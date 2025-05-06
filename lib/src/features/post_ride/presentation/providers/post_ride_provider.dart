import 'package:flutter/material.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:uuid/uuid.dart';
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as latLngToTimezone;
import '../../../../core/models/location_model.dart';
import '../../../../core/models/ride_item_model.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/nostr_service.dart';
import '../../../../core/utils/nostr_event_helpers.dart';
import 'dart:math';
import 'package:collection/collection.dart';

class PostRideProvider with ChangeNotifier {
  final AuthService _authService;
  final NostrService _nostrService;

  // Form State
  RideType _rideType = RideType.offer;
  LocationModel? _origin;
  LocationModel? _destination;
  DateTime? _departureDate;
  TimeOfDay? _departureTime;
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCurrency = 'USD';
  final List<String> _currencies = ['USD', 'EUR', 'GBP', 'CAD', 'AUD', 'JPY', 'CHF', 'BTC', 'SATS'];

  // Editing State
  RideItemModel? _rideToEdit;
  String? _dTagValue;

  // UI State
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  // Getters
  RideType get rideType => _rideType;
  LocationModel? get origin => _origin;
  LocationModel? get destination => _destination;
  DateTime? get departureDate => _departureDate;
  TimeOfDay? get departureTime => _departureTime;
  TextEditingController get descriptionController => _descriptionController;
  TextEditingController get priceController => _priceController;
  String get selectedCurrency => _selectedCurrency;
  List<String> get currencies => _currencies;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get successMessage => _successMessage;
  bool get isEditing => _rideToEdit != null;

  // Utilities
  final _geoHasher = GeoHasher();
  final _uuid = const Uuid();

  PostRideProvider(this._authService, this._nostrService, {RideItemModel? rideToEdit}) {
    if (rideToEdit != null) {
      _initializeForEdit(rideToEdit);
    }
    _nostrService.addListener(_handleNostrConnectionChange);
  }

  void _handleNostrConnectionChange() {
    if (_nostrService.connectionState == NostrConnectionState.disconnected && _isLoading) {
      setError("Lost connection to Nostr relays.");
    } else if (_nostrService.connectionState == NostrConnectionState.reconnecting) {
      setStateLoading(true);
      _error = "Reconnecting to relays...";
      notifyListeners();
    }
  }

  void _initializeForEdit(RideItemModel ride) {
    _rideToEdit = ride;
    _rideType = ride.type;
    _origin = ride.origin;
    _destination = ride.destination;
    _departureDate = ride.departureTimeUtc;
    _departureTime = TimeOfDay.fromDateTime(ride.departureTimeUtc);
    _descriptionController.text = ride.description;
    _priceController.text = ride.priceAmount ?? '0';
    _selectedCurrency = ride.priceCurrency ?? 'USD';
    _dTagValue = ride.rawNostrEvent?.tags?.firstWhereOrNull((t) => t is List && t.isNotEmpty && t[0] == 'd')?[1].toString();
    notifyListeners();
  }

  void setRideType(RideType type) {
    if (_rideType != type) {
      _rideType = type;
      notifyListeners();
    }
  }

  void setOrigin(LocationModel location) {
    _origin = location;
    _error = null;
    notifyListeners();
  }

  void setDestination(LocationModel location) {
    _destination = location;
    _error = null;
    notifyListeners();
  }

  void setDepartureDate(DateTime date) {
    _departureDate = date;
    notifyListeners();
  }

  void setDepartureTime(TimeOfDay time) {
    _departureTime = time;
    notifyListeners();
  }

  void setCurrency(String currency) {
    if (_currencies.contains(currency)) {
      _selectedCurrency = currency;
      notifyListeners();
    }
  }

  void clearSuccessMessage() {
    _successMessage = null;
    notifyListeners();
  }

  Future<RideItemModel?> submitRide() async {
    if (_isLoading) return null;
    if (_nostrService.connectionState != NostrConnectionState.connected) {
      setError("Cannot post ride, not connected to Nostr.");
      return null;
    }

    _error = null;
    _successMessage = null;

    // Validation
    if (_origin == null || _destination == null) {
      setError("Please select origin and destination.");
      return null;
    }
    if (_departureDate == null || _departureTime == null) {
      setError("Please select departure date and time.");
      return null;
    }
    final description = _descriptionController.text.trim();
    if (description.isEmpty) {
      setError("Please enter a description.");
      return null;
    }
    if (!_authService.isLoggedIn || _authService.signingKey == null) {
      setError("Authentication error. Please ensure you are logged in.");
      return null;
    }

    setStateLoading(true);

    try {
      // Prepare Data
      DateTime departureDateTime = DateTime(
        _departureDate!.year,
        _departureDate!.month,
        _departureDate!.day,
        _departureTime!.hour,
        _departureTime!.minute,
      );

      String originTimezone = 'UTC';
      try {
        final timezoneName = await latLngToTimezone.latLngToTimezoneString(_origin!.latitude, _origin!.longitude);
        originTimezone = timezoneName;
        final location = tz.getLocation(timezoneName);
        final originTzDateTime = tz.TZDateTime(
          location,
          departureDateTime.year,
          departureDateTime.month,
          departureDateTime.day,
          departureDateTime.hour,
          departureDateTime.minute,
        );
        departureDateTime = originTzDateTime.toUtc();
      } catch (e) {
        debugPrint("Timezone lookup failed: $e. Using UTC.");
        if (!departureDateTime.isUtc) {
          departureDateTime = departureDateTime.toUtc();
        }
      }

      final priceInput = _priceController.text.trim();
      final priceAmount = (double.tryParse(priceInput) ?? 0).toString();

      final event = NostrEventHelper.createRideEvent(
        rideType: _rideType,
        origin: _origin!,
        destination: _destination!,
        departureTimeUtc: departureDateTime,
        originTimezone: originTimezone,
        description: description,
        signingKey: _authService.signingKey!,
        dTagIdentifier: _rideToEdit != null ? _dTagValue! : _uuid.v4(),
        priceAmount: priceAmount,
        priceCurrency: _selectedCurrency,
      );

      if (event == null) {
        throw Exception("Failed to create Nostr event.");
      }

      // Publish with retries
      const maxRetries = 3;
      bool success = false;
      for (int attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          success = await _nostrService.publishEvent(event);
          if (success) {
            _successMessage = _rideToEdit != null ? "Ride updated successfully!" : "Ride posted successfully!";
            _resetForm();
            setStateLoading(false); // Explicitly reset loading state
            break;
          } else {
            debugPrint("PostRideProvider: Failed to publish event (attempt $attempt).");
          }
        } catch (e) {
          debugPrint("PostRideProvider: Error publishing event (attempt $attempt): $e");
        }
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: min(60, pow(2, attempt).toInt())));
        }
      }

      if (!success) {
        setError("Failed to publish ride to Nostr relays after $maxRetries attempts.");
        return null;
      }

      // Create RideItemModel for navigation
      final rideItem = RideItemModel.fromNostrEvent(event);
      return rideItem;
    } catch (e) {
      setError("An error occurred: $e");
      return null;
    } finally {
      setStateLoading(false); // Ensure loading is reset in all cases
    }
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
    notifyListeners();
  }

  void _resetForm() {
    _rideType = RideType.offer;
    _origin = null;
    _destination = null;
    _departureDate = null;
    _departureTime = null;
    _priceController.clear();
    _descriptionController.clear();
    _selectedCurrency = 'USD';
    _rideToEdit = null;
    _dTagValue = null;
    _error = null;
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _priceController.dispose();
    _nostrService.removeListener(_handleNostrConnectionChange);
    super.dispose();
  }
}