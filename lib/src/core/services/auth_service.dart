import 'package:dart_nostr/nostr/instance/bech32/bech32.dart';
import 'package:dart_nostr/nostr/instance/keys/keys.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:dart_nostr/dart_nostr.dart'; // Correct import
import 'dart:async';

/// Service responsible for managing NOSTR keys (generation, storage, retrieval)
/// using dart_nostr and flutter_secure_storage.
class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();
  final _nsecStorageKey = 'nostr_nsec_key';

  // Internal state
  String? _nsec;
  String? _hexPrivateKey;
  String? _npub;
  String? _hexPublicKey;
  bool _showNsec = false; // New flag to toggle nsec visibility

  // Public getters
  String? get npub => _npub;
  bool get isLoggedIn => _nsec != null && _npub != null;
  String? get signingKey => _hexPrivateKey; // Hex private key for signing
  bool get showNsec => _showNsec; // Getter for visibility state
  String? get nsec => _nsec != null ? (_showNsec ? _nsec : _nsec!.replaceAll(RegExp(r'[a-zA-Z0-9]'), '•')) : 'Not available';

  // Access Correct Services
  final NostrKeys _keysService = Nostr.instance.services.keys;
  final NostrBech32 _bech32Service = Nostr.instance.services.bech32;

  Future<void> loadKey() async {
    _clearInternalState(notify: false);
    final storedNsec = await _storage.read(key: _nsecStorageKey);

    if (storedNsec != null && storedNsec.isNotEmpty) {
      try {
        // 1. Decode nsec -> hex using SPECIFIC Bech32 method
        final hexPrivKey = _bech32Service.decodeNsecKeyToPrivateKey(storedNsec);

        // 2. Derive public key using Keys Service
        final hexPubKey = _keysService.derivePublicKey(privateKey: hexPrivKey);

        // 3. Encode public key -> npub using SPECIFIC Bech32 method
        final npubKey = _bech32Service.encodePublicKeyToNpub(hexPubKey);

        // Update internal state
        _nsec = storedNsec;
        _hexPrivateKey = hexPrivKey;
        _hexPublicKey = hexPubKey;
        _npub = npubKey;

        debugPrint('AuthService: NOSTR Key loaded successfully. Npub: $_npub');
      } catch (e) {
        debugPrint('AuthService: Error loading/parsing stored NOSTR key: $e');
        await clearKey();
      }
    } else {
      debugPrint('AuthService: No NOSTR key found in storage.');
    }
    notifyListeners();
  }

  Future<String?> generateNewKey() async {
    try {
      // 1. Generate Hex Key Pair using Keys Service
      final NostrKeyPairs keyPair = _keysService.generateKeyPair();
      final hexPrivKey = keyPair.private;
      final hexPubKey = keyPair.public;

      // 2. Encode private key -> nsec using SPECIFIC Bech32 method
      final nsecKey = _bech32Service.encodePrivateKeyToNsec(hexPrivKey);

      // 3. Encode public key -> npub using SPECIFIC Bech32 method
      final npubKey = _bech32Service.encodePublicKeyToNpub(hexPubKey);

      // 4. Store nsec securely
      await _storage.write(key: _nsecStorageKey, value: nsecKey);

      // 5. Update internal state
      _nsec = nsecKey;
      _hexPrivateKey = hexPrivKey;
      _hexPublicKey = hexPubKey;
      _npub = npubKey;

      debugPrint('AuthService: New NOSTR Key generated and stored. Npub: $_npub');
      notifyListeners();
      return nsecKey; // Return nsec for user backup
    } catch (e) {
      debugPrint('AuthService: Error generating new NOSTR key: $e');
      await clearKey();
      return null;
    }
  }

  Future<bool> importKey(String nsecInput) async {
    if (nsecInput.isEmpty || !nsecInput.startsWith('nsec')) {
      debugPrint('AuthService: Import failed - Invalid nsec format.');
      return false;
    }
    try {
      // 1. Validate by decoding nsec -> hex using SPECIFIC Bech32 method
      final hexPrivKey = _bech32Service.decodeNsecKeyToPrivateKey(nsecInput);

      // 2. Derive public key using Keys Service
      final hexPubKey = _keysService.derivePublicKey(privateKey: hexPrivKey);

      // 3. Re-encode public key -> npub using SPECIFIC Bech32 method
      final npubKey = _bech32Service.encodePublicKeyToNpub(hexPubKey);

      // 4. Store validated nsec
      await _storage.write(key: _nsecStorageKey, value: nsecInput);

      // 5. Update internal state
      _nsec = nsecInput;
      _hexPrivateKey = hexPrivKey;
      _hexPublicKey = hexPubKey;
      _npub = npubKey;

      debugPrint('AuthService: NOSTR Key imported successfully. Npub: $_npub');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error importing provided NOSTR key (nsec: $nsecInput): $e');
      return false;
    }
  }

  Future<void> clearKey() async {
    await _storage.delete(key: _nsecStorageKey);
    _clearInternalState(notify: true);
    debugPrint('AuthService: Stored NOSTR key cleared.');
  }

  void toggleNsecVisibility() {
    _showNsec = !_showNsec;
    notifyListeners();
  }

  void _clearInternalState({bool notify = true}) {
    _nsec = null;
    _hexPrivateKey = null;
    _npub = null;
    _hexPublicKey = null;
    _showNsec = false; // Reset visibility on logout
    if (notify) {
      notifyListeners();
    }
  }
}