// screens/encryption/encryption_setup_screen
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/encryption/master_key_service.dart';
import '../../services/encryption/passphrase_kdf.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

// Pushed (not a shell tab) — a one-time setup flow, not somewhere to
// linger. Returns true via Navigator.pop if setup actually completed,
// false/null if the person backed out, so the caller (the encryption
// settings card) knows whether to re-check MasterKeyService.isUnlocked.
//
// Two steps, no going back once step 2 starts: the recovery codes are
// generated in step 1's result and can only ever be shown this once —
// MasterKeyService itself never stores them in recoverable form.
class EncryptionSetupScreen extends StatefulWidget {
  const EncryptionSetupScreen({super.key});

  @override 
  State<EncryptionSetupScreen> createState() => _EncryptionSetupScreenState();
}

enum _Step { passphrase, recoveryCodes }

class _EncryptionSetupScreenState extends State<EncryptionSetupScreen> {
  _Step _step = _Step.passphrase;

  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _working = false;

  List<RecoveryCode> _recoveryCodes = const [];
  bool _savedConfirmed = false;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _createPassphrase() async {
    final passphrase = _passphraseController.text;
    final confirm = _confirmController.text;

    if (passphrase.length < 8) {
      setState(() => _error = 'At least 8 characters');
      return;
    }
    if (passphrase != confirm) {
      setState(() => _error = "Those don't match");
      return;
    }

    setState(() {
      _working = true;
      _error = null;
    });

    final result = await MasterKeyService.instance.setUpNew(passphrase);
    if (!mounted) return;
    setState(() {
      _recoveryCodes = result.recoveryCodes;
      _step = _Step.recoveryCodes;
      _working = false;
    });

    // TODO(backend): upload result.wraps to Laravel's /encryption-keys
    // once that endpoint exists. Setup still fully succeeds locally
    // without it — offline-first — this device can already encrypt;
    // only other devices being able to unlock the same data depends on
    // the upload having happened at some point before they try.
  }

  void _finish() => Navigator.of(context).pop(true);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == _Step.passphrase ? 'Set up encryption' : 'Recovery codes',
        ),
        automaticallyImplyLeading: _step == _Step.passphrase,
      ),
      body: _step == _Step.passphrase
          ? _passphraseStep(context)
          : _recoveryCodesStep(context),
    );
  }

  Widget _passphraseStep(BuildContext context) {
    final colors = context.colors;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'This passphrase protects your tasks, contacts and spending. '
          "It's never sent anywhere — only you can unlock your data with "
          'it, and TaskFlow has no way to reset it if it\'s lost. The '
          'next step gives you one-time recovery codes as a backup.',
          style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _passphraseController,
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          decoration: const InputDecoration(hintText: 'Passphrase'),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _confirmController,
          obscureText: true,
          decoration: InputDecoration(
            hintText: 'Confirm passphrase',
            errorText: _error,
          ),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _working ? null : _createPassphrase(),
        ),
        const SizedBox(height: AppSpacing.lg),
        ElevatedButton(
          onPressed: _working ? null : _createPassphrase,
          child: _working
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _recoveryCodesStep(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Save these somewhere safe — a password manager, or '
                'written down. Each code works once, on its own, to get '
                'back in if you forget your passphrase. TaskFlow shows '
                'them only this one time.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final code in _recoveryCodes)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            code.text,
                            style: AppTypography.bodyMd.copyWith(
                              color: colors.textPrimary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(
                      text: _recoveryCodes.map((c) => c.text).join('\n'),
                    ),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Copied to clipboard')),
                  );
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
                label: const Text('Copy all'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _savedConfirmed,
                onChanged: (v) => setState(() => _savedConfirmed = v ?? false),
                title: Text(
                  "I've saved these recovery codes",
                  style: AppTypography.bodyMd.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _savedConfirmed ? _finish : null,
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
