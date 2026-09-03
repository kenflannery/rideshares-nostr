import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk_amber/ndk_amber.dart';
import 'package:nip07_event_signer/nip07_event_signer.dart';
import 'package:amberflutter/amberflutter.dart';
import 'package:bip340/bip340.dart' as bip340;

import 'nostr_service.dart';
import 'nip46_helper.dart';

enum LoginType { nsec, nip07, amber, nip46 }

/// Service responsible for managing NOSTR authentication and signers
/// (Local Key, NIP-07 extension, Amber NIP-55, Remote Bunker NIP-46).
class AuthService with ChangeNotifier {
  final _storage = const FlutterSecureStorage();

  static const _loginTypeStorageKey = 'nostr_login_type';
  static const _nsecStorageKey = 'nostr_nsec_key';
  static const _bunkerConnectionStorageKey = 'nostr_bunker_connection';
  static const _bunkerUserPubkeyStorageKey = 'nostr_bunker_user_pubkey';
  static const _amberPubkeyStorageKey = 'nostr_amber_pubkey';
  static const _nip07PubkeyStorageKey = 'nostr_nip07_pubkey';

  // Internal state
  LoginType? _loginType;
  EventSigner? _signer;
  String? _nsec;
  String? _hexPrivateKey;
  String? _npub;
  String? _hexPublicKey;
  bool _showNsec = false;

  // Getters
  LoginType? get loginType => _loginType;
  EventSigner? get signer => _signer;
  String? get npub => _npub;
  String? get hexPublicKey => _hexPublicKey;
  String? get signingKey => _hexPrivateKey;
  bool get isLoggedIn => _signer != null && _hexPublicKey != null;
  bool get showNsec => _showNsec;
  String? get nsec => _nsec != null
      ? (_showNsec ? _nsec : _nsec!.replaceAll(RegExp(r'[a-zA-Z0-9]'), '•'))
      : 'Not available';

  Future<void> loadKey({NostrService? nostrService}) async {
    _clearInternalState(notify: false);

    final storedType = await _storage.read(key: _loginTypeStorageKey);

    if (storedType == LoginType.nsec.name || storedType == null) {
      final storedNsec = await _storage.read(key: _nsecStorageKey);
      if (storedNsec != null && storedNsec.isNotEmpty) {
        await _loadNsec(storedNsec);
      }
    } else if (storedType == LoginType.amber.name) {
      final storedPubkey = await _storage.read(key: _amberPubkeyStorageKey);
      if (storedPubkey != null && storedPubkey.isNotEmpty) {
        await _setupAmberSigner(storedPubkey);
      }
    } else if (storedType == LoginType.nip07.name) {
      final storedPubkey = await _storage.read(key: _nip07PubkeyStorageKey);
      if (storedPubkey != null && storedPubkey.isNotEmpty) {
        await _setupNip07Signer(storedPubkey);
      }
    } else if (storedType == LoginType.nip46.name && nostrService != null) {
      final storedBunkerJson = await _storage.read(key: _bunkerConnectionStorageKey);
      final storedUserPubkey = await _storage.read(key: _bunkerUserPubkeyStorageKey);
      if (storedBunkerJson != null && storedBunkerJson.isNotEmpty) {
        try {
          final bunkerConn = BunkerConnection.fromJson(jsonDecode(storedBunkerJson));
          await _setupBunkerSigner(bunkerConn, nostrService, explicitUserPubkey: storedUserPubkey);
        } catch (e) {
          debugPrint("AuthService: Error reloading bunker connection: $e");
          await clearKey();
        }
      }
    }

    notifyListeners();
  }

  Future<void> _loadNsec(String nsecInput) async {
    try {
      String hexPrivKey;
      if (nsecInput.startsWith('nsec')) {
        hexPrivKey = Nip19.decode(nsecInput);
      } else {
        hexPrivKey = nsecInput;
      }

      final hexPubKey = bip340.getPublicKey(hexPrivKey);
      final npubKey = Nip19.encodePubKey(hexPubKey);
      final nsecKey = Nip19.encodePrivateKey(hexPrivKey);

      _signer = Bip340EventSigner(
        privateKey: hexPrivKey,
        publicKey: hexPubKey,
      );

      _nsec = nsecKey;
      _hexPrivateKey = hexPrivKey;
      _hexPublicKey = hexPubKey;
      _npub = npubKey;
      _loginType = LoginType.nsec;

      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nsec.name);
      await _storage.write(key: _nsecStorageKey, value: nsecKey);
      debugPrint('AuthService: Local Nostr key loaded. Npub: $_npub');
    } catch (e) {
      debugPrint('AuthService: Error loading nsec: $e');
      await clearKey();
    }
  }

  Future<String?> generateNewKey() async {
    try {
      final random = Random.secure();
      final bytes = List<int>.generate(32, (_) => random.nextInt(256));
      final hexPrivKey = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      final hexPubKey = bip340.getPublicKey(hexPrivKey);
      final nsecKey = Nip19.encodePrivateKey(hexPrivKey);
      final npubKey = Nip19.encodePubKey(hexPubKey);

      _signer = Bip340EventSigner(
        privateKey: hexPrivKey,
        publicKey: hexPubKey,
      );

      _nsec = nsecKey;
      _hexPrivateKey = hexPrivKey;
      _hexPublicKey = hexPubKey;
      _npub = npubKey;
      _loginType = LoginType.nsec;

      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nsec.name);
      await _storage.write(key: _nsecStorageKey, value: nsecKey);

      debugPrint('AuthService: New NOSTR Key generated and stored. Npub: $_npub');
      notifyListeners();
      return nsecKey;
    } catch (e) {
      debugPrint('AuthService: Error generating new NOSTR key: $e');
      await clearKey();
      return null;
    }
  }

  Future<bool> importKey(String nsecInput) async {
    final trimmed = nsecInput.trim();
    if (trimmed.isEmpty) {
      debugPrint('AuthService: Import failed - Empty input.');
      return false;
    }
    try {
      await _loadNsec(trimmed);
      notifyListeners();
      return isLoggedIn;
    } catch (e) {
      debugPrint('AuthService: Error importing provided NOSTR key: $e');
      return false;
    }
  }

  Future<bool> isAmberAvailable() async {
    try {
      final amberDs = AmberFlutterDS(Amberflutter());
      return await amberDs.amber.isAppInstalled();
    } catch (_) {
      return false;
    }
  }

  Future<bool> loginWithAmber() async {
    try {
      final amberDs = AmberFlutterDS(Amberflutter());
      final res = await amberDs.amber.getPublicKey();
      final pubkeyHexOrNpub = res['signature'] ?? res['pubkey'];

      if (pubkeyHexOrNpub == null || pubkeyHexOrNpub.isEmpty) {
        debugPrint('AuthService: No public key returned from Amber.');
        return false;
      }

      String hexPubKey;
      String npubKey;
      if (pubkeyHexOrNpub.startsWith('npub')) {
        hexPubKey = Nip19.decode(pubkeyHexOrNpub);
        npubKey = pubkeyHexOrNpub;
      } else {
        hexPubKey = pubkeyHexOrNpub;
        npubKey = Nip19.encodePubKey(hexPubKey);
      }

      await _setupAmberSigner(hexPubKey);
      await _storage.write(key: _loginTypeStorageKey, value: LoginType.amber.name);
      await _storage.write(key: _amberPubkeyStorageKey, value: hexPubKey);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error logging in with Amber: $e');
      return false;
    }
  }

  Future<void> _setupAmberSigner(String hexPubKey) async {
    final amberDs = AmberFlutterDS(Amberflutter());
    _signer = AmberEventSigner(
      publicKey: hexPubKey,
      amberFlutterDS: amberDs,
    );
    _hexPublicKey = hexPubKey;
    _npub = Nip19.encodePubKey(hexPubKey);
    _loginType = LoginType.amber;
    _hexPrivateKey = null;
    _nsec = null;
  }

  Future<bool> loginWithNip07() async {
    try {
      final nip07Signer = Nip07EventSigner();
      final pubKey = await nip07Signer.getPublicKeyAsync();

      String hexPubKey;
      if (pubKey.startsWith('npub')) {
        hexPubKey = Nip19.decode(pubKey);
      } else {
        hexPubKey = pubKey;
      }

      await _setupNip07Signer(hexPubKey);
      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nip07.name);
      await _storage.write(key: _nip07PubkeyStorageKey, value: hexPubKey);

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error logging in with NIP-07 extension: $e');
      return false;
    }
  }

  Future<void> _setupNip07Signer(String hexPubKey) async {
    _signer = Nip07EventSigner(cachedPublicKey: hexPubKey);
    _hexPublicKey = hexPubKey;
    _npub = Nip19.encodePubKey(hexPubKey);
    _loginType = LoginType.nip07;
    _hexPrivateKey = null;
    _nsec = null;
  }

  Future<bool> loginWithBunkerUrl(
    String bunkerUrl,
    NostrService nostrService, {
    Function(String)? authCallback,
  }) async {
    try {
      final connection = await nostrService.ndk.bunkers.connectWithBunkerUrl(
        bunkerUrl.trim(),
        authCallback: authCallback,
      );

      if (connection == null) {
        debugPrint('AuthService: Failed to connect to bunker.');
        return false;
      }

      await _setupBunkerSigner(connection, nostrService, authCallback: authCallback);
      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nip46.name);
      await _storage.write(
        key: _bunkerConnectionStorageKey,
        value: jsonEncode(connection.toJson()),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error connecting with Bunker URL: $e');
      return false;
    }
  }

  Future<bool> loginWithNostrConnect(
    NostrConnect nostrConnect,
    NostrService nostrService, {
    Function(String)? authCallback,
  }) async {
    try {
      final connection = await nostrService.ndk.bunkers.connectWithNostrConnect(
        nostrConnect,
        authCallback: authCallback,
      );

      if (connection == null) {
        debugPrint('AuthService: Failed to connect via Nostr Connect.');
        return false;
      }

      await _setupBunkerSigner(connection, nostrService, authCallback: authCallback);
      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nip46.name);
      await _storage.write(
        key: _bunkerConnectionStorageKey,
        value: jsonEncode(connection.toJson()),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error connecting with NostrConnect: $e');
      return false;
    }
  }

  Future<bool> loginWithNip46Connection(
    BunkerConnection connection,
    NostrService nostrService, {
    String? explicitUserPubkey,
    Function(String)? authCallback,
  }) async {
    try {
      await _setupBunkerSigner(
        connection,
        nostrService,
        explicitUserPubkey: explicitUserPubkey,
        authCallback: authCallback,
      );
      await _storage.write(key: _loginTypeStorageKey, value: LoginType.nip46.name);
      await _storage.write(
        key: _bunkerConnectionStorageKey,
        value: jsonEncode(connection.toJson()),
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('AuthService: Error connecting with BunkerConnection: $e');
      return false;
    }
  }

  Future<void> _setupBunkerSigner(
    BunkerConnection connection,
    NostrService nostrService, {
    String? explicitUserPubkey,
    Function(String)? authCallback,
  }) async {
    String? resolvedUserPubkey = explicitUserPubkey;

    if (resolvedUserPubkey == null || resolvedUserPubkey.isEmpty) {
      try {
        final fetched = await RideshareNip46Signer.fetchUserPublicKey(
          connection: connection,
          nostrService: nostrService,
        );
        if (fetched != null && fetched.isNotEmpty) {
          resolvedUserPubkey = fetched;
        }
      } catch (e) {
        debugPrint('AuthService: fetchUserPublicKey error: $e');
      }
    }

    resolvedUserPubkey ??= connection.remotePubkey;

    if (resolvedUserPubkey.startsWith('npub')) {
      resolvedUserPubkey = Nip19.decode(resolvedUserPubkey);
    }

    final signer = RideshareNip46Signer(
      connection: connection,
      userPublicKey: resolvedUserPubkey,
      nostrService: nostrService,
    );

    _signer = signer;
    _hexPublicKey = resolvedUserPubkey;
    _npub = Nip19.encodePubKey(resolvedUserPubkey);
    _loginType = LoginType.nip46;
    _hexPrivateKey = null;
    _nsec = null;

    await _storage.write(key: _bunkerUserPubkeyStorageKey, value: resolvedUserPubkey);
  }

  Future<void> clearKey() async {
    await _storage.delete(key: _loginTypeStorageKey);
    await _storage.delete(key: _nsecStorageKey);
    await _storage.delete(key: _bunkerConnectionStorageKey);
    await _storage.delete(key: _bunkerUserPubkeyStorageKey);
    await _storage.delete(key: _amberPubkeyStorageKey);
    await _storage.delete(key: _nip07PubkeyStorageKey);
    _clearInternalState(notify: true);
    debugPrint('AuthService: Stored NOSTR authentication cleared.');
  }

  void toggleNsecVisibility() {
    _showNsec = !_showNsec;
    notifyListeners();
  }

  void _clearInternalState({bool notify = true}) {
    _loginType = null;
    _signer = null;
    _nsec = null;
    _hexPrivateKey = null;
    _npub = null;
    _hexPublicKey = null;
    _showNsec = false;
    if (notify) {
      notifyListeners();
    }
  }
}