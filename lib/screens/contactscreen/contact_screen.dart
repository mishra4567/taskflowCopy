/// screens/contactscreen/contact_screen.dart
///
/// Contacts — a plain built-in screen backed by AppDatabase's own
/// `contacts` table (data/tables/contacts_table.dart), not an extension.
/// The list is a live Drift stream, so adding or deleting a contact from
/// anywhere (this screen, the quick-add sheet, a backup restore) updates
/// it by itself with no refresh plumbing.
///
/// Lives inside MainShell rather than being pushed over it, so the
/// bottom nav stays visible — hence `onBack` instead of Navigator.pop,
/// and its own AppBar since the shell hides its bar for this page.
import 'package:flutter/material.dart';

import '../../data/app_database.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_tokens.dart';
import '../../theme/app_typography.dart';
import '../../widgets/quick_add/quick_add_sheet.dart'
    show QuickAddAction, QuickAddRegistry;

class ContactScreen extends StatefulWidget {
  const ContactScreen({super.key, this.onBack});

  /// Null when there's no previous page to return to — no back arrow is
  /// shown at all then, rather than one wired to nothing.
  final VoidCallback? onBack;

  @override
  State<ContactScreen> createState() => _ContactScreenState();
}

class _ContactScreenState extends State<ContactScreen> {
  // Created once. A StreamBuilder handed a brand-new stream on every
  // build would resubscribe (and flash a spinner) each time.
  late final Stream<List<SavedContact>> _contacts = AppDatabase.instance
      .watchContacts();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(
        leading: widget.onBack == null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: widget.onBack,
              ),
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Add contact',
            onPressed: () => showAddContactDialog(context),
          ),
        ],
      ),
      body: StreamBuilder<List<SavedContact>>(
        stream: _contacts,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.containerMargin),
                child: Text(
                  "Couldn't load contacts.\n${snapshot.error}",
                  textAlign: TextAlign.center,
                  style: AppTypography.bodySm.copyWith(color: colors.error),
                ),
              ),
            );
          }
          final contacts = snapshot.data;
          if (contacts == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (contacts.isEmpty) {
            return Center(
              child: Text(
                'No contacts yet — tap + to add one.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.md,
              AppSpacing.containerMargin,
              100,
            ),
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              final name = contact.displayName;
              final number = contact.number.trim();

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
                    tooltip: 'Delete',
                    onPressed: () =>
                        AppDatabase.instance.deleteContact(contact.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Opens the add-contact bottom sheet — used by this screen's AppBar
/// button and by the quick-add sheet's "Add Contact" card, so there is
/// one form, not two copies that can drift apart.
Future<void> showAddContactDialog(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => const _AddContactSheet(),
  );
}

/// Add-contact form, styled to match the quick-add sheet (same
/// rounded-top container, drag handle and title treatment).
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
    final firstName = _firstNameController.text.trim();
    final secondName = _secondNameController.text.trim();
    final number = _numberController.text.trim();

    // Nothing usable to show or call — just close.
    if (firstName.isEmpty && secondName.isEmpty && number.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    await AppDatabase.instance.addContact(
      firstName: firstName,
      secondName: secondName,
      number: number,
    );
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
      // Keeps the sheet above the keyboard.
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

/// Registers "Add Contact" as a quick-add card. Call once, from
/// MainShell's initState.
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