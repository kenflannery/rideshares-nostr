import 'package:ndk/entities.dart';

Future<bool> isNip07Available() async => false;

Future<String> getNip07PublicKey() async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<Nip01Event> signEventWithNip07(Nip01Event event) async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<String?> nip04EncryptWithNip07(String plaintext, String recipientPubKey) async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<String?> nip04DecryptWithNip07(String ciphertext, String senderPubKey) async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<String?> nip44EncryptWithNip07(String plaintext, String recipientPubKey) async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<String?> nip44DecryptWithNip07(String ciphertext, String senderPubKey) async =>
    throw UnsupportedError('NIP-07 is only available in web browsers.');

Future<bool> isNip44Supported() async => false;
