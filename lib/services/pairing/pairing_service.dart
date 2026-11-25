// services/pairing/pairing_service
import 'package:cryptography/cryptography.dart';

import '../../config/device_info.dart';
import '../api/api_client.dart';
import '../api/device_session.dart';
import '../encryption/aes_box.dart';
import '../encryption/master_key_service.dart';
import '../encryption/pairing_crypto.dart';
import 'pairing_api.dart';

class PairingException implements Exception {
  const PairingException(this.message);
  final String message;
  @override
  String toString() => message;
}

// One run of "show a code on this new phone": the throwaway key pair and
// the server session. Lives only while the QR screen is open.
class PairingAttempt {
  const PairingAttempt({
    required this.sessionId,
    required this.pollSecret,
    required this.keyPair,
    required this.expiresAt,
  });

  final String sessionId;
  final String pollSecret;
  final PairingKeyPair keyPair;
  final DateTime expiresAt;

  // What the QR carries: public information only.
  String get qrText =>
      PairingQr(sessionId: sessionId, publicKey: keyPair.publicKey).encode();
}

// A network blip while polling shouldn't end pairing — only a real answer
// from the server (expired, rejected) should.
bool isTransientPairingError(Object error) =>
    error is ApiException && error.isNetwork;

// A message safe to show the person for anything pairing can throw.
String describePairingError(Object error) {
  if (error is PairingException) return error.message;
  if (error is ApiException) {
    switch (error.code) {
      case 'device_limit_reached':
        final limit = error.data['limit'];
        return limit == null
            ? "You've reached your device limit."
            : "You've linked $limit of $limit devices. Remove one, or "
                  'wait for Premium, which links more.';
      case 'not_signed_in':
        return 'Sign in on this phone first.';
    }
    if (error.statusCode == 404 || error.statusCode == 410) {
      return 'That code has expired. Show a new one on the other phone.';
    }
    if (error.statusCode == 429) {
      return 'Too many tries. Wait a minute and try again.';
    }
    return error.message ?? 'Something went wrong. Try again.';
  }
  if (error is DecryptionFailedException) {
    return "Couldn't verify the other phone. Start again.";
  }
  return 'Something went wrong. Try again.';
}

class PairingService {
  PairingService._();
  static final PairingService instance = PairingService._();

  final PairingApi _api = PairingApi.instance;

  // ------------------------------------------- the NEW phone (shows a QR)

  // Makes this phone's throwaway key pair, opens a session on the server
  // and returns what the QR screen needs.
  //
  // [deviceName] is what the person typed on the "Link this phone" screen
  // ("Amma's phone"); left empty, the name comes from the device itself
  // (manufacturer + model, via DeviceInfoConfig). The platform is always
  // read from the device and never passed in, so it can't disagree with
  // what DeviceInfoConfig reports everywhere else.
  Future<PairingAttempt> startAsNewDevice({String? deviceName}) async {
    if (await DeviceSession.instance.isSignedIn) {
      throw const PairingException(
        'This phone is already linked to an account.',
      );
    }
    // Adopting the account's master key would replace this phone's own, and
    // anything already encrypted under the old one would be unreadable.
    if (MasterKeyService.instance.isUnlocked) {
      throw const PairingException(
        'This phone already has its own encryption set up, and linking '
        'would lock you out of that data. A phone you link should be '
        "fresh — clear TaskFlow's data (or reinstall) first.",
      );
    }

    final device = await DeviceInfoConfig.getDeviceInfo();
    final typedName = deviceName?.trim() ?? '';

    final keyPair = await PairingCrypto.newKeyPair();
    final session = await _api.createSession(
      deviceName: typedName.isEmpty ? device.deviceName : typedName,
      platform: device.platform,
      publicKey: keyPair.publicKey,
    );
    return PairingAttempt(
      sessionId: session.sessionId,
      pollSecret: session.pollSecret,
      keyPair: keyPair,
      expiresAt: session.expiresAt,
    );
  }

  // Asks the server whether the other phone approved. Returns true once
  // this phone has taken over the account (master key adopted if there is
  // one, device token stored), false while still waiting. Throws on
  // anything final: expired session, failed decryption.
  Future<bool> checkForApproval(PairingAttempt attempt) async {
    final result = await _api.poll(attempt.sessionId, attempt.pollSecret);
    if (result == null) return false;

    final encrypted = result.encryptedMasterKey;
    final approverKey = result.approverPublicKey;
    if (encrypted != null) {
      if (approverKey == null) {
        throw const PairingException(
          'The other phone sent an incomplete answer. Start again.',
        );
      }
      final SecretKey masterKey = await PairingCrypto.decryptMasterKey(
        myKeyPair: attempt.keyPair,
        approverPublicKey: approverKey,
        encryptedMasterKey: encrypted,
        sessionId: attempt.sessionId,
      );
      await MasterKeyService.instance.adoptPairedKey(masterKey);
    }

    // Last on purpose: a phone that failed to get the key must not end up
    // half-linked with a token.
    await DeviceSession.instance.save(
      token: result.deviceToken,
      deviceId: result.deviceId,
    );
    // TODO(sync): download the wrapped feature keys and their on/off flags
    // (FeatureKeyService) BEFORE downloading any data, or encrypted rows
    // arrive with no key to read them.
    return true;
  }

  // ------------------------------- the LINKED phone (scans the QR, approves)

  Future<PairingLookup> lookup(PairingQr qr) => _api.lookup(qr.sessionId);

  // Sends the new phone's approval. If this phone has encryption set up,
  // the master key goes along, encrypted so only the new phone can open
  // it. The new phone's public key comes from the scanned QR, never from
  // the server.
  Future<void> approve(PairingQr qr) async {
    if (!MasterKeyService.instance.isUnlocked) {
      await _api.approve(qr.sessionId);
      return;
    }
    final payload = await PairingCrypto.encryptMasterKeyFor(
      newDevicePublicKey: qr.publicKey,
      sessionId: qr.sessionId,
      masterKey: MasterKeyService.instance.currentKey,
    );
    await _api.approve(
      qr.sessionId,
      approverPublicKey: payload.approverPublicKey,
      encryptedMasterKey: payload.encryptedMasterKey,
    );
  }
}
