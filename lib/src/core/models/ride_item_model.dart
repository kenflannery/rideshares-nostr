import 'package:flutter/foundation.dart';
import 'package:dart_nostr/dart_nostr.dart'; // Import NostrEvent

import 'location_model.dart'; // Import the Location model

// Enum for Ride Type
enum RideType { offer, request, partner, unknown }

// Enum for Ride Status (can align with NIP-99 or be more detailed internally)
enum RideStatus { active, filled, cancelled, expired, unknown }


/// Represents a single rideshare posting (offer or request).
@immutable
class RideItemModel {
  final String id; // Use Nostr event ID
  final String pubkey; // Author's public key (hex)
  final DateTime createdAt; // Nostr event timestamp
  final DateTime publishedAt;
  final String title;
  final RideType type;
  final LocationModel origin;
  final LocationModel destination;
  final DateTime departureTimeUtc;
  final String? originTimezone; // IANA timezone name (e.g., "America/New_York")
  final String description;
  final RideStatus status;
  final String? priceAmount;
  final String? priceCurrency;
  // Optional: Keep the original Nostr event for reference or advanced features
  final NostrEvent? rawNostrEvent;

  const RideItemModel({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.publishedAt,
    required this.title,
    required this.type,
    required this.origin,
    required this.destination,
    required this.departureTimeUtc,
    this.originTimezone,
    required this.description,
    required this.status,
    this.rawNostrEvent,
    this.priceAmount,
    this.priceCurrency,
  });

  // --- Factory constructor for parsing from a NostrEvent ---
  // This will be complex and needs careful implementation based on NIP-99 tags
  factory RideItemModel.fromNostrEvent(NostrEvent event) {
    // Basic Info
    final id = event.id;
    final pubkey = event.pubkey;
    final createdAt = event.createdAt;
    final content = event.content;

    // Parse Tags
    String? title;
    String? publishedAtStr;
    RideType type = RideType.unknown;
    RideStatus status = RideStatus.unknown;
    String? priceAmount; // Store price parts
    String? priceCurrency;
    // String? priceFrequency;
    String? originDisplayName; // From 'location' tag
    String? originTz;
    String? departureTimestampStr; // From custom tag
    List<String> originGeohashes = [];
    List<String> destGeohashes = [];
    // --- Add variables for new tags ---
    String? locationDestName;
    String? originLatStr;
    String? originLonStr;
    String? destLatStr;
    String? destLonStr;
    // --- End new variables ---


    for (final tag in event.tags ?? []) {
      if (tag is! List<dynamic> || tag.isEmpty) continue;

      final tagName = tag[0].toString();
      final tagValue = tag.length > 1 ? tag[1].toString() : '';

      switch (tagName) {
        case 'title': title = tagValue; break;
        case 'published_at': publishedAtStr = tagValue; break;
        case 't':
          if (tagValue == 'ride-offer') type = RideType.offer;
          if (tagValue == 'ride-request') type = RideType.request;
          if (tagValue == 'travel-partner') type = RideType.partner;
          break;
        case 'status':
          if (tagValue == 'active') status = RideStatus.active;
          if (tagValue == 'sold' || tagValue == 'filled') status = RideStatus.filled;
          break;
        case 'price':
          if (tag.length > 1) priceAmount = tag[1].toString();
          if (tag.length > 2) priceCurrency = tag[2].toString();
          // if (tag.length > 3) priceFrequency = tag[3].toString();
          break;
        case 'location': originDisplayName = tagValue; break; // Standard origin name
        case 'g': originGeohashes.add(tagValue); break;
        case 'dg': destGeohashes.add(tagValue); break;
        case 'departure_utc': departureTimestampStr = tagValue; break; // Use custom tag
        case 'origin_tz': originTz = tagValue; break;
      // --- Parse NEW tags ---
        case 'location_dest': locationDestName = tagValue; break;
        case 'origin_lat': originLatStr = tagValue; break;
        case 'origin_lon': originLonStr = tagValue; break;
        case 'dest_lat': destLatStr = tagValue; break;
        case 'dest_lon': destLonStr = tagValue; break;
      // --- End parse NEW tags ---
      }
    }

    // --- Post-processing & Defaults ---
    // Parse published_at, fall back to createdAt if missing/invalid
    DateTime publishedAtTime = event.createdAt ?? DateTime.now().toUtc(); // Default to event creation
    if (publishedAtStr != null) {
      final timestamp = int.tryParse(publishedAtStr);
      if (timestamp != null) {
        publishedAtTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
      }
    }

    // Post-processing & Defaults
    DateTime departureTime = createdAt ?? DateTime.now().toUtc(); // Fallback
    if (departureTimestampStr != null) {
      final timestamp = int.tryParse(departureTimestampStr);
      if (timestamp != null) {
        departureTime = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
      }
    }

    // --- Create LocationModels using parsed data ---
    final originLat = double.tryParse(originLatStr ?? '') ?? 0.0;
    final originLon = double.tryParse(originLonStr ?? '') ?? 0.0;
    final destLat = double.tryParse(destLatStr ?? '') ?? 0.0;
    final destLon = double.tryParse(destLonStr ?? '') ?? 0.0;

    final origin = LocationModel(
      displayName: originDisplayName ?? 'Origin Unknown', // Use 'location' tag
      latitude: originLat, // Use parsed value
      longitude: originLon, // Use parsed value
      geohash: originGeohashes.isNotEmpty ? originGeohashes.reduce((a, b) => a.length > b.length ? a : b) : '',
    );
    final destination = LocationModel(
      displayName: locationDestName ?? title?.split(' to ').last ?? 'Destination Unknown', // Use 'location_dest' tag
      latitude: destLat, // Use parsed value
      longitude: destLon, // Use parsed value
      geohash: destGeohashes.isNotEmpty ? destGeohashes.reduce((a, b) => a.length > b.length ? a : b) : '',
    );
    // --- End LocationModel creation ---

    final description = content ?? title ?? 'No description.';


    return RideItemModel(
      id: id ?? 'invalid_id',
      pubkey: pubkey ?? 'invalid_pubkey',
      createdAt: createdAt ?? DateTime.now().toUtc(),
      publishedAt: publishedAtTime, // Parsed NIP-99 tag
      title: title ?? 'No Title',
      type: type,
      origin: origin,
      destination: destination,
      departureTimeUtc: departureTime,
      originTimezone: originTz,
      description: description,
      status: status,
      rawNostrEvent: event,
      priceAmount: priceAmount,
      priceCurrency: priceCurrency,
    );
  }


  // Optional: Equatable or manual equality/hashCode
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is RideItemModel &&
              runtimeType == other.runtimeType &&
              id == other.id; // ID is usually sufficient for uniqueness

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'RideItemModel(id: $id, type: $type, from: ${origin.displayName}, to: ${destination.displayName}, time: $departureTimeUtc, status: $status)';
  }
}