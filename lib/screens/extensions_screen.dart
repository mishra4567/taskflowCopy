// screens/extensions_screen
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../extensions/extension_manager.dart';
import '../extensions/extension_manifest.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/app_snackbar.dart';
import '../widgets/slide_page_route.dart';
import 'extension_runner_screen.dart';

/// Extensions page — installable modules. Tapping "Add Extension" opens
/// the system file picker so the user can select a .zip they downloaded
/// (e.g. into their Downloads folder); the zip's own manifest.json
/// determines which extension actually installs. There is no built-in
/// catalog of "known" extensions — anything with a valid manifest can
/// be installed, so the list here only ever reflects what's actually on
/// the device.
class ExtensionsScreen extends StatefulWidget {
  const ExtensionsScreen({
    super.key,
    this.standalone = false,
    this.onOpenExtension,
  });

  /// True when pushed as its own route (e.g. from ContactsScreen's "Go to
  /// Extensions" button) — adds a back-button AppBar. False when embedded
  /// as a tab inside MainShell, which already provides the AppBar/back nav.
  final bool standalone;

  /// Opens the generic extension-runner shell tab for a tapped card —
  /// only available when embedded in MainShell (passed from there), so
  /// the bottom nav stays visible. Null when standalone, since there's
  /// no shell to switch tabs in from a route pushed on top of it; that
  /// case falls back to pushing ExtensionRunnerScreen directly instead.
  final void Function(String extensionType, String title)? onOpenExtension;

  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  List<InstalledExtension> _installed = [];
  bool _loading = true;
  bool _installing = false;
  String? _loadError;
  String? _uninstallingId;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final installed = await ExtensionManager.instance.loadInstalled();
      if (!mounted) return;
      setState(() {
        _installed = installed;
        _loading = false;
        _loadError = null;
      });
    } catch (e) {
      // Don't leave the page stuck on a spinner if the extensions folder
      // can't be read for some reason — fall back to "nothing installed"
      // so Add Extension still works and the empty state renders instead.
      if (!mounted) return;
      setState(() {
        _installed = [];
        _loading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _addExtension() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (files.isEmpty) return;

    final bytes = await files.first.readAsBytes();

    setState(() => _installing = true);
    try {
      final installed = await ExtensionManager.instance.installFromZipBytes(
        bytes,
      );
      await _refresh();
      if (!mounted) return;
      showAppSnackBar(context, '${installed.manifest.name} installed');
    } on ExtensionInstallException catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, e.message);
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, "Couldn't install that file");
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  Future<void> _confirmUninstall(InstalledExtension extension) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Uninstall extension?'),
        content: Text(
          'Remove "${extension.manifest.name}"? Any data it stored will be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Uninstall'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _uninstallExtension(extension);
  }

  Future<void> _uninstallExtension(InstalledExtension extension) async {
    setState(() => _uninstallingId = extension.storageId);
    try {
      await ExtensionManager.instance.uninstall(extension.storageId);
      await _refresh();
      if (!mounted) return;
      showAppSnackBar(context, '${extension.manifest.name} uninstalled');
    } catch (_) {
      if (!mounted) return;
      showAppSnackBar(context, "Couldn't uninstall that extension");
    } finally {
      if (mounted) setState(() => _uninstallingId = null);
    }
  }

  /// Opens an installed extension. Goes through the shell's tab switch
  /// when embedded (bottom nav stays visible); falls back to a plain
  /// push when standalone, since there's no shell tab to switch to from
  /// a route sitting on top of MainShell.
  void _openExtension(InstalledExtension extension) {
    final type = extension.manifest.type;
    final title = extension.manifest.name;
    if (widget.onOpenExtension != null) {
      widget.onOpenExtension!(type, title);
      return;
    }
    Navigator.of(context).push(
      slidePageRoute(
        (_) => ExtensionRunnerScreen(
          extensionType: type,
          title: title,
          onBack: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final body = _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.containerMargin,
              AppSpacing.md,
              AppSpacing.containerMargin,
              140,
            ),
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Extensions',
                          style: AppTypography.headlineMd.copyWith(
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Enhance your workflow with these tools.',
                          style: AppTypography.bodySm.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _installing ? null : _addExtension,
                    icon: _installing
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.primary,
                            ),
                          )
                        : Icon(
                            Icons.add_circle_outline,
                            color: colors.primaryContainer,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              if (_loadError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: Text(
                    "Couldn't read installed extensions.",
                    style: AppTypography.bodySm.copyWith(color: colors.error),
                  ),
                ),

              for (final installed in _installed) ...[
                _ExtensionCard(
                  icon: installed.manifest.iconData,
                  title: installed.manifest.name,
                  description: installed.manifest.description,
                  onTap: () => _openExtension(installed),
                  onUninstall: _uninstallingId == installed.storageId
                      ? null
                      : () => _confirmUninstall(installed),
                  uninstalling: _uninstallingId == installed.storageId,
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              if (_installed.isEmpty && _loadError == null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Column(
                    children: [
                      Icon(
                        Icons.extension_outlined,
                        size: 40,
                        color: colors.textSecondary,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'No extensions installed yet',
                        style: AppTypography.bodyLg.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Download an extension .zip, then tap + above to install it.',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySm.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );

    if (widget.standalone) {
      return Scaffold(
        appBar: AppBar(title: const Text('Extensions')),
        body: body,
      );
    }
    return Scaffold(body: body);
  }
}

class _ExtensionCard extends StatelessWidget {
  const _ExtensionCard({
    required this.icon,
    required this.title,
    required this.description,
    this.onTap,
    this.onUninstall,
    this.uninstalling = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final VoidCallback? onUninstall;
  final bool uninstalling;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.container),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(AppRadius.standard),
                    ),
                    child: Icon(icon, color: colors.primary, size: 20),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.tertiary.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'INSTALLED',
                          style: AppTypography.labelCaps.copyWith(
                            color: colors.tertiary,
                            fontSize: 10,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: uninstalling
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colors.error,
                                ),
                              )
                            : IconButton(
                                padding: EdgeInsets.zero,
                                tooltip: 'Uninstall',
                                onPressed: onUninstall,
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: colors.error,
                                ),
                              ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                style: AppTypography.bodyLg.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                description,
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
