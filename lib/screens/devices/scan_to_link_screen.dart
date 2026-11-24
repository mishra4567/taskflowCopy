// screens/devices/scan_to_link_screen
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../services/encryption/master_key_service.dart';
import '../../services/encryption/pairing_crypto.dart';
import '../../services/pairing/pairing_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

// Shown on a phone that's already linked: scan the new phone's QR, check
// the name matches the phone in your hand, approve. Pops with true once
// approved.
class ScanToLinkScreen extends StatefulWidget {
  const ScanToLinkScreen({super.key});

  @override
  State<ScanToLinkScreen> createState() => _ScanToLinkScreenState();
}

class _ScanToLinkScreenState extends State<ScanToLinkScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _busy = false;

  // A wrong QR in view fires detections many times a second — only
  // complain about each distinct one once.
  String? _lastRejected;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;

    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;

    final qr = PairingQr.parse(raw);
    if (qr == null) {
      if (raw != _lastRejected) {
        _lastRejected = raw;
        setState(() => _message = "That isn't a TaskFlow code.");
      }
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final info = await PairingService.instance.lookup(qr);
      if (!mounted) return;
      final confirmed = await _confirm(info.deviceName);
      if (confirmed != true || !mounted) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      await PairingService.instance.approve(qr);
      if (!mounted) return;
      await _showLinked(info.deviceName);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _message = describePairingError(e);
      });
    }
  }

  Future<bool?> _confirm(String deviceName) {
    final withKey = MasterKeyService.instance.isUnlocked;
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Link "$deviceName"?'),
        content: Text(
          'Only continue if you are holding that phone right now. It will '
          'get your tasks, contacts and spending'
          '${withKey ? ', and your encryption key' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Link phone'),
          ),
        ],
      ),
    );
  }

  Future<void> _showLinked(String deviceName) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone linked'),
        content: Text('"$deviceName" is now linked to your account.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Link another phone')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                if (_busy) const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              _message ??
                  'On the new phone, choose Link this phone and point this '
                      'camera at the code.',
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: _message != null ? colors.error : colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
