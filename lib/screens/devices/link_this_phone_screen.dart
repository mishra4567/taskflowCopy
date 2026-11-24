// screens/devices/link_this_phone_screen
import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/pairing/pairing_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

// Shown on the phone that is being linked: name it, then show a QR for an
// already-linked phone to scan. Pops with true once linked.
class LinkThisPhoneScreen extends StatefulWidget {
  const LinkThisPhoneScreen({super.key});

  @override
  State<LinkThisPhoneScreen> createState() => _LinkThisPhoneScreenState();
}

class _LinkThisPhoneScreenState extends State<LinkThisPhoneScreen> {
  static const _pollEvery = Duration(seconds: 2);

  final _nameController = TextEditingController(
    text: Platform.isIOS ? 'iPhone' : 'Android phone',
  );
  PairingAttempt? _attempt;
  Timer? _timer;
  bool _starting = false;
  bool _checking = false;
  bool _linked = false;
  String? _error;
  Duration _remaining = Duration.zero;

  @override
  void dispose() {
    _timer?.cancel();
    _nameController.dispose();
    super.dispose();
  }

  String get _platform => Platform.isIOS ? 'ios' : 'android';

  Future<void> _start() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give this phone a name');
      return;
    }
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final attempt = await PairingService.instance.startAsNewDevice(
        deviceName: name,
        platform: _platform,
      );
      if (!mounted) return;
      setState(() {
        _attempt = attempt;
        _starting = false;
        _remaining = attempt.expiresAt.difference(DateTime.now());
      });
      _timer?.cancel();
      _timer = Timer.periodic(_pollEvery, (_) => _tick());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _starting = false;
        _error = describePairingError(e);
      });
    }
  }

  Future<void> _tick() async {
    final attempt = _attempt;
    if (attempt == null || _checking || _linked) return;

    final remaining = attempt.expiresAt.difference(DateTime.now());
    if (remaining <= Duration.zero) {
      _timer?.cancel();
      setState(() {
        _attempt = null;
        _error = 'That code expired. Show a new one.';
      });
      return;
    }
    setState(() => _remaining = remaining);

    _checking = true;
    try {
      final linked = await PairingService.instance.checkForApproval(attempt);
      if (!mounted) return;
      if (linked) {
        _timer?.cancel();
        setState(() => _linked = true);
      }
    } catch (e) {
      if (isTransientPairingError(e)) return; // keep trying
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _attempt = null;
        _error = describePairingError(e);
      });
    } finally {
      _checking = false;
    }
  }

  String _formatRemaining(Duration d) {
    final seconds = d.inSeconds < 0 ? 0 : d.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Link this phone')),
      body: _linked
          ? _doneView(context)
          : _attempt == null
          ? _nameView(context)
          : _qrView(context, _attempt!),
    );
  }

  Widget _nameView(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Link this phone to your TaskFlow account. You\'ll show a code '
          "here and scan it with a phone that's already linked.",
          style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            hintText: 'Name this phone',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _starting ? null : _start(),
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _starting ? null : _start,
          child: _starting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Show code'),
        ),
      ],
    );
  }

  Widget _qrView(BuildContext context, PairingAttempt attempt) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'On the other phone, open Settings → Devices → Link another '
          'phone, and scan this code.',
          style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        Center(
          // White on purpose: scanners need dark-on-light, and the app's
          // black theme would make the code unreadable.
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.container),
            ),
            child: QrImageView(
              data: attempt.qrText,
              size: 240,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Text(
            'Expires in ${_formatRemaining(_remaining)}',
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _doneView(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 56, color: colors.tertiary),
          const SizedBox(height: AppSpacing.md),
          Text(
            'This phone is linked',
            style: AppTypography.bodyLg.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your data will appear here as it syncs.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
