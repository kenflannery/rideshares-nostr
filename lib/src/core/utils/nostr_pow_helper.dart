import 'dart:convert';
import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';


class NostrPowHelper {
  /// Performs NIP-13 Proof-of-Work mining to find a nonce.
  /// Returns the successful nonce tag list element: ["nonce", "<nonce_str>", "<target_str>"]
  /// Returns null if mining fails or is interrupted.
  static Future<List<String>?> minePoW({
    required int targetDifficulty,
    required int kind,
    required DateTime createdAt, // Use consistent timestamp for ID calc
    required String pubkey,      // Pubkey needed for ID calc
    required List<List<String>> tags, // Base tags (excluding nonce)
    required String content,
    int maxAttempts = 10000000,  // Add safety limit to prevent infinite loop
    int startNonce = 0,         // Allow resuming from a previous nonce
  }) async {
    // Use compute for background processing
    final List<String>? result = await compute<Map<String, dynamic>, List<String>?>(
        _powMiningWorker,
        {
          'nonce': startNonce,
          'targetDifficulty': targetDifficulty,
          'tags': tags,
          'content': content,
          'kind': kind,
          'pubkey': pubkey,
          'createdAt': createdAt,
          'maxAttempts': maxAttempts,
        }
    );

    return result;
  }

  /// Worker function that runs in a separate isolate to mine PoW
  static List<String>? _powMiningWorker(Map<String, dynamic> params) {
    int currentNonce = params['nonce'];
    final int target = params['targetDifficulty'];
    final List<List<String>> baseTags = List<List<String>>.from(params['tags']);
    final String eventContent = params['content'];
    final int eventKind = params['kind'];
    final String authorPubkey = params['pubkey'];
    final DateTime creationTime = params['createdAt'];
    final int maxAttempts = params['maxAttempts'];

    int attemptCount = 0;

    debugPrint("NostrPowHelper: Starting PoW mining for difficulty $target...");

    while (attemptCount < maxAttempts) {
      // Create a copy of tags to avoid modifying the original
      final List<List<String>> currentTags = List<List<String>>.from(baseTags);
      final String nonceStr = currentNonce.toString();
      final String targetStr = target.toString();

      // Add nonce tag
      currentTags.add(["nonce", nonceStr, targetStr]);

      // Manually build the event structure needed for ID generation
      final List<dynamic> idData = [
        0,
        authorPubkey,
        creationTime.millisecondsSinceEpoch ~/ 1000,
        eventKind,
        currentTags,
        eventContent,
      ];

      final String serializedIdData = jsonEncode(idData);

      // Calculate SHA256 hash
      final List<int> bytes = utf8.encode(serializedIdData);
      final Digest digest = sha256.convert(bytes);
      final String eventId = digest.toString();

      // Check if hash meets the difficulty target
      final int difficulty = _countLeadingZeroBits(eventId);

      if (difficulty >= target) {
        debugPrint("NostrPowHelper: PoW found! Nonce: $currentNonce, Difficulty: $difficulty, ID: $eventId");
        return ["nonce", nonceStr, targetStr];
      }

      currentNonce++;
      attemptCount++;

      if (currentNonce % 50000 == 0) {
        debugPrint("NostrPowHelper: PoW progress... Nonce: $currentNonce, Attempts: $attemptCount/$maxAttempts");
      }
    }

    debugPrint("NostrPowHelper: PoW mining failed after $maxAttempts attempts.");
    return null;
  }

  /// Count leading zero bits in a hex string
  /// This is a more efficient implementation than using the Nostr utility
  static int _countLeadingZeroBits(String hexString) {
    int leadingZeroBits = 0;

    for (int i = 0; i < hexString.length; i++) {
      final String hexChar = hexString[i];
      final int hexValue = int.parse(hexChar, radix: 16);

      if (hexValue == 0) {
        leadingZeroBits += 4; // Each zero hex character represents 4 zero bits
      } else {
        // Count leading zeros in this hex character
        int bits = 4;
        for (int bit = 3; bit >= 0; bit--) {
          if ((hexValue & (1 << bit)) == 0) {
            leadingZeroBits++;
          } else {
            return leadingZeroBits;
          }
        }
        return leadingZeroBits;
      }
    }

    return leadingZeroBits;
  }
}