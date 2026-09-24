/// ./screens/testing/TestingExtensionScreen.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';

const _contactsExtensionType = 'contacts';

/// The rule you get is: prefer the second name, fall back to the first
/// name if it's blank. Neither is guaranteed non-empty (both fields are
/// optional in the add-contact dialog), so this can still return ''.
String contactDisplayName(Map<String, dynamic> payload) {
  final secondName = (payload['secondName'] as String? ?? '').trim();
  final firstName = (payload['firstName'] as String? ?? '').trim();
  return secondName.isNotEmpty ? secondName : firstName;
}

/// Shared "add a contact" form — used by both this screen's own + button
/// and the Quick Add sheet's "Add Contact" card, so there's one place
/// that owns the fields and the save path instead of two copies
/// drifting apart. Styled as a bottom sheet (rounded top, drag handle,
/// title) to match Quick Add's own sheet rather than a plain dialog.
Future<void> showAddContactDialog(
  BuildContext context, {
  VoidCallback? onSaved,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _AddContactSheet(onSaved: onSaved),
  );
}

class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet({this.onSaved});
  final VoidCallback? onSaved;

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _numberController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();

  @override
  void dispose() {
    _numberController.dispose();
    _firstNameController.dispose();
    _secondNameController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(
    AppPalette colors, {
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: colors.onSurfaceVariant),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
    );
  }

  Future<void> _save() async {
    final payload = {
      'number': _numberController.text.trim(),
      'firstName': _firstNameController.text.trim(),
      'secondName': _secondNameController.text.trim(),
    };
    // Skip saving a contact with nothing usable to show or call.
    if (contactDisplayName(payload).isEmpty && payload['number']!.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    await AppDatabase.instance.addExtensionRecord(
      _contactsExtensionType,
      jsonEncode(payload),
    );
    widget.onSaved?.call();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.container),
          ),
          border: Border.all(color: colors.borderSubtle),
        ),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: colors.borderSubtle,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.standard),
                  ),
                  child: Icon(
                    Icons.person_add_alt,
                    color: colors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Add contact',
                  style: AppTypography.bodyLg.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _firstNameController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                colors,
                label: 'First name',
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _secondNameController,
              textCapitalization: TextCapitalization.words,
              decoration: _fieldDecoration(
                colors,
                label: 'Second name',
                icon: Icons.badge_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              decoration: _fieldDecoration(
                colors,
                label: 'Number',
                icon: Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.standard),
                  ),
                ),
                child: const Text('Save contact'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contacts extension — for debugging/testing the card + navigation +
/// real data flow before this becomes a real installed extension.
/// Persisted via AppDatabase's generic ExtensionRecords table under
/// extensionType 'contacts', the same store a real installed Contacts
/// extension with recordFields: ['number', 'firstName', 'secondName']
/// would use — so this testing screen and the eventual real extension
/// share the exact same data, not two separate stores.
///
/// Lives inside MainShell (like TodoScreen) rather than being pushed
/// over it, so the bottom nav stays visible — hence `onBack` instead of
/// relying on Navigator.pop, and its own leading arrow since the shell
/// hides its AppBar for this page.
class TestingExtensionScreen extends StatefulWidget {
  const TestingExtensionScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<TestingExtensionScreen> createState() =>
      _TestingExtensionScreenState();
}

class _TestingExtensionScreenState extends State<TestingExtensionScreen> {
  List<ExtensionRecord> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await AppDatabase.instance.getExtensionRecords(
      _contactsExtensionType,
    );
    if (!mounted) return;
    setState(() {
      _contacts = rows;
      _loading = false;
    });
  }

  Future<void> _deleteContact(int id) async {
    await AppDatabase.instance.deleteExtensionRecord(id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
        title: const Text('Contacts Extension'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showAddContactDialog(context, onSaved: _refresh),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? Center(
              child: Text(
                'No contacts yet — tap + to add one.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.md,
                AppSpacing.containerMargin,
                100,
              ),
              itemCount: _contacts.length,
              itemBuilder: (context, index) {
                final record = _contacts[index];
                final payload =
                    jsonDecode(record.payload) as Map<String, dynamic>;
                final name = contactDisplayName(payload);
                final number = (payload['number'] as String? ?? '').trim();

                return Card(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colors.surfaceContainerHigh,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : '?',
                        style: TextStyle(color: colors.onSurfaceVariant),
                      ),
                    ),
                    title: Text(name.isEmpty ? '(no name)' : name),
                    subtitle: number.isEmpty ? null : Text(number),
                    trailing: IconButton(
                      icon: Icon(Icons.delete_outline, color: colors.error),
                      onPressed: () => _deleteContact(record.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
