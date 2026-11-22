// test/pairing_crypto_test.dart
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:taskflow/services/encryption/aes_box.dart';
import 'package:taskflow/services/encryption/pairing_crypto.dart';

void main() {
  test('master key survives a pairing round trip', () async {
    final master = await AesBox.generateKey();
    final b = await PairingCrypto.newKeyPair();
    const session = 'session-123';

    final qr = PairingQr(sessionId: session, publicKey: b.publicKey);
    final scanned = PairingQr.parse(qr.encode())!;

    final approval = await PairingCrypto.encryptMasterKeyFor(
      newDevicePublicKey: scanned.publicKey,
      sessionId: scanned.sessionId,
      masterKey: master,
    );
    final received = await PairingCrypto.decryptMasterKey(
      myKeyPair: b,
      approverPublicKey: approval.approverPublicKey,
      encryptedMasterKey: approval.encryptedMasterKey,
      sessionId: session,
    );

    expect(await received.extractBytes(), await master.extractBytes());
  });

  test('a different session id is rejected', () async {
    final master = await AesBox.generateKey();
    final b = await PairingCrypto.newKeyPair();
    final approval = await PairingCrypto.encryptMasterKeyFor(
      newDevicePublicKey: b.publicKey,
      sessionId: 'one',
      masterKey: master,
    );
    expect(
      () => PairingCrypto.decryptMasterKey(
        myKeyPair: b,
        approverPublicKey: approval.approverPublicKey,
        encryptedMasterKey: approval.encryptedMasterKey,
        sessionId: 'two',
      ),
      throwsA(isA<DecryptionFailedException>()),
    );
  });
}
