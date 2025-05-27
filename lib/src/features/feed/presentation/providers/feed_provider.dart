import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:osm_nominatim/osm_nominatim.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/location_model.dart';
import '../../../../core/models/ride_item_model.dart';
import '../../../../core/services/nostr_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dart_geohash/dart_geohash.dart';
import '../../../../core/utils/nostr_event_helpers.dart';
import 'package:latlong2/latlong.dart';
import 'package:collection/collection.dart';

enum FeedMode { nearby, global, search }

class FeedProvider with ChangeNotifier {
  final NostrService _nostrService;
  StreamSubscription? _rideSubscription;
  Map<String, RideItemModel> _ridesByDTag = {};
  bool _isLoading = false;
  String? _error;
  bool _initialFetchDone = false;

  // Default mode for new users, easily configurable
  static const FeedMode _defaultMode = FeedMode.global;

  FeedMode _currentMode = _defaultMode;
  FeedMode get currentMode => _currentMode;

  LocationModel? _searchLocation;
  LocationModel? get searchLocation => _searchLocation;
  String? _searchQuery;
  String? get searchQuery => _searchQuery;
  bool _isSearchingLocation = false;
  bool get isSearchingLocation => _isSearchingLocation;

  Position? _currentDevicePosition;
  String? _locationError;
  bool _isFetchingDeviceLocation = false;
  LocationPermission _permissionStatus = LocationPermission.denied;

  final GeoHasher _geoHasher = GeoHasher();

  List<RideItemModel> get rides {
    final ridesList = _ridesByDTag.values.toList();
    ridesList.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return ridesList;
  }

  String? get error => _error;
  String? get locationError => _locationError;
  LocationPermission get permissionStatus => _permissionStatus;
  Position? get currentDevicePosition => _currentDevicePosition;
  bool get isFetchingDeviceLocation => _isFetchingDeviceLocation;
  bool get isLoading => _isLoading || _isFetchingDeviceLocation || _isSearchingLocation;

  bool _providerMounted = true;

  FeedProvider(this._nostrService) {
    _nostrService.addListener(_nostrConnectionListener);
    _loadSavedModeAndInit();
  }

  Future<void> _loadSavedModeAndInit() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString('feed_mode');
    FeedMode initialMode = _defaultMode;
    if (savedMode != null) {
      try {
        initialMode = FeedMode.values.firstWhere(
              (mode) => mode.toString() == savedMode,
          orElse: () => _defaultMode,
        );
      } catch (e) {
        debugPrint("FeedProvider: Error loading saved mode: $e");
      }
    }
    _initLocationAndFetch(mode: initialMode);
  }

  Future<void> _saveMode(FeedMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('feed_mode', mode.toString());
  }

  void _nostrConnectionListener() {
    final state = _nostrService.connectionState;
    debugPrint("FeedProvider: Nostr state changed: $state");

    if (state == NostrConnectionState.connected) {
      if (!_initialFetchDone && _rideSubscription == null) {
        debugPrint("FeedProvider: Connected, fetching rides...");
        fetchAndListenToRides(position: _currentDevicePosition);
      }
    } else if (state == NostrConnectionState.disconnected) {
      if (_providerMounted && !_isLoading && _initialFetchDone) {
        setError("Lost connection to Nostr relays.");
        _ridesByDTag.clear();
      }
    } else if (state == NostrConnectionState.reconnecting) {
      if (_providerMounted && !_isLoading) {
        setStateLoading(true);
        _error = "Reconnecting to relays...";
        notifyListeners();
      }
    }
  }

  Future<void> _initLocationAndFetch({required FeedMode mode, String? searchQuery}) async {
    if (_isLoading || _isFetchingDeviceLocation || _isSearchingLocation) {
      debugPrint("FeedProvider: Already processing, exiting init.");
      return;
    }

    _currentMode = mode;
    await _saveMode(mode); // Save the new mode
    setStateLoading(true);
    _locationError = null;
    _searchLocation = null;
    _searchQuery = searchQuery;
    _initialFetchDone = false;
    _ridesByDTag.clear();
    notifyListeners();

    Position? positionToUse;

    if (mode == FeedMode.nearby) {
      _isFetchingDeviceLocation = true;
      notifyListeners();
      positionToUse = await _determinePosition();
      _currentDevicePosition = positionToUse;
      _isFetchingDeviceLocation = false;
      if (positionToUse == null && _locationError != null) {
        debugPrint("FeedProvider: Location failed: $_locationError");
      }
    } else if (mode == FeedMode.search && searchQuery != null) {
      _isSearchingLocation = true;
      notifyListeners();
      final searchResult = await _geocodeSearchQuery(searchQuery);
      _isSearchingLocation = false;
      if (searchResult != null) {
        _searchLocation = searchResult;
        positionToUse = Position(
          latitude: searchResult.latitude,
          longitude: searchResult.longitude,
          timestamp: DateTime.now(),
          accuracy: 500,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
        _currentDevicePosition = positionToUse;
      } else {
        _currentMode = FeedMode.global;
        await _saveMode(FeedMode.global); // Save fallback mode
        setError("Could not find location: '$searchQuery'.");
        _isLoading = true;
      }
    }

    _currentDevicePosition = positionToUse;

    if (_nostrService.connectionState == NostrConnectionState.connected) {
      debugPrint("FeedProvider: Connected, fetching rides...");
      fetchAndListenToRides(position: _currentDevicePosition, forceRefresh: true);
    } else {
      debugPrint("FeedProvider: Waiting for Nostr connection...");
    }
  }

  Future<LocationModel?> _geocodeSearchQuery(String query) async {
    debugPrint("FeedProvider: Geocoding: '$query'");
    try {
      final places = await Nominatim.searchByName(
        query: query,
        limit: 1,
        addressDetails: true,
      );
      if (places.isNotEmpty) {
        final place = places.first;
        final lat = place.lat;
        final lon = place.lon;
        if (lat != null && lon != null) {
          final geohash = _geoHasher.encode(lon, lat, precision: 9);
          return LocationModel(
            displayName: place.displayName ?? query,
            latitude: lat,
            longitude: lon,
            geohash: geohash,
          );
        }
      }
      return null;
    } catch (e) {
      debugPrint("FeedProvider: Geocoding error: $e");
      return null;
    }
  }

  void switchToGlobalMode() {
    if (_currentMode != FeedMode.global) {
      _initLocationAndFetch(mode: FeedMode.global);
    }
  }

  void switchToNearbyMode() {
    if (_currentMode != FeedMode.nearby) {
      _initLocationAndFetch(mode: FeedMode.nearby);
    } else {
      requestDeviceLocationAndFetch();
    }
  }

  void searchLocationAndFetch(String query) {
    if (query.trim().isNotEmpty) {
      _initLocationAndFetch(mode: FeedMode.search, searchQuery: query.trim());
    }
  }

  Future<void> requestDeviceLocationAndFetch() async {
    await _initLocationAndFetch(mode: FeedMode.nearby);
  }

  Future<Position?> _determinePosition() async {
    debugPrint("FeedProvider: Determining position...");
    _isFetchingDeviceLocation = true;
    notifyListeners();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _locationError = 'Location services are disabled.';
      _permissionStatus = LocationPermission.deniedForever;
      _isFetchingDeviceLocation = false;
      notifyListeners();
      return null;
    }

    _permissionStatus = await Geolocator.checkPermission();
    if (_permissionStatus == LocationPermission.denied) {
      _permissionStatus = await Geolocator.requestPermission();
      if (_permissionStatus == LocationPermission.denied) {
        _locationError = 'Location permissions are denied.';
        _isFetchingDeviceLocation = false;
        notifyListeners();
        return null;
      }
    }

    if (_permissionStatus == LocationPermission.deniedForever) {
      _locationError = 'Location permissions are permanently denied.';
      _isFetchingDeviceLocation = false;
      notifyListeners();
      return null;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      _locationError = null;
      _isFetchingDeviceLocation = false;
      notifyListeners();
      return position;
    } catch (e) {
      _locationError = 'Failed to get location: $e';
      _isFetchingDeviceLocation = false;
      notifyListeners();
      return null;
    }
  }

  Future<void> fetchAndListenToRides({Position? position, bool forceRefresh = false}) async {
    if (!_isLoading) setStateLoading(true);
    _error = null;
    if (forceRefresh || !_initialFetchDone) {
      _ridesByDTag.clear();
      _initialFetchDone = false;
    }
    notifyListeners();

    _rideSubscription?.cancel();
    _rideSubscription = null;

    if (_nostrService.connectionState != NostrConnectionState.connected) {
      setError("Cannot fetch rides, not connected to Nostr.");
      return;
    }

    List<String>? geohashFilter;
    if (position != null && _currentMode != FeedMode.global) {
      try {
        final currentGeohash = _geoHasher.encode(position.longitude, position.latitude, precision: 9);
        geohashFilter = NostrEventHelper.generateGeohashTags(currentGeohash, 5, "g")
            .map((tagList) => tagList[1])
            .toList();
      } catch (e) {
        debugPrint("FeedProvider: Geohash encoding error: $e");
      }
    }

    try {
      final relays = _nostrService.relays;
      final totalRelays = relays.length;
      final completedRelays = <String>{};
      String? subscriptionId;
      bool allRelaysDone = false;

      final streamResult = _nostrService.subscribeToRides(
        originGeohashPrefixes: geohashFilter,
        onEose: (relayUrl, eoseCommand) {
          if (subscriptionId == null) {
            subscriptionId = eoseCommand.subscriptionId;
          }
          if (eoseCommand.subscriptionId == subscriptionId) {
            completedRelays.add(relayUrl);
            debugPrint("FeedProvider: EOSE from $relayUrl, ${completedRelays.length}/$totalRelays relays done");
            if (completedRelays.length == totalRelays) {
              debugPrint("FeedProvider: All relays sent EOSE");
              allRelaysDone = true;
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_providerMounted && _isLoading) {
                  _rideSubscription?.cancel();
                  _rideSubscription = null;
                  _isLoading = false;
                  _initialFetchDone = true;
                  _error = null;
                  notifyListeners();
                }
              });
            }
          }
        },
      );

      _rideSubscription = _nostrService.feedRideEventsStream.listen(
            (rideItem) {
          bool listChanged = false;
          try {
            final dTag = rideItem.rawNostrEvent?.tags
                ?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd');
            if (dTag != null && dTag.length > 1) {
              final dValue = dTag[1].toString();
              final existingRide = _ridesByDTag[dValue];
              if (existingRide == null || rideItem.createdAt.isAfter(existingRide.createdAt)) {
                _ridesByDTag[dValue] = rideItem;
                listChanged = true;
              }
            }
          } catch (e) {
            debugPrint("FeedProvider: Error processing event ${rideItem.id}: $e");
          }
          if (listChanged) {
            _isLoading = false;
            _error = null;
            notifyListeners();
          }
        },
        onError: (e) {
          if (_providerMounted) {
            setError("Failed to load rides: $e");
            _initialFetchDone = true;
          }
        },
        onDone: () {
          debugPrint("FeedProvider: Ride stream closed.");
          _rideSubscription = null;
          if (_providerMounted && _isLoading) {
            _isLoading = false;
            _initialFetchDone = true;
            notifyListeners();
          }
        },
      );

      Future.delayed(const Duration(seconds: 10), () {
        if (_providerMounted && _isLoading) {
          _rideSubscription?.cancel();
          _rideSubscription = null;
          _isLoading = false;
          _initialFetchDone = true;
          _error = _ridesByDTag.isEmpty ? "No rides found." : null;
          debugPrint("FeedProvider: Fallback timeout triggered");
          notifyListeners();
        }
      });
    } catch (e) {
      setError("Failed to start fetching rides: $e");
    }
  }

  void setStateLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      if (!loading) _isFetchingDeviceLocation = false;
      notifyListeners();
    }
  }

  void setError(String errorMessage) {
    _error = errorMessage;
    _isLoading = false;
    _isFetchingDeviceLocation = false;
    _isSearchingLocation = false;
    _initialFetchDone = true;
    if (_providerMounted) notifyListeners();
  }

  @override
  void dispose() {
    debugPrint("FeedProvider: Disposing...");
    _rideSubscription?.cancel();
    _nostrService.removeListener(_nostrConnectionListener);
    _providerMounted = false;
    super.dispose();
  }
}