import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';

import 'nip07_signer_stub.dart'
    if (dart.library.js_interop) 'nip07_signer_web.dart' as impl;

/// Event signer interfacing with NIP-07 browser extensions (Alby, nos2x, Blockcore, etc.)
class Nip07Signer implements EventSigner {
  final String _publicKey;

  Nip07Signer._(this._publicKey);

  static Future<bool> isAvailable() async {
    if (!kIsWeb) return false;
    return impl.isNip07Available();
  }

  static Future<bool> isNip44Supported() async {
    if (!kIsWeb) return false;
    return impl.isNip44Supported();
  }

  static Future<Nip07Signer> connect() async {
    if (!kIsWeb) {
      throw UnsupportedError('NIP-07 browser extensions are only supported in web environments.');
    }
    final pubKey = await impl.getNip07PublicKey();
    if (pubKey.isEmpty) {
      throw StateError('Failed to retrieve public key from NIP-07 extension.');
    }
    return Nip07Signer._(pubKey);
  }

  factory Nip07Signer.fromCachedPublicKey(String publicKey) {
    return Nip07Signer._(publicKey);
  }

  @override
  String getPublicKey() => _publicKey;

  @override
  bool canSign() => true;

  @override
  bool get requiresInteractiveSigning => true;

  @override
  bool get requiresSignerNetwork => false;

  @override
  Iterable<String> get signerTransportRelayUrls => const <String>[];

  @override
  Future<Nip01Event> sign(Nip01Event event) async {
    if (!kIsWeb) {
      throw UnsupportedError('NIP-07 signing only supported on web.');
    }
    return impl.signEventWithNip07(event);
  }

  @override
  Future<String?> encrypt(String plaintext, String recipientPubKey) async {
    if (!kIsWeb) return null;
    return impl.nip04EncryptWithNip07(plaintext, recipientPubKey);
  }

  @override
  Future<String?> decrypt(String cipherText, String id) async {
    if (!kIsWeb) return null;
    return impl.nip04DecryptWithNip07(cipherText, id);
  }

  @override
  Future<String?> encryptNip44({required String plaintext, required String recipientPubKey}) async {
    if (!kIsWeb) return null;
    return impl.nip44EncryptWithNip07(plaintext, recipientPubKey);
  }

  @override
  Future<String?> decryptNip44({required String ciphertext, required String senderPubKey}) async {
    if (!kIsWeb) return null;
    return impl.nip44DecryptWithNip07(ciphertext, senderPubKey);
  }

  @override
  bool cancelRequest(String requestId) => true;

  @override
  Future<void> dispose() async {}

  @override
  get pendingRequests => [];

  @override
  get pendingRequestsStream => const Stream.empty();
}
