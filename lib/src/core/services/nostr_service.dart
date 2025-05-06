import 'dart:async';
import 'package:dart_nostr/nostr/model/ease.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_nostr/dart_nostr.dart';
import '../models/ride_item_model.dart';
import '../utils/nostr_pow_helper.dart';
import 'dart:math';

enum NostrConnectionState { disconnected, connecting, connected, reconnecting }

/// Service responsible for managing NOSTR relay connections, subscriptions,
/// and event fetching/publishing for the Rideshares app.
class NostrService with ChangeNotifier {
  // Current connection state
  NostrConnectionState _connectionState = NostrConnectionState.disconnected;
  NostrConnectionState get connectionState => _connectionState;

  // Track whether initialization is in progress
  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  // List of relays with priority and status
  final List<Map<String, dynamic>> _relays = [
    {'url': 'wss://relay.damus.io', 'priority': 1, 'active': true},
    {'url': 'wss://nos.lol', 'priority': 2, 'active': true},
    {'url': 'wss://relay.primal.net', 'priority': 3, 'active': true},
    {'url': 'wss://relay.trustroots.org', 'priority': 4, 'active': true},
    {'url': 'wss://relay.nostr.band', 'priority': 5, 'active': true},
  ];

  // Default PoW difficulty
  final int _defaultPowDifficulty = 28;

  // Nostr service instance
  final _nostrRelaysService = Nostr.instance.services.relays;

  // Stream controllers
  final _feedRideEventController = StreamController<RideItemModel>.broadcast();
  Stream<RideItemModel> get feedRideEventsStream => _feedRideEventController.stream;

  // Subscription tracking
  final Map<String, String> _activeSubscriptions = {};
  final Map<String, NostrEventsStream> _activeStreams = {};

  // Connected relays
  Set<String> _connectedRelayUrls = {};
  int get connectedRelayCount => _connectedRelayUrls.length;
  int get totalRelayCount => _relays.where((r) => r['active']).length;

  // Reconnection parameters
  static const _maxReconnectAttempts = 3;
  int _reconnectAttempts = 0;
  Timer? _reconnectTimer;

  /// Initializes connections to relays with retry and fallback logic.
  Future<void> init() async {
    if (_isInitializing || _connectionState == NostrConnectionState.connected) {
      debugPrint("NostrService: Skipping init (already initializing or connected).");
      return;
    }

    _isInitializing = true;
    _setConnectionState(NostrConnectionState.connecting);
    _connectedRelayUrls.clear();
    _reconnectAttempts = 0;

    debugPrint("NostrService: Initializing relay connections...");

    try {
      // Select active relays, sorted by priority
      final activeRelayUrls = _relays
          .where((r) => r['active'])
          .toList()
        ..sort((a, b) => (a['priority'] as int).compareTo(b['priority'] as int));

      final relayUrlsList = activeRelayUrls.map((r) => r['url'] as String).toList();

      await _nostrRelaysService.init(
        relaysUrl: relayUrlsList,
        connectionTimeout: const Duration(seconds: 15),
        onRelayConnectionError: (relay, error, _) {
          debugPrint("NostrService: Error on $relay: $error");
          _connectedRelayUrls.remove(relay);
          _updateRelayStatus(relay, false);
          _checkConnectionStatus();
        },
        onRelayConnectionDone: (relayUrl, webSocket) {
          if (webSocket != null) {
            debugPrint("NostrService: Connected to $relayUrl");
            _connectedRelayUrls.add(relayUrl);
            _updateRelayStatus(relayUrl, true);
            _setConnectionState(NostrConnectionState.connected);
            _reconnectAttempts = 0;
          } else {
            debugPrint("NostrService: Connection closed for $relayUrl");
            _connectedRelayUrls.remove(relayUrl);
            _updateRelayStatus(relayUrl, false);
            _checkConnectionStatus();
          }
        },
        retryOnError: true,
        retryOnClose: true,
        ignoreConnectionException: true,
        shouldReconnectToRelayOnNotice: true,
        lazyListeningToRelays: false,
        ensureToClearRegistriesBeforeStarting: true,
      );

      // Immediately check relay statuses after init
      _updateConnectedRelaysFromRegistry();
      _checkConnectionStatus();
      debugPrint("NostrService: Relay init completed. Connected to: $connectedRelayCount/$totalRelayCount");
    } catch (e) {
      debugPrint("NostrService: Exception during relay init: $e");
      _updateConnectedRelaysFromRegistry();
      _checkConnectionStatus();
    } finally {
      _isInitializing = false;
    }
  }

  /// Updates connected relays based on the WebSocket registry.
  void _updateConnectedRelaysFromRegistry() {
    _connectedRelayUrls.clear();
    final registry = _nostrRelaysService.relaysWebSocketsRegistry;
    for (final relay in _relays) {
      final url = relay['url'] as String;
      if (registry.containsKey(url)) {
        _connectedRelayUrls.add(url);
        _updateRelayStatus(url, true);
      } else {
        _updateRelayStatus(url, false);
      }
    }
  }

  /// Updates relay status (active/inactive) based on connection success/failure.
  void _updateRelayStatus(String relayUrl, bool isActive) {
    final relay = _relays.firstWhere((r) => r['url'] == relayUrl, orElse: () => {});
    if (relay.isNotEmpty) {
      relay['active'] = isActive;
      if (!isActive) {
        // Increase priority of inactive relays to try others later
        relay['priority'] = (relay['priority'] as int) + 1;
      }
    }
  }

  /// Checks overall connection status and triggers reconnection if needed.
  void _checkConnectionStatus() {
    if (_connectedRelayUrls.isNotEmpty) {
      _setConnectionState(NostrConnectionState.connected);
    } else if (_reconnectAttempts < _maxReconnectAttempts) {
      _setConnectionState(NostrConnectionState.disconnected);
      _scheduleReconnect();
    } else {
      debugPrint("NostrService: No relays connected after max attempts. Staying disconnected.");
      _setConnectionState(NostrConnectionState.disconnected);
    }
  }

  /// Schedules a reconnection attempt with exponential backoff.
  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts || _connectionState == NostrConnectionState.reconnecting) {
      debugPrint("NostrService: Max reconnect attempts reached or already reconnecting.");
      return;
    }

    _reconnectAttempts++;
    final delaySeconds = min(30, pow(2, _reconnectAttempts).toInt());
    final delay = Duration(seconds: delaySeconds);
    debugPrint("NostrService: Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s");

    _setConnectionState(NostrConnectionState.reconnecting);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      await init();
    });
  }

  /// Subscribes to ride events with geohash filtering.
  NostrEventsStream subscribeToRides({List<String>? originGeohashPrefixes, Function(String, NostrRequestEoseCommand)? onEose}) {
    const subKey = "feed_rides";
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot subscribe, not connected (state: $_connectionState).");
      throw StateError("Not connected to Nostr relays.");
    }

    _unsubscribe(subKey);

    debugPrint("NostrService: Subscribing to rides with geohashes: $originGeohashPrefixes");

    final filter = NostrFilter(
      kinds: [30402],
      t: ['rideshare'],
      additionalFilters: originGeohashPrefixes != null && originGeohashPrefixes.isNotEmpty
          ? {'#g': originGeohashPrefixes}
          : null,
      since: DateTime.now().subtract(const Duration(days: 60)),
      limit: 100,
    );

    final request = NostrRequest(filters: [filter]);

    try {
      final streamResult = _nostrRelaysService.startEventsSubscription(
        request: request,
        onEose: onEose, // Pass the onEose callback
      );
      _activeSubscriptions[subKey] = streamResult.subscriptionId;
      _activeStreams[subKey] = streamResult;
      debugPrint("NostrService: Subscription started (ID: ${streamResult.subscriptionId})");

      streamResult.stream.listen(
            (NostrEvent event) {
          try {
            final rideItem = RideItemModel.fromNostrEvent(event);
            _feedRideEventController.add(rideItem);
          } catch (e) {
            debugPrint("NostrService: Error parsing event: $e");
          }
        },
        onError: (error) {
          debugPrint("NostrService: Subscription error ($subKey): $error");
          _handleSubscriptionError(subKey);
        },
        onDone: () {
          debugPrint("NostrService: Subscription closed ($subKey)");
          _handleSubscriptionDone(subKey);
        },
      );

      return streamResult;
    } catch (e) {
      debugPrint("NostrService: Error starting subscription ($subKey): $e");
      _handleSubscriptionError(subKey);
      throw e; // Re-throw to allow caller to handle
    }
  }

  /// Subscribes to user-specific rides.
  NostrEventsStream? subscribeToUserRides(String userPubkeyHex) {
    const subKey = "my_rides";
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot subscribe to user rides (state: $_connectionState).");
      return null;
    }

    _unsubscribe(subKey);

    debugPrint("NostrService: Subscribing to user rides for $userPubkeyHex");

    final filter = NostrFilter(
      authors: [userPubkeyHex],
      kinds: [30402],
      limit: 200,
    );
    final request = NostrRequest(filters: [filter]);

    try {
      final streamResult = _nostrRelaysService.startEventsSubscription(
        request: request,
      );
      _activeSubscriptions[subKey] = streamResult.subscriptionId;
      _activeStreams[subKey] = streamResult;
      debugPrint("NostrService: User rides subscription started (ID: ${streamResult.subscriptionId})");
      return streamResult;
    } catch (e) {
      debugPrint("NostrService: Error starting user rides subscription: $e");
      return null;
    }
  }

  /// Unsubscribes from a specific subscription.
  void _unsubscribe(String subscriptionKey) {
    final subId = _activeSubscriptions.remove(subscriptionKey);
    final stream = _activeStreams.remove(subscriptionKey);
    if (subId != null) {
      debugPrint("NostrService: Unsubscribing from $subscriptionKey (ID: $subId)");
      try {
        _nostrRelaysService.closeEventsSubscription(subId);
        stream?.stream.drain();
      } catch (e) {
        debugPrint("NostrService: Error closing subscription $subId: $e");
      }
    }
  }

  /// Handles subscription errors.
  void _handleSubscriptionError(String subKey) {
    _unsubscribe(subKey);
    if (_connectionState == NostrConnectionState.connected) {
      Future.delayed(const Duration(seconds: 2), () {
        if (subKey == "feed_rides") {
          subscribeToRides();
        } else if (subKey == "my_rides") {
          // Re-subscribe to user rides if needed
        }
      });
    }
  }

  /// Handles subscription completion.
  void _handleSubscriptionDone(String subKey) {
    _unsubscribe(subKey);
  }

  /// Publishes a signed event with retry logic.
  Future<bool> publishEvent(NostrEvent event) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish event ${event.id} (state: $_connectionState).");
      return false;
    }
    if (event.sig == null) {
      debugPrint("NostrService: Cannot publish unsigned event ${event.id}.");
      return false;
    }

    debugPrint("NostrService: Publishing event ${event.id} (Kind: ${event.kind})");

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final res = await _nostrRelaysService.sendEventToRelaysAsync(
          event,
          timeout: const Duration(seconds: 10),
        );
        if (res.isEventAccepted ?? false) {
          debugPrint("NostrService: Event ${event.id} published successfully.");
          return true;
        } else {
          debugPrint("NostrService: Attempt $attempt failed for event ${event.id}: ${res.message}");
        }
      } catch (e) {
        debugPrint("NostrService: Error publishing event ${event.id} (attempt $attempt): $e");
      }
      if (attempt < maxRetries) {
        await Future.delayed(const Duration(seconds: 2));
      }
    }
    debugPrint("NostrService: Failed to publish event ${event.id} after $maxRetries attempts.");
    return false;
  }

  /// Publishes a deletion event.
  Future<bool> publishDeletionEvent({
    required String eventIdToDelete,
    String reason = "",
    required String signingKey,
  }) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish deletion (state: $_connectionState).");
      return false;
    }

    debugPrint("NostrService: Publishing deletion for event $eventIdToDelete");

    try {
      final keyPairs = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(signingKey);
      final deletionEvent = NostrEvent.fromPartialData(
        kind: 5,
        tags: [["e", eventIdToDelete]],
        content: reason,
        keyPairs: keyPairs,
      );

      return await publishEvent(deletionEvent);
    } catch (e) {
      debugPrint("NostrService: Error publishing deletion event: $e");
      return false;
    }
  }

  /// Publishes an event with PoW.
  Future<NostrEvent?> publishEventWithPow({
    required int kind,
    required List<List<String>> tags,
    required String content,
    required String signingKey,
    int? powDifficulty,
  }) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish PoW event (state: $_connectionState).");
      return null;
    }

    try {
      final keyPairs = Nostr.instance.services.keys.generateKeyPairFromExistingPrivateKey(signingKey);
      final targetDifficulty = powDifficulty ?? _defaultPowDifficulty;
      final creationTime = DateTime.now();

      final nonceTag = await NostrPowHelper.minePoW(
        targetDifficulty: targetDifficulty,
        kind: kind,
        createdAt: creationTime,
        pubkey: keyPairs.public,
        tags: tags,
        content: content,
      );

      if (nonceTag == null) {
        debugPrint("NostrService: PoW mining failed for kind $kind.");
        return null;
      }

      final eventTags = List<List<String>>.from(tags)..add(nonceTag);
      final event = NostrEvent.fromPartialData(
        keyPairs: keyPairs,
        createdAt: creationTime,
        kind: kind,
        tags: eventTags,
        content: content,
      );

      final success = await publishEvent(event);
      return success ? event : null;
    } catch (e) {
      debugPrint("NostrService: Error publishing PoW event (kind $kind): $e");
      return null;
    }
  }

  /// Updates connection state and notifies listeners.
  void _setConnectionState(NostrConnectionState state) {
    if (_connectionState != state) {
      debugPrint("NostrService: Connection state changed: $_connectionState -> $state");
      _connectionState = state;
      notifyListeners();
    }
  }

  @override
  Future<void> dispose() async {
    debugPrint("NostrService: Disposing...");
    _reconnectTimer?.cancel();
    _activeSubscriptions.keys.toList().forEach(_unsubscribe);
    await _feedRideEventController.close();
    await _nostrRelaysService.freeAllResources();
    _setConnectionState(NostrConnectionState.disconnected);
    super.dispose();
  }

  // Expose relays for external use
  List<String> get relays => _relays.where((r) => r['active']).map((r) => r['url'] as String).toList();
}
