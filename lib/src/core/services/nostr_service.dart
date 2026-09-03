import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ride_item_model.dart';
import '../utils/nostr_pow_helper.dart';

enum NostrConnectionState { disconnected, connecting, connected, reconnecting }

class NostrService with ChangeNotifier {
  NostrConnectionState _connectionState = NostrConnectionState.disconnected;
  NostrConnectionState get connectionState => _connectionState;

  bool _isInitializing = false;
  bool get isInitializing => _isInitializing;

  List<Map<String, Object>> _relays = [];
  List<Map<String, Object>> get relays => _relays;

  final int _defaultPowDifficulty = 28;

  late Ndk _ndk;
  Ndk get ndk => _ndk;

  final _feedRideEventController = StreamController<RideItemModel>.broadcast();
  Stream<RideItemModel> get feedRideEventsStream => _feedRideEventController.stream;

  final Map<String, String> _activeSubscriptions = {};
  final Map<String, NdkResponse> _activeStreams = {};

  final Set<String> _connectedRelayUrls = {};
  Set<String> get connectedRelayUrls => _connectedRelayUrls;
  int get connectedRelayCount => _connectedRelayUrls.length;
  int get totalRelayCount => _relays.where((r) => r['active'] as bool).length;

  NostrService() {
    _initNdkDefault();
    _loadRelays();
  }

  void _initNdkDefault() {
    _ndk = Ndk(
      NdkConfig(
        eventVerifier: Bip340EventVerifier(),
        cache: MemCacheManager(),
        bootstrapRelays: const [
          'wss://relay.damus.io',
          'wss://nos.lol',
          'wss://relay.primal.net',
          'wss://relay.trustroots.org',
          'wss://relay.nostr.band',
        ],
      ),
    );
  }

  Future<void> _loadRelays() async {
    final prefs = await SharedPreferences.getInstance();
    final savedRelays = prefs.getStringList('nostr_relays');
    if (savedRelays != null && savedRelays.isNotEmpty) {
      _relays = savedRelays.map((relayStr) {
        final parts = relayStr.split('|');
        return {
          'url': parts[0] as Object,
          'priority': int.parse(parts[1]) as Object,
          'active': (parts[2] == 'true') as Object,
        };
      }).toList();
    } else {
      _relays = [
        {'url': 'wss://relay.damus.io' as Object, 'priority': 1 as Object, 'active': true as Object},
        {'url': 'wss://nos.lol' as Object, 'priority': 2 as Object, 'active': true as Object},
        {'url': 'wss://relay.primal.net' as Object, 'priority': 3 as Object, 'active': true as Object},
        {'url': 'wss://relay.trustroots.org' as Object, 'priority': 4 as Object, 'active': true as Object},
        {'url': 'wss://relay.nostr.band' as Object, 'priority': 5 as Object, 'active': true as Object},
      ];
      await _saveRelays();
    }
    notifyListeners();
    await init();
  }

  Future<void> _saveRelays() async {
    final prefs = await SharedPreferences.getInstance();
    final relayStrings = _relays.map((relay) => '${relay['url']}|${relay['priority']}|${relay['active']}').toList();
    await prefs.setStringList('nostr_relays', relayStrings);
  }

  List<String> get activeRelayUrls => _relays
      .where((r) => r['active'] as bool)
      .map((r) => r['url'] as String)
      .toList();

  Future<bool> addRelay(String url) async {
    if (!url.startsWith('wss://')) {
      debugPrint("NostrService: Invalid relay URL, must start with wss://: $url");
      return false;
    }
    if (_relays.any((r) => r['url'] == url)) {
      debugPrint("NostrService: Relay already exists: $url");
      return false;
    }
    _relays.add({
      'url': url as Object,
      'priority': _relays.length + 1 as Object,
      'active': true as Object,
    });
    await _saveRelays();
    notifyListeners();
    await init();
    return true;
  }

  Future<bool> removeRelay(String url) async {
    final index = _relays.indexWhere((r) => r['url'] == url);
    if (index == -1) {
      debugPrint("NostrService: Relay not found: $url");
      return false;
    }
    _relays.removeAt(index);
    await _saveRelays();
    notifyListeners();
    await init();
    return true;
  }

  Future<bool> toggleRelayActive(String url) async {
    final index = _relays.indexWhere((r) => r['url'] == url);
    if (index == -1) {
      debugPrint("NostrService: Relay not found: $url");
      return false;
    }
    _relays[index]['active'] = !(_relays[index]['active'] as bool);
    await _saveRelays();
    notifyListeners();
    await init();
    return true;
  }

  Future<void> init() async {
    if (_isInitializing) {
      debugPrint("NostrService: Skipping init (already initializing).");
      return;
    }

    _isInitializing = true;
    _setConnectionState(NostrConnectionState.connecting);
    _connectedRelayUrls.clear();

    debugPrint("NostrService: Initializing NDK and relays...");

    try {
      final currentActiveUrls = activeRelayUrls;

      _ndk = Ndk(
        NdkConfig(
          eventVerifier: Bip340EventVerifier(),
          cache: MemCacheManager(),
          bootstrapRelays: currentActiveUrls.isNotEmpty
              ? currentActiveUrls
              : const ['wss://relay.damus.io', 'wss://nos.lol', 'wss://relay.primal.net'],
        ),
      );

      for (final url in currentActiveUrls) {
        _connectedRelayUrls.add(url);
      }

      _setConnectionState(NostrConnectionState.connected);
      debugPrint("NostrService: NDK initialized with ${currentActiveUrls.length} relays.");
    } catch (e) {
      debugPrint("NostrService: Exception during NDK init: $e");
      _setConnectionState(NostrConnectionState.disconnected);
    } finally {
      _isInitializing = false;
    }
  }

  NdkResponse subscribeToRides({
    List<String>? originGeohashPrefixes,
  }) {
    const subKey = "feed_rides";
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot subscribe, not connected (state: $_connectionState).");
      throw StateError("Not connected to Nostr relays.");
    }

    _unsubscribe(subKey);

    debugPrint("NostrService: Subscribing to rides with geohashes: $originGeohashPrefixes");

    final filter = Filter(
      kinds: [30402],
      tTags: ['rideshare', 'travel-partner', 'ride-offer', 'ride-request', 'rideshares.org', 'hitchhiking-partner'],
      since: (DateTime.now().subtract(const Duration(days: 60)).millisecondsSinceEpoch ~/ 1000),
      limit: 100,
    );

    if (originGeohashPrefixes != null && originGeohashPrefixes.isNotEmpty) {
      filter.setTag("g", originGeohashPrefixes);
    }

    try {
      final response = _ndk.requests.subscription(
        filter: filter,
        explicitRelays: activeRelayUrls.isNotEmpty ? activeRelayUrls : null,
      );

      _activeSubscriptions[subKey] = response.requestId;
      _activeStreams[subKey] = response;
      debugPrint("NostrService: Subscription started (ID: ${response.requestId})");

      response.stream.listen(
        (Nip01Event event) {
          try {
            if (RideItemModel.isRideshareEvent(event)) {
              final rideItem = RideItemModel.fromNostrEvent(event);
              _feedRideEventController.add(rideItem);
            }
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

      return response;
    } catch (e) {
      debugPrint("NostrService: Error starting subscription ($subKey): $e");
      _handleSubscriptionError(subKey);
      rethrow;
    }
  }

  NdkResponse? subscribeToUserRides(String userPubkeyHex) {
    const subKey = "my_rides";
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot subscribe to user rides (state: $_connectionState).");
      return null;
    }

    _unsubscribe(subKey);

    debugPrint("NostrService: Subscribing to user rides for $userPubkeyHex");

    final filter = Filter(
      authors: [userPubkeyHex],
      kinds: [30402],
      tTags: ['rideshare', 'travel-partner', 'ride-offer', 'ride-request', 'rideshares.org', 'hitchhiking-partner'],
      limit: 200,
    );

    try {
      final response = _ndk.requests.subscription(
        filter: filter,
        explicitRelays: activeRelayUrls.isNotEmpty ? activeRelayUrls : null,
      );

      _activeSubscriptions[subKey] = response.requestId;
      _activeStreams[subKey] = response;
      debugPrint("NostrService: User rides subscription started (ID: ${response.requestId})");
      return response;
    } catch (e) {
      debugPrint("NostrService: Error starting user rides subscription: $e");
      return null;
    }
  }

  void _unsubscribe(String subscriptionKey) {
    final subId = _activeSubscriptions.remove(subscriptionKey);
    _activeStreams.remove(subscriptionKey);
    if (subId != null) {
      debugPrint("NostrService: Unsubscribing from $subscriptionKey (ID: $subId)");
      try {
        _ndk.requests.closeSubscription(subId);
      } catch (e) {
        debugPrint("NostrService: Error closing subscription $subId: $e");
      }
    }
  }

  void _handleSubscriptionError(String subKey) {
    _unsubscribe(subKey);
    if (_connectionState == NostrConnectionState.connected) {
      Future.delayed(const Duration(seconds: 2), () {
        if (subKey == "feed_rides") {
          subscribeToRides();
        }
      });
    }
  }

  void _handleSubscriptionDone(String subKey) {
    _unsubscribe(subKey);
  }

  Future<bool> publishEvent(Nip01Event event) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish event ${event.id} (state: $_connectionState).");
      return false;
    }
    if (event.sig == null || event.sig!.isEmpty) {
      debugPrint("NostrService: Cannot publish unsigned event ${event.id}.");
      return false;
    }

    debugPrint("NostrService: Publishing event ${event.id} (Kind: ${event.kind})");

    const maxRetries = 3;
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final broadcastRes = _ndk.broadcast.broadcast(
          nostrEvent: event,
          specificRelays: activeRelayUrls.isNotEmpty ? activeRelayUrls : null,
        );
        final broadcastDone = await broadcastRes.broadcastDoneFuture;
        if (broadcastDone.isNotEmpty) {
          debugPrint("NostrService: Event ${event.id} published successfully to ${broadcastDone.length} relays.");
          return true;
        } else {
          debugPrint("NostrService: Attempt $attempt: No relays accepted event ${event.id}");
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

  Future<bool> publishDeletionEvent({
    required String eventIdToDelete,
    String reason = "",
    required EventSigner signer,
  }) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish deletion (state: $_connectionState).");
      return false;
    }

    debugPrint("NostrService: Publishing deletion for event $eventIdToDelete");

    try {
      final rawDeletionEvent = Nip01Event(
        pubKey: signer.getPublicKey(),
        kind: 5,
        tags: [["e", eventIdToDelete]],
        content: reason,
      );

      final signedEvent = await signer.sign(rawDeletionEvent);
      return await publishEvent(signedEvent);
    } catch (e) {
      debugPrint("NostrService: Error publishing deletion event: $e");
      return false;
    }
  }

  Future<Nip01Event?> publishEventWithPow({
    required int kind,
    required List<List<String>> tags,
    required String content,
    required EventSigner signer,
    int? powDifficulty,
  }) async {
    if (_connectionState != NostrConnectionState.connected) {
      debugPrint("NostrService: Cannot publish PoW event (state: $_connectionState).");
      return null;
    }

    try {
      final pubKey = signer.getPublicKey();
      final targetDifficulty = powDifficulty ?? _defaultPowDifficulty;
      final creationTime = DateTime.now();

      final nonceTag = await NostrPowHelper.minePoW(
        targetDifficulty: targetDifficulty,
        kind: kind,
        createdAt: creationTime,
        pubkey: pubKey,
        tags: tags,
        content: content,
      );

      if (nonceTag == null) {
        debugPrint("NostrService: PoW mining failed for kind $kind.");
        return null;
      }

      final eventTags = List<List<String>>.from(tags)..add(nonceTag);
      final rawEvent = Nip01Event(
        pubKey: pubKey,
        createdAt: creationTime.millisecondsSinceEpoch ~/ 1000,
        kind: kind,
        tags: eventTags,
        content: content,
      );

      final signedEvent = await signer.sign(rawEvent);
      final success = await publishEvent(signedEvent);
      return success ? signedEvent : null;
    } catch (e) {
      debugPrint("NostrService: Error publishing PoW event (kind $kind): $e");
      return null;
    }
  }

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
    _activeSubscriptions.keys.toList().forEach(_unsubscribe);
    await _feedRideEventController.close();
    await _ndk.destroy();
    _setConnectionState(NostrConnectionState.disconnected);
    super.dispose();
  }
}