import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:collection/collection.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/models/ride_item_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';

class MyRidesProvider with ChangeNotifier {
  final AuthService _authService;
  final NostrService _nostrService;
  StreamSubscription<NostrEvent>? _myRidesStreamListener;

  // State
  Map<String, RideItemModel> _myRidesByDTag = {};
  bool _isLoading = false;
  String? _error;
  bool _initialFetchDone = false;

  // Getters
  List<RideItemModel> get myRides {
    final rides = _myRidesByDTag.values.toList();
    rides.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rides;
  }
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool _providerMounted = true;

  MyRidesProvider(this._authService, this._nostrService) {
    _authService.addListener(_handleAuthChange);
    _nostrService.addListener(_handleNostrConnectionChange);
    if (_authService.isLoggedIn) {
      fetchMyRides();
    }
  }

  void _handleAuthChange() {
    if (_authService.isLoggedIn) {
      fetchMyRides();
    } else {
      _myRidesStreamListener?.cancel();
      _myRidesStreamListener = null;
      _myRidesByDTag.clear();
      _isLoading = false;
      _error = null;
      _initialFetchDone = false;
      if (_providerMounted) notifyListeners();
    }
  }

  void _handleNostrConnectionChange() {
    final state = _nostrService.connectionState;
    debugPrint("MyRidesProvider: Nostr state changed: $state");
    if (state == NostrConnectionState.connected && _authService.isLoggedIn && !_initialFetchDone && _myRidesStreamListener == null) {
      debugPrint("MyRidesProvider: Connected, fetching rides...");
      fetchMyRides(forceRefresh: true);
    } else if (state == NostrConnectionState.disconnected && _initialFetchDone) {
      if (_providerMounted) {
        setError("Lost connection to Nostr relays.");
      }
    } else if (state == NostrConnectionState.reconnecting) {
      if (_providerMounted && !_isLoading) {
        setStateLoading(true);
        _error = "Reconnecting to relays...";
        notifyListeners();
      }
    }
  }

  Future<void> fetchMyRides({bool forceRefresh = false}) async {
    if (!_authService.isLoggedIn || _authService.npub == null) {
      setError("Not logged in.");
      return;
    }
    if (_isLoading && !forceRefresh) {
      debugPrint("MyRidesProvider: Already fetching, skipping.");
      return;
    }
    if (_nostrService.connectionState != NostrConnectionState.connected) {
      setError("Cannot fetch rides, not connected to Nostr.");
      return;
    }

    debugPrint("MyRidesProvider: Fetching rides for ${_authService.npub}");
    setStateLoading(true);
    _error = null;
    if (forceRefresh) {
      _myRidesByDTag.clear();
      _initialFetchDone = false;
    }
    notifyListeners();

    await _myRidesStreamListener?.cancel();
    _myRidesStreamListener = null;

    final userPubkeyHex = _authService.signingKey != null
        ? Nostr.instance.services.keys.derivePublicKey(privateKey: _authService.signingKey!)
        : null;
    if (userPubkeyHex == null) {
      setError("Could not derive public key.");
      return;
    }

    try {
      final streamResult = _nostrService.subscribeToUserRides(userPubkeyHex);
      if (streamResult == null) {
        setError("Failed to initiate subscription.");
        return;
      }

      _myRidesStreamListener = streamResult.stream.listen(
            (event) {
          if (!_providerMounted) return;
          bool rideAddedOrUpdated = false;
          try {
            final ride = RideItemModel.fromNostrEvent(event);
            final dTag = event.tags?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd');
            if (dTag != null && dTag.length > 1) {
              final dValue = dTag[1].toString();
              final existingRide = _myRidesByDTag[dValue];
              if (existingRide == null || ride.createdAt.isAfter(existingRide.createdAt)) {
                _myRidesByDTag[dValue] = ride;
                rideAddedOrUpdated = true;
              }
            }
          } catch (e) {
            debugPrint("MyRidesProvider: Error parsing event ${event.id}: $e");
          }
          if (rideAddedOrUpdated) {
            _isLoading = false;
            _error = null;
            notifyListeners();
          }
        },
        onError: (err) {
          debugPrint("MyRidesProvider: Stream error: $err");
          if (_providerMounted) setError("Error fetching rides: $err");
        },
        onDone: () {
          debugPrint("MyRidesProvider: Stream closed.");
          _myRidesStreamListener = null;
          if (_providerMounted && _isLoading) {
            _isLoading = false;
            _initialFetchDone = true;
            notifyListeners();
          }
        },
      );

      Future.delayed(const Duration(seconds: 5), () {
        if (_providerMounted && _isLoading) {
          _isLoading = false;
          _initialFetchDone = true;
          _error = _myRidesByDTag.isEmpty ? "You haven't posted any rides or timed out." : null;
          notifyListeners();
        }
      });
    } catch (e) {
      setError("Failed to initiate fetch: $e");
    }
  }

  Future<bool> markRideSold(RideItemModel ride) async {
    if (!_authService.isLoggedIn || _authService.signingKey == null) {
      debugPrint("MyRidesProvider: Cannot mark sold, not logged in.");
      return false;
    }
    if (ride.rawNostrEvent == null || ride.id == 'invalid_id') {
      debugPrint("MyRidesProvider: Cannot mark sold, missing raw event or invalid ID.");
      return false;
    }
    final dTagValue = ride.rawNostrEvent!.tags?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd')?[1].toString();
    if (dTagValue == null) {
      debugPrint("MyRidesProvider: Cannot mark sold, missing 'd' tag.");
      return false;
    }

    debugPrint("MyRidesProvider: Marking ride dTag=$dTagValue as sold...");

    // Optimistic UI update
    _updateLocalRideStatus(dTagValue, RideStatus.filled, DateTime.now());

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        List<List<String>> updatedTags = [];
        bool statusTagFound = false;
        for (final tag in ride.rawNostrEvent!.tags ?? []) {
          if (tag is List && tag.isNotEmpty) {
            final stringTag = tag.map((e) => e.toString()).toList();
            if (stringTag[0] == 'status') {
              updatedTags.add(["status", "sold"]);
              statusTagFound = true;
            } else {
              updatedTags.add(stringTag);
            }
          }
        }
        if (!statusTagFound) {
          updatedTags.add(["status", "sold"]);
        }

        final originalContent = ride.rawNostrEvent!.content ?? ride.description;
        final keyPairs = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(_authService.signingKey!);

        final updatedEvent = NostrEvent.fromPartialData(
          kind: ride.rawNostrEvent!.kind!,
          content: originalContent,
          tags: updatedTags,
          keyPairs: keyPairs,
        );

        final success = await _nostrService.publishEvent(updatedEvent);
        if (success) {
          debugPrint("MyRidesProvider: Successfully marked ride dTag=$dTagValue as sold. New Event ID: ${updatedEvent.id}");
          return true;
        } else {
          debugPrint("MyRidesProvider: Failed to mark sold (attempt $attempt).");
        }
      } catch (e) {
        debugPrint("MyRidesProvider: Error marking ride as sold (attempt $attempt): $e");
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Rollback optimistic update on failure
    _updateLocalRideStatus(dTagValue, ride.status, ride.createdAt);
    debugPrint("MyRidesProvider: Failed to mark ride dTag=$dTagValue as sold after $maxRetries attempts.");
    return false;
  }

  Future<bool> editRide(RideItemModel existingRide, {
    required RideType rideType,
    required LocationModel origin,
    required LocationModel destination,
    required DateTime departureTimeUtc,
    required String originTimezone,
    required String description,
    required String priceAmount,
    required String priceCurrency,
  }) async {
    if (!_authService.isLoggedIn || _authService.signingKey == null) {
      debugPrint("MyRidesProvider: Cannot edit, not logged in.");
      return false;
    }
    if (existingRide.rawNostrEvent == null || existingRide.id == 'invalid_id') {
      debugPrint("MyRidesProvider: Cannot edit, missing raw event or invalid ID.");
      return false;
    }
    final dTagValue = existingRide.rawNostrEvent!.tags?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd')?[1].toString();
    if (dTagValue == null) {
      debugPrint("MyRidesProvider: Cannot edit, missing 'd' tag.");
      return false;
    }

    debugPrint("MyRidesProvider: Editing ride dTag=$dTagValue...");

    // Optimistic UI update
    _updateLocalRideEdited(dTagValue, existingRide, rideType, origin, destination, departureTimeUtc, originTimezone, description, priceAmount, priceCurrency);

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        // Preserve essential tags and update relevant ones
        List<List<String>> updatedTags = [];
        for (final tag in existingRide.rawNostrEvent!.tags ?? []) {
          if (tag is List && tag.isNotEmpty) {
            final stringTag = tag.map((e) => e.toString()).toList();
            if (stringTag[0] == 'g' || stringTag[0] == 't' || stringTag[0] == 'd') {
              updatedTags.add(stringTag); // Keep geohash, type, and d tags
            }
          }
        }
        // Add updated tags
        updatedTags.addAll([
          ['t', rideType == RideType.offer ? 'offer' : 'request'],
          ['status', existingRide.status.name],
          ['price', priceAmount, priceCurrency],
          ['timezone', originTimezone],
        ]);

        final keyPairs = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(_authService.signingKey!);

        final updatedEvent = NostrEvent.fromPartialData(
          kind: existingRide.rawNostrEvent!.kind!,
          content: description,
          tags: updatedTags,
          keyPairs: keyPairs,
          createdAt: DateTime.now(),
        );

        final success = await _nostrService.publishEvent(updatedEvent);
        if (success) {
          debugPrint("MyRidesProvider: Successfully edited ride dTag=$dTagValue. New Event ID: ${updatedEvent.id}");
          return true;
        } else {
          debugPrint("MyRidesProvider: Failed to edit ride (attempt $attempt).");
        }
      } catch (e) {
        debugPrint("MyRidesProvider: Error editing ride (attempt $attempt): $e");
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Rollback optimistic update on failure
    _updateLocalRideStatus(dTagValue, existingRide.status, existingRide.createdAt);
    debugPrint("MyRidesProvider: Failed to edit ride dTag=$dTagValue after $maxRetries attempts.");
    return false;
  }

  Future<bool> deleteRide(RideItemModel ride) async {
    if (!_authService.isLoggedIn || _authService.signingKey == null) {
      debugPrint("MyRidesProvider: Cannot delete, not logged in.");
      return false;
    }
    if (ride.id == 'invalid_id') {
      debugPrint("MyRidesProvider: Cannot delete, invalid ride ID.");
      return false;
    }
    final dTagValue = ride.rawNostrEvent?.tags?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd')?[1].toString();
    if (dTagValue == null) {
      debugPrint("MyRidesProvider: Cannot delete, missing 'd' tag.");
      return false;
    }

    debugPrint("MyRidesProvider: Deleting ride ${ride.id}...");

    // Optimistic UI update
    _removeLocalRide(dTagValue);

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final success = await _nostrService.publishDeletionEvent(
          eventIdToDelete: ride.id,
          reason: "Ride deleted by user.",
          signingKey: _authService.signingKey!,
        );
        if (success) {
          debugPrint("MyRidesProvider: Successfully deleted ride ${ride.id}");
          return true;
        } else {
          debugPrint("MyRidesProvider: Failed to delete ride (attempt $attempt).");
        }
      } catch (e) {
        debugPrint("MyRidesProvider: Error deleting ride (attempt $attempt): $e");
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    // Rollback optimistic update on failure
    if (dTagValue != null) {
      _myRidesByDTag[dTagValue] = ride;
      notifyListeners();
    }
    debugPrint("MyRidesProvider: Failed to delete ride ${ride.id} after $maxRetries attempts.");
    return false;
  }

  void setStateLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void setError(String message) {
    _error = message;
    _isLoading = false;
    _initialFetchDone = true;
    if (_providerMounted) notifyListeners();
  }

  void _updateLocalRideStatus(String dTag, RideStatus newStatus, DateTime newTimestamp) {
    final ride = _myRidesByDTag[dTag];
    if (ride != null) {
      _myRidesByDTag[dTag] = RideItemModel(
        id: ride.id,
        pubkey: ride.pubkey,
        createdAt: newTimestamp,
        publishedAt: ride.publishedAt,
        type: ride.type,
        origin: ride.origin,
        destination: ride.destination,
        departureTimeUtc: ride.departureTimeUtc,
        originTimezone: ride.originTimezone,
        description: ride.description,
        status: newStatus,
        rawNostrEvent: ride.rawNostrEvent,
      );
      notifyListeners();
    }
  }

  void _updateLocalRideEdited(
      String dTag,
      RideItemModel existingRide,
      RideType rideType,
      LocationModel origin,
      LocationModel destination,
      DateTime departureTimeUtc,
      String originTimezone,
      String description,
      String priceAmount,
      String priceCurrency,
      ) {
    final ride = _myRidesByDTag[dTag];
    if (ride != null) {
      _myRidesByDTag[dTag] = RideItemModel(
        id: ride.id,
        pubkey: ride.pubkey,
        createdAt: DateTime.now(),
        publishedAt: ride.publishedAt,
        type: rideType,
        origin: origin,
        destination: destination,
        departureTimeUtc: departureTimeUtc,
        originTimezone: originTimezone,
        description: description,
        status: existingRide.status,
        priceAmount: priceAmount,
        priceCurrency: priceCurrency,
        rawNostrEvent: ride.rawNostrEvent,
      );
      notifyListeners();
    }
  }

  void _removeLocalRide(String dTag) {
    if (_myRidesByDTag.containsKey(dTag)) {
      _myRidesByDTag.remove(dTag);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    debugPrint("MyRidesProvider: Disposing...");
    _myRidesStreamListener?.cancel();
    _authService.removeListener(_handleAuthChange);
    _nostrService.removeListener(_handleNostrConnectionChange);
    _providerMounted = false;
    super.dispose();
  }
}