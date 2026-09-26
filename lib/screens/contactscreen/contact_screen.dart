/// screens/contactscreen/contact_screen.dart
///
/// Merges the previous testing_extension_screen.dart (the real Contacts
/// CRUD screen) with abcd.dart (a placeholder screen + the quick-add
/// registration). abcd.dart's placeholder TestingExtensionScreen is gone
/// — this is the real one — but its registerQuickAddContact() lives on
/// here, now sharing the same add-contact dialog as the screen's own FAB
/// instead of duplicating it. Delete screens/testing/abcd.dart once this
/// file is in place; nothing else should still reference it.
import 'dart:convert';

import 'package:flutter/material.dart';
import '../../data/app_database.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/quick_add/quick_add_sheet.dart'
    show QuickAddAction, QuickAddRegistry;

const _kContactsExtensionType = 'contacts';

/// Broadcasts contact-list changes so any open [ContactScreen]
/// refreshes even when the write came from elsewhere (e.g. the quick-add
/// sheet's "Add Contact" card) — same spirit as TodoRefreshBus in
/// widgets/quick_add_sheet.dart, just for contacts.
class ContactsRefreshBus {
  ContactsRefreshBus._();
  static final ValueNotifier<int> _ticks = ValueNotifier<int>(0);
  static Listenable get listenable => _ticks;
  static void notify() => _ticks.value++;
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
class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  List<ExtensionRecord> _contacts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
    // Picks up contacts added via the quick-add sheet while this screen
    // is already open (that write path doesn't go through this widget).
    ContactsRefreshBus.listenable.addListener(_refresh);
  }

  @override
  void dispose() {
    ContactsRefreshBus.listenable.removeListener(_refresh);
    super.dispose();
  }

  Future<void> _refresh() async {
    final rows = await AppDatabase.instance.getExtensionRecords(
      _kContactsExtensionType,
    );
    if (!mounted) return;
    setState(() {
      _contacts = rows;
      _loading = false;
    });
  }

  /// The rule you get is: prefer the second name, fall back to the first
  /// name if it's blank. Neither is guaranteed non-empty (both fields are
  /// optional in the dialog), so this can still return ''.
  static String _displayName(Map<String, dynamic> payload) {
    final secondName = (payload['secondName'] as String? ?? '').trim();
    final firstName = (payload['firstName'] as String? ?? '').trim();
    return secondName.isNotEmpty ? secondName : firstName;
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
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add contact',
            onPressed: () => showAddContactDialog(context),
          ),
        ],
      ),
      // No FAB here on purpose — this screen used to have its own square
      // FloatingActionButton, but since it lives inside MainShell's
      // Scaffold, that stacked on top of MainShell's round quick-add FAB
      // (two "+" buttons at once). Adding a contact now goes through the
      // shared quick-add sheet's "Add Contact" card (registerQuickAddContact
      // below), which calls the same showAddContactDialog either way.
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
                final name = _displayName(payload);
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

/// Shared "add contact" dialog — used by both the Contacts screen's own
/// FAB and the quick-add sheet's "Add Contact" card (via
/// [registerQuickAddContact] below), so there's exactly one dialog
/// implementation instead of two copies that can drift apart.
Future<void> showAddContactDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddContactSheet(),
  );
}

/// Add-contact form, styled to match _QuickAddSheet in quick_add_sheet.dart
/// (same rounded-top container, drag handle, title treatment) so this
/// reads as the same design language instead of a generic system dialog.
class _AddContactSheet extends StatefulWidget {
  const _AddContactSheet();

  @override
  State<_AddContactSheet> createState() => _AddContactSheetState();
}

class _AddContactSheetState extends State<_AddContactSheet> {
  final _firstNameController = TextEditingController();
  final _secondNameController = TextEditingController();
  final _numberController = TextEditingController();

  @override
  void dispose() {
    _firstNameController.dispose();
    _secondNameController.dispose();
    _numberController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final payload = {
      'number': _numberController.text.trim(),
      'firstName': _firstNameController.text.trim(),
      'secondName': _secondNameController.text.trim(),
    };
    final hasName =
        payload['secondName']!.isNotEmpty || payload['firstName']!.isNotEmpty;
    // Skip saving a contact with nothing usable to show or call — just
    // close, same behavior as before.
    if (!hasName && payload['number']!.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    await AppDatabase.instance.addExtensionRecord(
      _kContactsExtensionType,
      jsonEncode(payload),
    );
    ContactsRefreshBus.notify();
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _fieldDecoration(
    AppPalette colors,
    String label,
    IconData icon,
  ) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: colors.onSurfaceVariant, size: 20),
      filled: true,
      fillColor: colors.surfaceContainerHigh,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.standard),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      // Keeps the sheet above the keyboard, same as _QuickAddSheet would
      // need if it ever grew text fields.
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
            Text(
              'Add contact',
              style: AppTypography.bodyLg.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _firstNameController,
              style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              decoration: _fieldDecoration(
                colors,
                'First name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _secondNameController,
              style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              decoration: _fieldDecoration(
                colors,
                'Second name',
                Icons.person_outline,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _numberController,
              keyboardType: TextInputType.phone,
              style: AppTypography.bodyMd.copyWith(color: colors.textPrimary),
              decoration: _fieldDecoration(
                colors,
                'Number',
                Icons.phone_outlined,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodyMd.copyWith(
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: colors.primaryContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.standard),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: AppTypography.bodyMd.copyWith(
                        color: colors.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Registers "Add Contact" as a quick-add card. Writes to the same
/// ExtensionRecords store (type 'contacts') the screen above reads from,
/// so a contact added from the quick-add sheet shows up here too — no
/// separate data model. Call once, e.g. from MainShell's initState:
///   registerQuickAddContact();
void registerQuickAddContact() {
  QuickAddRegistry.register(
    QuickAddAction(
      icon: Icons.person_add_alt,
      title: 'Add Contact',
      subtitle: 'Save a name and number',
      onTap: (context) {
        Navigator.of(context).pop();
        showAddContactDialog(context);
      },
    ),
  );
}
