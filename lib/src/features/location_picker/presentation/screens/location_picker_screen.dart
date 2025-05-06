import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart'; // Import flutter_map
import 'package:latlong2/latlong.dart'; // Import LatLng
import 'package:osm_nominatim/osm_nominatim.dart'; // Import Nominatim
import 'package:dart_geohash/dart_geohash.dart'; // Import Geohash
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';

import '../../../../core/models/location_model.dart'; // Import our Location model

class LocationPickerScreen extends StatefulWidget {
  // Optional: Pass an initial location to center the map?
  // final LatLng? initialCenter;

  const LocationPickerScreen({
    super.key,
    /* this.initialCenter */
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();
  final GeoHasher _geoHasher = GeoHasher();

  LatLng? _selectedLatLng;
  String _selectedDisplayName = 'Tap map to select location';
  bool _isGeocoding = false;
  String? _geocodingError;

  @override
  void initState() {
    super.initState();
    // TODO: Optionally get user's current location to center initially
  }

  // --- Reverse Geocoding Logic ---
  Future<void> _reverseGeocode(LatLng point) async {
    if (_isGeocoding) return; // Prevent concurrent requests

    setState(() {
      _selectedLatLng = point; // Update selected point immediately
      _isGeocoding = true;
      _geocodingError = null;
      _selectedDisplayName = 'Loading address...'; // Show loading state
    });

    try {
      // IMPORTANT: Set a user agent as required by Nominatim's Usage Policy
      // Replace 'rideshares.org' with your actual app name/contact if possible.
      final Place result = await Nominatim.reverseSearch( // Returns a 'Place' object
        lat: point.latitude,
        lon: point.longitude,
        addressDetails: true,
        extraTags: false,
        nameDetails: false,
        // userAgent parameter may not exist on static method - check package docs if needed
      );

      if (mounted) {
        setState(() {
          _selectedDisplayName = result.displayName ?? 'Address not found';
          _isGeocoding = false;
        });
      }

    } catch (e) {
      debugPrint("Reverse geocoding error: $e");
      if (mounted) {
        setState(() {
          _selectedDisplayName = 'Could not get address';
          _geocodingError = e.toString();
          _isGeocoding = false;
        });
      }
    }
  }

  // --- Confirm Selection ---
  void _confirmSelection() {
    if (_selectedLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location on the map first.')),
      );
      return;
    }
    if (_isGeocoding) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for address lookup to finish.')),
      );
      return;
    }

    // Generate geohash
    final geohash = _geoHasher.encode(
        _selectedLatLng!.longitude,
        _selectedLatLng!.latitude,
        precision: 9 // Use good precision
    );

    // Create the LocationModel to return
    final selectedLocation = LocationModel(
      displayName: _selectedDisplayName, // Use the fetched display name
      latitude: _selectedLatLng!.latitude,
      longitude: _selectedLatLng!.longitude,
      geohash: geohash,
    );

    // Pop the screen and return the selected location
    Navigator.of(context).pop(selectedLocation);
  }


  // --- Build Method ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Location'),
        actions: [
          // Confirm Button
          IconButton(
            icon: const Icon(Icons.check),
            tooltip: 'Confirm Location',
            // Disable if no location selected or still loading address
            onPressed: (_selectedLatLng == null || _isGeocoding) ? null : _confirmSelection,
          )
        ],
      ),
      // Use Stack to overlay map and info panel
      body: Stack(
        children: [
          // Map View
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _selectedLatLng ?? const LatLng(51.5074, -0.1278), // Default to London if none selected
              initialZoom: 13.0,
              onTap: (tapPosition, point) => _reverseGeocode(point), // Trigger geocoding on tap
              // onLongPress: (tapPosition, point) => _reverseGeocode(point), // Or use long press
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate, // Allow all except rotate
              ),
            ),
            children: [
              // Base Map Layer (OpenStreetMap)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'org.rideshares.rideshares_app', // ** CHANGE AS NEEDED **
                tileProvider: CancellableNetworkTileProvider(),
                // Add fallback URLs if needed
              ),

              // Marker Layer to show selected point
              if (_selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _selectedLatLng!,
                      width: 80.0,
                      height: 80.0,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40.0,
                      ),
                      // Optional: Adjust anchor point if needed
                      // anchorPos: AnchorPos.align(AnchorAlign.top),
                    ),
                  ],
                ),
            ],
          ),

          // --- Bottom Info Panel ---
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material( // Use Material for background/elevation
              elevation: 4.0,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Display Selected Address or Loading/Error state
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDisplayName,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isGeocoding)
                          const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2)
                          ),
                      ],
                    ),
                    if (_geocodingError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'Error: $_geocodingError',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // Confirm button also here for convenience? Or just AppBar is fine.
                    // ElevatedButton.icon(
                    //    icon: const Icon(Icons.check_circle_outline),
                    //    label: const Text('Confirm This Location'),
                    //    onPressed: (_selectedLatLng == null || _isGeocoding) ? null : _confirmSelection,
                    // ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}