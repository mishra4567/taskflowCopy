// screens/morescreen/encryption_settings_card.dart
import 'package:flutter/material.dart';
import '../../services/encryption/feature_key_service.dart';
import '../../services/encryption/master_key_service.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/slide_page_route.dart';
import '../encryption/encryption_setup_screen.dart';

// Settings card for the four per-feature encryption switches. Before
// setup has ever run (no master key), shows a single "Set up
// encryption" prompt instead of switches — there's nothing to toggle
// until a passphrase exists to protect the keys. Mirrors
// AlarmSoundCard/BackupCard's layout.
// 
// Each switch flips FeatureKeyService's on/off state. Migrating
// existing rows to/from encrypted is NOT done here — each feature's own
// repository owns that (re-saving every row through the now-enabled or
// now-disabled path); this card only confirms the person means it and
// flips the switch, then expects the caller to have wired that
// migration behind the same toggle. Not wired yet for any feature.
class EncryptionSettingsCard extends StatefulWidget {
  const EncryptionSettingsCard({super.key});

  @override
  State<EncryptionSettingsCard> createState() => _EncryptionSettingsCardState();
}

class _EncryptionSettingsCardState extends State<EncryptionSettingsCard> {
  bool get _unlocked => MasterKeyService.instance.isUnlocked;

  EncryptedFeature? _busyFeature;

  Future<void> _openSetup() async {
    final completed = await Navigator.of(
      context,
    ).push<bool>(slidePageRoute((_) => const EncryptionSetupScreen()));
    if (completed == true && mounted) setState(() {});
  }

  Future<void> _toggle(EncryptedFeature feature, bool turningOn) async {
    final label = _label(feature);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          turningOn ? 'Encrypt $label?' : 'Turn off $label encryption?',
        ),
        content: Text(
          turningOn
              ? 'Existing $label entries will be encrypted on this device. '
                    "If you forget your passphrase and your recovery codes "
                    "are lost, this data can't be recovered."
              : 'Existing $label entries will be decrypted back to plain '
                    'storage on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(turningOn ? 'Encrypt' : 'Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyFeature = feature);
    try {
      if (turningOn) {
        await FeatureKeyService.instance.enable(feature);
      } else {
        await FeatureKeyService.instance.disable(feature);
      }
      // TODO(migration): once each feature's repository supports it,
      // trigger the re-save-every-row pass here — e.g.
      // await TodoRepository.instance.migrateEncryption(turningOn).
    } finally {
      if (mounted) setState(() => _busyFeature = null);
    }
  }

  String _label(EncryptedFeature feature) => switch (feature) {
    EncryptedFeature.todo => 'TODO',
    EncryptedFeature.contacts => 'Contacts',
    EncryptedFeature.expenses => 'Expenses',
    EncryptedFeature.roadmap => 'Roadmap',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 20,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    'Encryption',
                    style: AppTypography.bodyMd.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!_unlocked)
              _SetupPrompt(onTap: _openSetup)
            else ...[
              _FeatureRow(
                label: 'TODO',
                feature: EncryptedFeature.todo,
                busy: _busyFeature == EncryptedFeature.todo,
                onChanged: (v) => _toggle(EncryptedFeature.todo, v),
              ),
              _FeatureRow(
                label: 'Contacts',
                feature: EncryptedFeature.contacts,
                busy: _busyFeature == EncryptedFeature.contacts,
                onChanged: (v) => _toggle(EncryptedFeature.contacts, v),
              ),
              _FeatureRow(
                label: 'Expenses',
                feature: EncryptedFeature.expenses,
                busy: _busyFeature == EncryptedFeature.expenses,
                onChanged: (v) => _toggle(EncryptedFeature.expenses, v),
              ),
              _FeatureRow(
                label: 'Roadmap',
                feature: EncryptedFeature.roadmap,
                busy: _busyFeature == EncryptedFeature.roadmap,
                // Roadmap has no real backing table yet, so there's
                // nothing to actually encrypt — disabled, not hidden, so
                // the setting is visibly "coming" rather than missing.
                onChanged: null,
                disabledReason: 'Available once Roadmap has real data',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetupPrompt extends StatelessWidget {
  const _SetupPrompt({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.standard),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Set up a passphrase to enable encryption',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
            Icon(Icons.chevron_right, size: 18, color: colors.outline),
          ],
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.label,
    required this.feature,
    required this.busy,
    required this.onChanged,
    this.disabledReason,
  });

  final String label;
  final EncryptedFeature feature;
  final bool busy;
  final ValueChanged<bool>? onChanged;
  final String? disabledReason;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final enabled = FeatureKeyService.instance.isEnabled(feature);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.bodyMd.copyWith(
                    color: onChanged == null
                        ? colors.textSecondary
                        : colors.textPrimary,
                  ),
                ),
                if (disabledReason != null)
                  Text(
                    disabledReason!,
                    style: AppTypography.bodySm.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Switch(
                  value: enabled,
                  onChanged: busy ? null : onChanged,
                  activeThumbColor: colors.primary,
                ),
        ],
      ),
    );
  }
}
