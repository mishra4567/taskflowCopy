import 'package:dart_eval/dart_eval.dart';
import 'package:flutter/material.dart';
import 'package:flutter_eval/flutter_eval.dart';

import '../theme/app_palette.dart';
import '../theme/app_tokens.dart';
import '../theme/app_typography.dart';

class CodeExtensionView extends StatefulWidget {
  const CodeExtensionView({
    super.key,
    required this.source,
    this.entryFunction = 'buildExtension',
  });

  final String source;
  final String entryFunction;

  @override
  State<CodeExtensionView> createState() => _CodeExtensionViewState();
}

class _CodeExtensionViewState extends State<CodeExtensionView> {
  String? _preflightError;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _preflightCompile();
  }

  void _preflightCompile() {
    try {
      final compiler = Compiler();
      compiler.addPlugin(flutterEvalPlugin);
      final program = compiler.compile({
        'extension': {'main.dart': widget.source},
      });
      debugPrint('[extension preflight] COMPILE OK — program: $program');
      setState(() {
        _preflightError = null;
        _checked = true;
      });
    } catch (e, st) {
      debugPrint('[extension preflight] COMPILE FAILED: $e');
      debugPrint('[extension preflight] STACK: $st');
      setState(() {
        _preflightError = '$e';
        _checked = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_preflightError != null) {
      return _ExtensionError(error: 'Compile error:\n${_preflightError!}');
    }
    return CompilerWidget(
      packages: {
        'extension': {'main.dart': widget.source},
      },
      library: 'package:extension/main.dart',
      function: widget.entryFunction,
      onError: (context, error, stackTrace) {
        debugPrint('[extension runtime] ERROR: $error');
        debugPrint('[extension runtime] STACK: $stackTrace');
        return _ExtensionError(error: 'Runtime error:\n$error');
      },
    );
  }
}

class _ExtensionError extends StatelessWidget {
  const _ExtensionError({required this.error});
  final String error;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colors.error),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'This extension failed to run',
              style: AppTypography.bodyMd.copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            SelectableText(
              error,
              style: AppTypography.bodySm.copyWith(color: colors.textSecondary),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
