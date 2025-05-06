import 'package:dart_nostr/dart_nostr.dart';
import 'package:dart_geohash/dart_geohash.dart';
import 'package:intl/intl.dart'; // For formatting in title/content
import 'package:flutter/foundation.dart';
import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:crypto/crypto.dart';

import '../models/location_model.dart';
import '../models/ride_item_model.dart'; // For RideType enum

/// Helper functions for creating specific Nostr events.
class NostrEventHelper {
  static final _geoHasher = GeoHasher();

  /// Generates cascading geohash tags (e.g., ["g", "abc"], ["g", "ab"], ["g", "a"])
  static List<List<String>> generateGeohashTags(
      String geohash, int maxLength, String tagPrefix) {
    List<List<String>> geohashTags = [];
    final effectiveLength = geohash.length < maxLength ? geohash.length : maxLength;
    // Ensure loop runs at least once if geohash is not empty
    if (geohash.isNotEmpty) {
      for (int i = 1; i <= effectiveLength; i++) {
        geohashTags.add([tagPrefix, geohash.substring(0, i)]);
      }
    }
    return geohashTags;
  }


  /// Creates a NIP-99 (Kind 30402) NostrEvent for a rideshare.
  static NostrEvent? createRideEvent({
    required RideType rideType,
    required LocationModel origin,
    required LocationModel destination,
    required DateTime departureTimeUtc,
    required String originTimezone,
    required String description,
    required String signingKey, // HEX private key
    required String dTagIdentifier, // Unique identifier for 'd' tag
    String priceAmount = "0", // Default to 0 (Free/Negotiable)
    String priceCurrency = "USD", // Default currency
  }) {
    try {
      // --- Prepare Event Data ---
      final offerOrRequest = rideType == RideType.offer ? 'offer' : 'request';
      final typeTag = rideType == RideType.offer ? 'ride-offer' : 'ride-request';

      final title = "Rideshare $offerOrRequest from ${origin.displayName} to ${destination.displayName}";

      // Format departure time nicely for the content string, including timezone
      // TODO: Use timezone package for more robust formatting later if needed
      String formattedDeparture;
      try {
        final location = tz.getLocation(originTimezone);
        final localizedDt = tz.TZDateTime.from(departureTimeUtc, location);
        formattedDeparture = DateFormat("MMM d y, hh:mm a z").format(localizedDt); // e.g., Oct 26 2023, 09:00 AM EDT
      } catch(_) {
        formattedDeparture = '${DateFormat("MMM d y, HH:mm").format(departureTimeUtc)} UTC';
      }


      final fullContent = '$description\n\n'
          'Type: $offerOrRequest\n'
          'Departure: $formattedDeparture\n'
          'Origin: ${origin.displayName}\n'
          'Destination: ${destination.displayName}\n\n'
          'NOTE: This ride was posted via Rideshares.org.';
      final summary = description.length > 100 ? '${description.substring(0, 97)}...' : description;



      // Generate geohash tags (adjust maxLength as needed, e.g., 6 for reasonable area)
      final originGeohashTags = generateGeohashTags(origin.geohash, 6, "g");
      final destGeohashTags = generateGeohashTags(destination.geohash, 6, "dg");

      List<String> priceTag = ["price", priceAmount, priceCurrency];

      // --- Get KeyPair for Signing ---
      final NostrKeyPairs keyPairs = Nostr.instance.services.keys
          .generateKeyPairFromExistingPrivateKey(signingKey);

      // --- Prepare published_at timestamp ---
      // Use current time for initial publication
      final publishedAtTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final publishedAtString = publishedAtTimestamp.toString();

      // --- Create Event using fromPartialData ---
      final event = NostrEvent.fromPartialData(
        kind: 30402, // NIP-99 Classifieds
        content: fullContent,
        keyPairs: keyPairs, // Pass NostrKeyPairs for automatic signing & pubkey
        tags: [
          ["d", dTagIdentifier], // Unique identifier for the listing
          ["title", title],
          ["published_at", publishedAtString], // NIP-99 specific tag
          ["summary", summary],
          // published_at is handled automatically by fromPartialData if keyPairs provided
          ["t", "Services"], // used in shopstr
          ["t", "rideshare"],
          ["t", "rideshares.org"], // App-specific tag
          ["t", typeTag], // ride-offer or ride-request
          ...originGeohashTags,
          ...destGeohashTags,
          [
            "image",
            "https://image.nostr.build/8b24a94d7f10547327d1e172d7273fa2b7ce8e123d316192d9611559cfccd50f.jpg"
          ], // TODO different images for offer vs request
          ["location", origin.displayName], // Human-readable origin still useful
          priceTag,
          ["status", "active"], // New posts are active
          // Custom tags for easier parsing by our app:
          ["departure_utc", (departureTimeUtc.millisecondsSinceEpoch ~/ 1000).toString()],
          ["origin_tz", originTimezone],
          ["location_dest", destination.displayName], // Destination Name
          ["origin_lat", origin.latitude.toString()],
          ["origin_lon", origin.longitude.toString()],
          ["dest_lat", destination.latitude.toString()],
          ["dest_lon", destination.longitude.toString()],
        ],
      );
      return event;

    } catch (e) {
      debugPrint("Error creating ride event object: $e");
      return null;
    }
  }

  /*/// Performs NIP-13 Proof-of-Work mining to find a nonce.
  /// Returns the successful nonce tag list element: ["nonce", "<nonce_str>", "<target_str>"]
  /// Returns null if mining fails or is interrupted.
  static Future<List<String>?> minePoW({
    required int targetDifficulty,
    required int kind,
    required DateTime createdAt, // Use consistent timestamp for ID calc
    required String pubkey,      // Pubkey needed for ID calc
    required List<List<String>> tags, // Base tags (excluding nonce)
    required String content,
  }) async {
    final List<String>? result = await compute<Map<String, dynamic>, List<String>?>((params) {
      int currentNonce = params['nonce']; // Starting nonce
      final int target = params['targetDifficulty'];
      final List<List<String>> baseTags = params['tags'];
      final String eventContent = params['content'];
      final int eventKind = params['kind'];
      final String authorPubkey = params['pubkey']; // Use correct variable name
      final DateTime creationTime = params['createdAt'];

      debugPrint("NostrEventHelper (compute): Starting PoW mining for difficulty $target...");

      while (true) { // Be cautious with infinite loops in production
        final List<List<String>> currentTags = List.from(baseTags);
        final String nonceStr = currentNonce.toString();
        final String targetStr = target.toString();
        currentTags.add(["nonce", nonceStr, targetStr]);

        // Manually build the data structure needed for ID generation
        final List<dynamic> idData = [
          0,
          authorPubkey,
          creationTime.millisecondsSinceEpoch ~/ 1000,
          eventKind,
          currentTags,
          eventContent,
        ];
        final String serializedIdData = jsonEncode(idData);

        // --- CORRECTED: Use crypto package for SHA256 ---
        // 1. Encode the JSON string to UTF-8 bytes
        List<int> bytes = utf8.encode(serializedIdData);
        // 2. Hash the bytes using SHA256
        Digest digest = sha256.convert(bytes);
        // 3. The event ID is the hexadecimal representation of the digest bytes
        final String eventId = digest.toString();
        // --- End Correction ---

        final int difficulty = Nostr.instance.services.utils.countDifficultyOfHex(eventId); // This utility should still work

        if (difficulty >= target) {
          debugPrint("NostrEventHelper (compute): PoW found! Nonce: $currentNonce, Difficulty: $difficulty, ID: $eventId");
          // Return the successful nonce tag
          return ["nonce", nonceStr, targetStr];
        }

        currentNonce++;
        if (currentNonce % 50000 == 0) {
          debugPrint("NostrEventHelper (compute): PoW check... Nonce: $currentNonce");
        }
      }
      // return null; // Potentially needed if loop can exit
    }, {
      'nonce': 0, // Start nonce at 0
      'targetDifficulty': targetDifficulty,
      'tags': tags,
      'content': content,
      'kind': kind,
      'pubkey': pubkey, // Pass pubkey to isolate
      'createdAt': createdAt, // Pass consistent timestamp
    });

    return result;
  }*/


}