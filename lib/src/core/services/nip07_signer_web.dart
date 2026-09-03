import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:ndk/entities.dart';

String _toDartString(JSAny? val) {
  if (val == null) return '';
  final dartified = val.dartify();
  if (dartified != null) {
    return dartified.toString().trim();
  }
  return '';
}

Future<bool> isNip07Available() async {
  try {
    final win = web.window as JSObject;
    return win.hasProperty('nostr'.toJS).toDart && win.getProperty('nostr'.toJS) != null;
  } catch (_) {
    return false;
  }
}

Future<String> getNip07PublicKey() async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) {
    throw StateError('No NIP-07 browser extension (e.g. Alby, nos2x) detected on window.nostr');
  }

  try {
    final promise = (nostr as JSObject).callMethod<JSPromise<JSAny?>>('getPublicKey'.toJS);
    final result = await promise.toDart;
    final pubkey = _toDartString(result);

    if (pubkey.isEmpty) {
      throw StateError('Browser extension returned empty public key');
    }
    return pubkey;
  } catch (e) {
    throw StateError('Extension authorization failed: $e');
  }
}

Future<Nip01Event> signEventWithNip07(Nip01Event event) async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) {
    throw StateError('No NIP-07 extension detected');
  }

  final eventMap = {
    'kind': event.kind,
    'content': event.content,
    'tags': event.tags,
    'created_at': event.createdAt,
    'pubkey': event.pubKey,
  };

  final jsEventObj = eventMap.jsify();
  final promise = (nostr as JSObject).callMethod<JSPromise<JSAny?>>('signEvent'.toJS, jsEventObj);
  final signedJsResult = await promise.toDart;
  final dartified = signedJsResult?.dartify();

  Map<String, dynamic> decoded;
  if (dartified is Map) {
    decoded = Map<String, dynamic>.from(dartified);
  } else if (dartified != null) {
    decoded = jsonDecode(dartified.toString()) as Map<String, dynamic>;
  } else {
    throw StateError('Extension returned null from signEvent');
  }

  return Nip01Event(
    id: decoded['id'] as String? ?? event.id,
    pubKey: decoded['pubkey'] as String? ?? event.pubKey,
    kind: decoded['kind'] as int? ?? event.kind,
    tags: (decoded['tags'] as List<dynamic>?)
            ?.map((t) => (t as List<dynamic>).map((e) => e.toString()).toList())
            .toList() ??
        event.tags,
    content: decoded['content'] as String? ?? event.content,
    createdAt: decoded['created_at'] as int? ?? event.createdAt,
    sig: decoded['sig'] as String? ?? event.sig,
  );
}

Future<String?> nip04EncryptWithNip07(String plaintext, String recipientPubKey) async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) return null;

  try {
    final nostrObj = nostr as JSObject;
    if (!nostrObj.hasProperty('nip04'.toJS).toDart) return null;
    final nip04 = nostrObj.getProperty('nip04'.toJS) as JSObject;
    final promise = nip04.callMethod<JSPromise<JSAny?>>('encrypt'.toJS, recipientPubKey.toJS, plaintext.toJS);
    final res = await promise.toDart;
    return _toDartString(res);
  } catch (_) {
    return null;
  }
}

Future<String?> nip04DecryptWithNip07(String ciphertext, String senderPubKey) async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) return null;

  try {
    final nostrObj = nostr as JSObject;
    if (!nostrObj.hasProperty('nip04'.toJS).toDart) return null;
    final nip04 = nostrObj.getProperty('nip04'.toJS) as JSObject;
    final promise = nip04.callMethod<JSPromise<JSAny?>>('decrypt'.toJS, senderPubKey.toJS, ciphertext.toJS);
    final res = await promise.toDart;
    return _toDartString(res);
  } catch (_) {
    return null;
  }
}

Future<String?> nip44EncryptWithNip07(String plaintext, String recipientPubKey) async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) return null;

  try {
    final nostrObj = nostr as JSObject;
    if (!nostrObj.hasProperty('nip44'.toJS).toDart) return null;
    final nip44 = nostrObj.getProperty('nip44'.toJS) as JSObject;
    final promise = nip44.callMethod<JSPromise<JSAny?>>('encrypt'.toJS, recipientPubKey.toJS, plaintext.toJS);
    final res = await promise.toDart;
    return _toDartString(res);
  } catch (_) {
    return null;
  }
}

Future<String?> nip44DecryptWithNip07(String ciphertext, String senderPubKey) async {
  final win = web.window as JSObject;
  final nostr = win.getProperty('nostr'.toJS);
  if (nostr == null) return null;

  try {
    final nostrObj = nostr as JSObject;
    if (!nostrObj.hasProperty('nip44'.toJS).toDart) return null;
    final nip44 = nostrObj.getProperty('nip44'.toJS) as JSObject;
    final promise = nip44.callMethod<JSPromise<JSAny?>>('decrypt'.toJS, senderPubKey.toJS, ciphertext.toJS);
    final res = await promise.toDart;
    return _toDartString(res);
  } catch (_) {
    return null;
  }
}

Future<bool> isNip44Supported() async {
  try {
    final win = web.window as JSObject;
    if (!win.hasProperty('nostr'.toJS).toDart) return false;
    final nostr = win.getProperty('nostr'.toJS);
    if (nostr == null) return false;
    final nostrObj = nostr as JSObject;
    return nostrObj.hasProperty('nip44'.toJS).toDart &&
        nostrObj.getProperty('nip44'.toJS) != null;
  } catch (_) {
    return false;
  }
}
