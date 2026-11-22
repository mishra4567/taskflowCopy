// main.dart
import 'package:flutter/material.dart';
import 'package:taskflow/services/notification_service.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';
import 'widgets/main_shell.dart';
import 'services/dev_mode_service.dart';
import 'package:taskflow/services/archive_trash_service.dart'; // ARCHIVE
import 'package:taskflow/services/encryption/crypto_bootstrap.dart'; // ENCRYPT

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Awaited, unlike the two below — see crypto_bootstrap.dart for why:
  // MasterKeyService/FeatureKeyService have no reactive listenable the
  // UI rebuilds from, so a deferred load could let the Settings card's
  // first frame show "not set up" on an already-set-up device. These
  // are quick secure-storage reads, not a slow scan, so this doesn't
  // delay the first frame the way NotificationService.init() did.
  await initEncryption(); // ENCRYPT
  runApp(const TaskFlowApp());
  // Both of these read from disk/do setup work, but nothing on the first
  // frame depends on them finishing first — DevModeService's `enabled`
  // and NotificationService's setup both update reactively once ready,
  // the same way themeController already does. Deferring them here keeps
  // that work off the startup-blocking path instead of freezing the
  // first frame on it (NotificationService.init() in particular loops
  // over the whole timezone database to guess the local zone, which is
  // exactly what was causing the multi-second startup freeze).
  // ignore: unawaited_futures
  DevModeService.instance.load();
  // ignore: unawaited_futures
  NotificationService.instance.init();
  TaskBinService.instance.autoArchiveCompleted();
}

class TaskFlowApp extends StatelessWidget {
  const TaskFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeController,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'TaskFlowCopy',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: mode,
          home: const MainShell(),
        );
      },
    );
  }
}