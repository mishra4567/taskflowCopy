// screens/contacts_screen
import 'package:flutter/material.dart';
import '../extensions/extension_manager.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/code_extension_view.dart';
import '../widgets/slide_page_route.dart';
import 'extensions_screen.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  bool _loading = true;
  String? _codeSource; // real compiled-at-runtime extension, if present
  List<Map<String, dynamic>>? _contacts; // plain-data fallback, or null

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    debugPrint('[Contacts] loading installed extensions...');
    final installed = await ExtensionManager.instance.loadInstalled();
    debugPrint(
      '[Contacts] found ${installed.length} installed: ${installed.map((e) => e.manifest.id).toList()}',
    );

    final match = installed.where((e) => e.manifest.id == 'contacts');
    if (match.isEmpty) {
      debugPrint('[Contacts] no contacts extension found');
      if (mounted) {
        setState(() {
          _loading = false;
          _codeSource = null;
          _contacts = null;
        });
      }
      return;
    }

    final ext = match.first;
    debugPrint(
      '[Contacts] contacts extension manifest: codeFile=${ext.manifest.codeFile}, dataFile=${ext.manifest.dataFile}, id=${ext.storageId}',
    );

    final code = await ExtensionManager.instance.readCodeFile(ext);
    debugPrint(
      '[Contacts] readCodeFile returned: ${code == null ? "null" : "${code.length} chars"}',
    );
    if (code != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _codeSource = code;
      });
      return;
    }

    final data = await ExtensionManager.instance.readDataFile(ext);
    debugPrint('[Contacts] readDataFile returned: $data');
    if (!mounted) return;
    setState(() {
      _loading = false;
      _contacts = data is List ? data.cast<Map<String, dynamic>>() : [];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Contacts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _codeSource != null
          ? CodeExtensionView(source: _codeSource!)
          : _contacts == null
          ? _NotInstalled(colors: colors)
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.containerMargin,
                AppSpacing.md,
                AppSpacing.containerMargin,
                AppSpacing.xl,
              ),
              itemCount: _contacts!.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) {
                final c = _contacts![i];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: colors.primaryContainer,
                          child: Text(
                            '${c['initials'] ?? '?'}',
                            style: TextStyle(
                              color: colors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${c['name'] ?? ''}',
                              style: AppTypography.bodyMd.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${c['role'] ?? ''}',
                              style: AppTypography.bodySm.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _NotInstalled extends StatelessWidget {
  const _NotInstalled({required this.colors});
  final AppPalette colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.extension_outlined, size: 40, color: colors.outline),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Contacts extension not installed',
              style: AppTypography.bodyMd.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                slidePageRoute((_) => const ExtensionsScreen(standalone: true)),
              ),
              child: const Text('Go to Extensions'),
            ),
          ],
        ),
      ),
    );
  }
}