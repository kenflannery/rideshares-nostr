import 'dart:convert';
import 'package:amberflutter/amberflutter.dart';
import 'package:ndk/ndk.dart';

/// Amber (NIP-55) Android external intent signer implementation for NDK 0.9.0
class AmberEventSigner implements EventSigner {
  final String publicKey;
  final Amberflutter amber;

  AmberEventSigner({required this.publicKey, Amberflutter? amber})
      : amber = amber ?? Amberflutter();

  @override
  String getPublicKey() => publicKey;

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
    final eventMap = {
      'id': event.id,
      'pubkey': event.pubKey.isNotEmpty ? event.pubKey : publicKey,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'created_at': event.createdAt,
    };

    final res = await amber.signEvent(
      currentUser: publicKey,
      eventJson: jsonEncode(eventMap),
    );

    final sig = res['signature'] ?? '';
    final id = res['id'] ?? event.id;
    final eventStr = res['event'];
    if (eventStr != null && eventStr is String) {
      try {
        final decoded = jsonDecode(eventStr);
        return Nip01Event(
          id: decoded['id'] ?? id,
          pubKey: decoded['pubkey'] ?? publicKey,
          kind: decoded['kind'] ?? event.kind,
          tags: (decoded['tags'] as List<dynamic>?)
                  ?.map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
                  .toList() ??
              event.tags,
          content: decoded['content'] ?? event.content,
          createdAt: decoded['created_at'] ?? event.createdAt,
          sig: decoded['sig'] ?? sig,
        );
      } catch (_) {}
    }

    return event.copyWith(id: id, sig: sig);
  }

  @override
  Future<String?> decrypt(String msg, String destPubKey, {String? id}) async {
    final res = await amber.nip04Decrypt(
      currentUser: publicKey,
      pubKey: destPubKey,
      ciphertext: msg,
    );
    return res['signature'];
  }

  @override
  Future<String?> encrypt(String msg, String destPubKey, {String? id}) async {
    final res = await amber.nip04Encrypt(
      currentUser: publicKey,
      pubKey: destPubKey,
      plaintext: msg,
    );
    return res['signature'];
  }

  @override
  Future<String?> decryptNip44({required String ciphertext, required String senderPubKey}) async {
    final res = await amber.nip44Decrypt(
      currentUser: publicKey,
      pubKey: senderPubKey,
      ciphertext: ciphertext,
    );
    return res['signature'];
  }

  @override
  Future<String?> encryptNip44({required String plaintext, required String recipientPubKey}) async {
    final res = await amber.nip44Encrypt(
      currentUser: publicKey,
      pubKey: recipientPubKey,
      plaintext: plaintext,
    );
    return res['signature'];
  }

  @override
  Stream<List<PendingSignerRequest>> get pendingRequestsStream => const Stream.empty();

  @override
  List<PendingSignerRequest> get pendingRequests => [];

  @override
  bool cancelRequest(String requestId) => false;

  @override
  Future<void> dispose() async {}
}
