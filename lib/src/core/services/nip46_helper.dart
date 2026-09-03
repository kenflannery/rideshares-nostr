import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:ndk/ndk.dart';
import 'package:ndk/shared/nips/nip01/bip340.dart';
import 'package:ndk/shared/nips/nip01/helpers.dart';
import 'package:ndk/shared/nips/nip01/key_pair.dart';
import 'package:rxdart/rxdart.dart';

import 'nostr_service.dart';

/// Robust NIP-46 Remote Bunker Signer with current timestamps and real user pubkey resolution.
class RideshareNip46Signer implements EventSigner {
  final BunkerConnection connection;
  final String _userPublicKey;
  final NostrService nostrService;

  late Bip340EventSigner localEventSigner;
  NdkResponse? _subscription;

  final _pendingRequests = <String, Completer<String>>{};
  final _pendingRequestsController = BehaviorSubject<List<PendingSignerRequest>>.seeded([]);

  RideshareNip46Signer({
    required this.connection,
    required String userPublicKey,
    required this.nostrService,
  }) : _userPublicKey = userPublicKey.startsWith('npub')
            ? Nip19.decode(userPublicKey)
            : userPublicKey {
    final privKey = connection.privateKey;
    final pubKey = Bip340.getPublicKey(privKey);
    final privKeyHr = Helpers.encodeBech32(privKey, 'nsec');
    final pubKeyHr = Helpers.encodeBech32(pubKey, 'npub');

    final keyPair = KeyPair(privKey, pubKey, privKeyHr, pubKeyHr);
    localEventSigner = Bip340EventSigner(
      privateKey: keyPair.privateKey,
      publicKey: keyPair.publicKey,
    );

    _listenRelays();
  }

  void _listenRelays() {
    try {
      _subscription = nostrService.ndk.requests.subscription(
        explicitRelays: connection.relays,
        filter: Filter(
          authors: [connection.remotePubkey],
          kinds: [24133],
          pTags: [localEventSigner.publicKey],
          since: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 120,
        ),
      );

      _subscription!.stream.listen(_onEvent);
    } catch (e) {
      debugPrint("RideshareNip46Signer: Error starting subscription: $e");
    }
  }

  Future<void> _onEvent(Nip01Event event) async {
    try {
      final decrypted = await localEventSigner.decryptNip44(
        ciphertext: event.content,
        senderPubKey: event.pubKey,
      );

      if (decrypted == null) return;
      final response = jsonDecode(decrypted);
      final reqId = response["id"]?.toString();

      if (reqId != null && _pendingRequests.containsKey(reqId)) {
        final completer = _pendingRequests.remove(reqId)!;
        if (response["error"] != null && response["error"].toString().isNotEmpty) {
          completer.completeError(Exception(response["error"]));
        } else {
          completer.complete(response["result"]?.toString() ?? "");
        }
      }
    } catch (e) {
      debugPrint("RideshareNip46Signer: Error processing response event: $e");
    }
  }

  Future<String> remoteRequest(String method, List<dynamic> params) async {
    final reqId = Helpers.getRandomString(16);
    final completer = Completer<String>();
    _pendingRequests[reqId] = completer;

    final requestBody = jsonEncode({
      "id": reqId,
      "method": method,
      "params": params,
    });

    final encrypted = await localEventSigner.encryptNip44(
      plaintext: requestBody,
      recipientPubKey: connection.remotePubkey,
    );

    if (encrypted == null) {
      _pendingRequests.remove(reqId);
      throw Exception("Failed to encrypt NIP-46 request with NIP-44");
    }

    final requestEvent = Nip01Event(
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      pubKey: localEventSigner.publicKey,
      kind: 24133,
      tags: [
        ["p", connection.remotePubkey],
      ],
      content: encrypted,
    );

    final signedEvent = await localEventSigner.sign(requestEvent);

    final broadcastRes = nostrService.ndk.broadcast.broadcast(
      nostrEvent: signedEvent,
      specificRelays: connection.relays,
    );
    await broadcastRes.broadcastDoneFuture;

    return completer.future.timeout(
      const Duration(seconds: 20),
      onTimeout: () {
        _pendingRequests.remove(reqId);
        throw TimeoutException("NIP-46 remote request '$method' timed out.");
      },
    );
  }

  /// Queries the remote bunker for the real user public key.
  static Future<String?> fetchUserPublicKey({
    required BunkerConnection connection,
    required NostrService nostrService,
  }) async {
    final privKey = connection.privateKey;
    final pubKey = Bip340.getPublicKey(privKey);
    final localSigner = Bip340EventSigner(
      privateKey: privKey,
      publicKey: pubKey,
    );

    final reqId = Helpers.getRandomString(16);
    final completer = Completer<String>();

    final sub = nostrService.ndk.requests.subscription(
      explicitRelays: connection.relays,
      filter: Filter(
        authors: [connection.remotePubkey],
        kinds: [24133],
        pTags: [pubKey],
        since: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - 30,
      ),
    );

    final subListener = sub.stream.listen((event) async {
      try {
        final decrypted = await localSigner.decryptNip44(
          ciphertext: event.content,
          senderPubKey: event.pubKey,
        );
        if (decrypted == null) return;
        final response = jsonDecode(decrypted);
        if (response["id"]?.toString() == reqId) {
          final result = response["result"]?.toString();
          if (result != null && result.isNotEmpty) {
            completer.complete(result);
          }
        }
      } catch (_) {}
    });

    try {
      final requestBody = jsonEncode({
        "id": reqId,
        "method": "get_public_key",
        "params": [],
      });

      final encrypted = await localSigner.encryptNip44(
        plaintext: requestBody,
        recipientPubKey: connection.remotePubkey,
      );

      if (encrypted != null) {
        final reqEvent = Nip01Event(
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          pubKey: pubKey,
          kind: 24133,
          tags: [
            ["p", connection.remotePubkey],
          ],
          content: encrypted,
        );

        final signed = await localSigner.sign(reqEvent);
        final broadcastRes = nostrService.ndk.broadcast.broadcast(
          nostrEvent: signed,
          specificRelays: connection.relays,
        );
        await broadcastRes.broadcastDoneFuture;

        final fetched = await completer.future.timeout(const Duration(seconds: 5));
        return fetched;
      }
    } catch (e) {
      debugPrint("RideshareNip46Signer: get_public_key query error: $e");
    } finally {
      await subListener.cancel();
      try {
        await nostrService.ndk.requests.closeSubscription(sub.requestId);
      } catch (_) {}
    }
    return null;
  }

  @override
  String getPublicKey() => _userPublicKey;

  @override
  bool canSign() => true;

  @override
  Future<Nip01Event> sign(Nip01Event event) async {
    final eventMap = {
      "kind": event.kind,
      "content": event.content,
      "tags": event.tags,
      "created_at": event.createdAt,
    };

    final signedEventJson = await remoteRequest("sign_event", [jsonEncode(eventMap)]);
    final signedEvent = jsonDecode(signedEventJson);

    return event.copyWith(
      id: signedEvent["id"],
      sig: signedEvent["sig"],
      pubKey: _userPublicKey,
    );
  }

  @override
  Future<String?> encrypt(String msg, String destPubKey, {String? id}) async {
    final res = await remoteRequest("nip04_encrypt", [destPubKey, msg]);
    return res;
  }

  @override
  Future<String?> decrypt(String msg, String destPubKey, {String? id}) async {
    final res = await remoteRequest("nip04_decrypt", [destPubKey, msg]);
    return res;
  }

  @override
  Future<String?> encryptNip44({required String plaintext, required String recipientPubKey}) async {
    final res = await remoteRequest("nip44_encrypt", [recipientPubKey, plaintext]);
    return res;
  }

  @override
  Future<String?> decryptNip44({required String ciphertext, required String senderPubKey}) async {
    final res = await remoteRequest("nip44_decrypt", [senderPubKey, ciphertext]);
    return res;
  }

  @override
  Stream<List<PendingSignerRequest>> get pendingRequestsStream => _pendingRequestsController.stream;

  @override
  List<PendingSignerRequest> get pendingRequests => [];

  @override
  bool cancelRequest(String requestId) {
    final completer = _pendingRequests.remove(requestId);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception("Request cancelled"));
      return true;
    }
    return false;
  }

  @override
  Future<void> dispose() async {
    if (_subscription != null) {
      try {
        await nostrService.ndk.requests.closeSubscription(_subscription!.requestId);
      } catch (_) {}
    }
    await _pendingRequestsController.close();
  }
}
