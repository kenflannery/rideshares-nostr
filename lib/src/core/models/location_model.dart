import 'package:flutter/foundation.dart';

/// Represents a geographical location with display name, coordinates, and geohash.
@immutable // Good practice for model classes passed around
class LocationModel {
  final String displayName;
  final double latitude;
  final double longitude;
  final String geohash; // Geohash for the location

  const LocationModel({
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.geohash,
  });

  // Optional: Factory constructor for creating from a map (useful for JSON/Nostr parsing later)
  factory LocationModel.fromMap(Map<String, dynamic> map) {
    // TODO: Implement robust parsing later based on how location is stored in Nostr event
    return LocationModel(
      displayName: map['displayName'] ?? 'Unknown Location',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      geohash: map['geohash'] ?? '',
    );
  }

  // Optional: Method to convert to a map (useful for storing or sending)
  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'latitude': latitude,
      'longitude': longitude,
      'geohash': geohash,
    };
  }

  // Optional: Equatable or manual equality overrides for comparison
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is LocationModel &&
              runtimeType == other.runtimeType &&
              displayName == other.displayName &&
              latitude == other.latitude &&
              longitude == other.longitude &&
              geohash == other.geohash;

  @override
  int get hashCode =>
      displayName.hashCode ^
      latitude.hashCode ^
      longitude.hashCode ^
      geohash.hashCode;

  @override
  String toString() {
    return 'LocationModel(displayName: $displayName, lat: $latitude, lon: $longitude, geohash: $geohash)';
  }
}