// screens/extension_runner_screen
import 'package:flutter/material.dart';
import '../extensions/extension_manager.dart';
import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';
import '../widgets/code_extension_view.dart';
import '../widgets/slide_page_route.dart';
import 'extensions_screen.dart';

/// Generic screen for any code-based extension — looks up an installed
/// extension by type, and either runs its Dart source via CodeExtensionView,
/// falls back to reading plain JSON via [onData] if it's data-only, or
/// shows a "not installed" state. Not specific to Contacts; reusable for
/// any future extension that follows the same manifest shape.
///
/// Lives inside MainShell (like TodoScreen/ContactsExtensionScreen)
/// rather than being pushed over it, so the bottom nav stays visible —
/// hence `onBack` instead of Navigator.pop, and its own leading arrow
/// since the shell hides its AppBar for this page.
class ExtensionRunnerScreen extends StatefulWidget {
  const ExtensionRunnerScreen({
    super.key,
    required this.extensionType,
    required this.title,
    required this.onBack,
    this.onData,
  });

  final String extensionType;
  final String title;
  final VoidCallback onBack;

  /// Optional builder for extensions that ship plain JSON instead of
  /// code — called with the decoded data if the installed extension has
  /// a dataFile but no codeFile.
  final Widget Function(BuildContext context, dynamic data)? onData;

  @override
  State<ExtensionRunnerScreen> createState() => _ExtensionRunnerScreenState();
}

class _ExtensionRunnerScreenState extends State<ExtensionRunnerScreen> {
  bool _loading = true;
  String? _codeSource;
  dynamic _data;
  bool _installed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final installed = await ExtensionManager.instance.loadInstalled();
    final match = installed.where(
      (e) => e.manifest.type == widget.extensionType,
    );
    if (match.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _installed = false;
        });
      }
      return;
    }

    final ext = match.first;
    final code = await ExtensionManager.instance.readCodeFile(ext);
    if (code != null) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _installed = true;
        _codeSource = code;
      });
      return;
    }

    final data = await ExtensionManager.instance.readDataFile(ext);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _installed = true;
      _data = data;
    });
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
        title: Text(widget.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : !_installed
          ? _NotInstalled(colors: colors, title: widget.title)
          : _codeSource != null
          ? CodeExtensionView(source: _codeSource!)
          : widget.onData != null
          ? widget.onData!(context, _data)
          : Center(
              child: Text(
                'No renderer provided for this extension\'s data.',
                style: AppTypography.bodySm.copyWith(
                  color: colors.textSecondary,
                ),
              ),
            ),
    );
  }
}

class _NotInstalled extends StatelessWidget {
  const _NotInstalled({required this.colors, required this.title});
  final AppPalette colors;
  final String title;

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
              '$title extension not installed',
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
