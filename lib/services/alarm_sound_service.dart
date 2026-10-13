// services/alarm_sound_service
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The sound alarms ring with. [uri] is what Android's notification
/// channel plays: either the system default alarm tone, or a content://
/// URI for a file the user uploaded (saved into the phone's
/// Alarms/TaskFlow folder by MainActivity.kt).
class AlarmSound {
  const AlarmSound({
    required this.uri,
    required this.name,
    required this.isCustom,
    this.ownedByApp = false,
  });

  final String uri;
  final String name;
  final bool isCustom;

  /// True only for a file this app itself copied into MediaStore (via
  /// [AlarmSoundService.pickAndImport]) — the one case where it's safe
  /// to delete the underlying file when the person switches away from
  /// it. A sound chosen via the system ringtone picker
  /// ([AlarmSoundService.pickSystemRingtone]) or one of the bundled
  /// built-in sounds points at a file this app doesn't own (a system
  /// sound, or something baked into the APK), so it's never deleted
  /// even though it's just as "custom".
  final bool ownedByApp;

  /// Whatever the phone's own "alarm" ringtone is set to — no asset to
  /// bundle, and it always exists.
  static const defaultSound = AlarmSound(
    uri: 'content://settings/system/alarm_alert',
    name: 'Default alarm sound',
    isCustom: false,
  );
}

/// One sound bundled as a Flutter asset (declared under `assets:` in
/// pubspec.yaml, e.g. assets/sounds/chime.wav). A Flutter asset has no
/// Uri the OS's notification system can resolve a playable sound from —
/// it only exists inside the asset bundle, not as a regular file — so
/// each one is copied into MediaStore the first time it's picked (via
/// the same native "import" channel method [AlarmSoundService.
/// pickAndImport] already uses for an uploaded file) to get a real
/// content:// uri. [displayName] is derived from the filename.
class BuiltInSoundAsset {
  const BuiltInSoundAsset({required this.assetPath, required this.displayName});

  final String assetPath;
  final String displayName;
}

/// How long a snoozed alarm waits before ringing again. A fixed set of
/// options (rather than a free-entry number field) keeps the picker a
/// row of tappable chips instead of a keyboard — the same tradeoff the
/// Priority chips elsewhere in the app already make.
const snoozeOptions = <int>[5, 10, 15, 20, 30];

/// Owns the user's alarm-sound choice and snooze duration: persists
/// both, imports uploaded files, and plays a short preview. A
/// ChangeNotifier so the settings tile (and the task form's rows)
/// rebuild when either changes.
class AlarmSoundService extends ChangeNotifier {
  AlarmSoundService._();
  static final AlarmSoundService instance = AlarmSoundService._();

  static const _channel = MethodChannel('taskflow/ringtone');
  static const _uriKey = 'taskflow_alarm_sound_uri';
  static const _nameKey = 'taskflow_alarm_sound_name';
  static const _ownedKey = 'taskflow_alarm_sound_owned';
  static const _snoozeKey = 'taskflow_snooze_minutes';
  static const _defaultSnoozeMinutes = 10;
  static const _previewDuration = Duration(seconds: 6);
  static const _maxBytes = 15 * 1024 * 1024;

  AlarmSound _current = AlarmSound.defaultSound;
  AlarmSound get current => _current;

  int _snoozeMinutes = _defaultSnoozeMinutes;
  int get snoozeMinutes => _snoozeMinutes;

  bool _previewing = false;
  bool get isPreviewing => _previewing;
  Timer? _previewTimer;

  Future<void>? _loadFuture;

  /// Safe to call repeatedly; reads saved prefs once.
  Future<void> load() => _loadFuture ??= _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final uri = prefs.getString(_uriKey);
    final name = prefs.getString(_nameKey);
    final owned = prefs.getBool(_ownedKey) ?? false;
    if (uri != null && name != null) {
      _current = AlarmSound(
        uri: uri,
        name: name,
        isCustom: true,
        ownedByApp: owned,
      );
    }
    final savedSnooze = prefs.getInt(_snoozeKey);
    if (savedSnooze != null && snoozeOptions.contains(savedSnooze)) {
      _snoozeMinutes = savedSnooze;
    }
    notifyListeners();
    // The saved sound can point at a MediaStore row that no longer exists
    // (prefs restored by Android backup after a reinstall, the file
    // removed from the Files app, a Samsung media cleanup, etc.) — check
    // now rather than discovering it when an alarm tries to ring.
    await validateCurrent();
  }

  /// True if [uri] can still be opened. The phone's own default-sound
  /// pointer (content://settings/...) is always treated as present, and
  /// a failure of the check itself (e.g. the native side unavailable)
  /// counts as "present" too — wrongly discarding a working sound is a
  /// worse outcome than keeping a doubtful one.
  Future<bool> _uriExists(String uri) async {
    try {
      return await _channel.invokeMethod<bool>('exists', {'uri': uri}) ?? true;
    } catch (_) {
      return true;
    }
  }

  /// If the chosen sound's file is gone, quietly falls back to the
  /// default alarm sound instead of leaving a dead URI in place — that
  /// URI otherwise reaches a notification channel and the preview
  /// player, which fail with "FileNotFoundException: No item at
  /// content://media/...". Cheap enough to call before scheduling.
  Future<void> validateCurrent() async {
    final sound = _current;
    if (!sound.isCustom) return;
    if (await _uriExists(sound.uri)) return;
    await _forgetBuiltInCacheFor(sound.uri);
    await _save(AlarmSound.defaultSound);
  }

  /// Built-in sounds are imported into MediaStore once and their uri is
  /// cached per asset (see [_builtInCachePrefix]). Whenever an imported
  /// file is deleted or found missing, the cache entry pointing at it
  /// has to go too — otherwise the next pick of that built-in sound
  /// reuses the dead uri instead of re-importing the asset.
  Future<void> _forgetBuiltInCacheFor(String uri) async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_builtInCachePrefix) && prefs.getString(key) == uri) {
        await prefs.remove(key);
      }
    }
  }

  /// Changes how long Snooze waits before an alarm rings again. Takes
  /// effect for every alarm scheduled after this call — including
  /// existing pending ones, via the same rescheduleAllAlarms() flow
  /// AlarmSoundCard's sound changes already trigger (see
  /// NotificationService.rescheduleAllAlarms's doc for why that's
  /// necessary rather than automatic).
  Future<void> setSnoozeMinutes(int minutes) async {
    if (!snoozeOptions.contains(minutes) || minutes == _snoozeMinutes) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeKey, minutes);
    _snoozeMinutes = minutes;
    notifyListeners();
  }

  Future<void> _save(AlarmSound sound) async {
    final prefs = await SharedPreferences.getInstance();
    if (sound.isCustom) {
      await prefs.setString(_uriKey, sound.uri);
      await prefs.setString(_nameKey, sound.name);
      await prefs.setBool(_ownedKey, sound.ownedByApp);
    } else {
      await prefs.remove(_uriKey);
      await prefs.remove(_nameKey);
      await prefs.remove(_ownedKey);
    }
    _current = sound;
    notifyListeners();
  }

  /// Lets the user pick an audio file and makes it the alarm sound.
  /// [error] is a message to show the user; null with [changed] false
  /// just means they cancelled the picker.
  Future<({bool changed, String? error})> pickAndImport() async {
    await stopPreview();
    // file_picker 12+ dropped the FilePicker.platform / FilePickerResult
    // indirection — FilePicker.pickFile() returns a single PlatformFile?
    // directly, which is exactly what a one-file picker needs.
    final file = await FilePicker.pickFile(type: FileType.audio);
    final path = file?.path;
    if (file == null || path == null) return (changed: false, error: null);

    // file_picker 13.x removed PlatformFile.size (it used to be filled in
    // synchronously from the pick result) — length() asks the platform
    // directly and can return null if it genuinely can't be determined,
    // in which case we just skip the size check rather than block a
    // valid import on an unknown.
    final length = await file.length();
    if (length != null && length > _maxBytes) {
      return (changed: false, error: 'That file is too large (15 MB max).');
    }

    try {
      final uri = await _channel.invokeMethod<String>('import', {
        'path': path,
        'name': file.name,
      });
      if (uri == null) {
        return (changed: false, error: "Couldn't import that file.");
      }
      final previous = _current;
      await _save(
        AlarmSound(
          uri: uri,
          name: _prettyName(file.name),
          isCustom: true,
          ownedByApp: true,
        ),
      );
      if (previous.ownedByApp) unawaited(_deleteImported(previous.uri));
      return (changed: true, error: null);
    } on PlatformException catch (e) {
      return (changed: false, error: e.message ?? "Couldn't import that file.");
    }
  }

  /// Opens Android's own ringtone picker (RingtoneManager.ACTION_RINGTONE_
  /// PICKER, filtered to TYPE_ALARM) — the same UI the phone's own
  /// Settings app uses, so the person can choose from whatever alarm
  /// sounds already exist on the device instead of only ones they upload
  /// themselves. MainActivity.kt owns the actual Activity-result dance;
  /// this just awaits the single method-channel call.
  Future<({bool changed, String? error})> pickSystemRingtone() async {
    await stopPreview();
    try {
      final result = await _channel.invokeMethod('pickSystemRingtone');
      if (result == null) return (changed: false, error: null); // cancelled
      final map = Map<String, dynamic>.from(result as Map);
      final uri = map['uri'] as String?;
      if (uri == null) return (changed: false, error: null);
      final name = (map['name'] as String?)?.trim();

      final previous = _current;
      await _save(
        AlarmSound(
          uri: uri,
          name: (name == null || name.isEmpty) ? 'Ringtone' : name,
          isCustom: true,
          // Not ownedByApp: this points at a sound the system already
          // had (bundled, or something another app installed) — this
          // app didn't create the file and must never delete it.
        ),
      );
      if (previous.ownedByApp) unawaited(_deleteImported(previous.uri));
      return (changed: true, error: null);
    } on PlatformException catch (e) {
      return (
        changed: false,
        error: e.message ?? "Couldn't open the ringtone picker.",
      );
    }
  }

  /// Folders (relative to pubspec.yaml's `assets:` list) the built-in
  /// sound catalog is read from. Every asset directly under any of these
  /// paths becomes one selectable built-in sound — declare the folder
  /// (not each file individually) under `assets:` in pubspec.yaml, add
  /// it to this list if it's a new folder, and files inside it show up
  /// automatically with no other code changes. Safe to list a folder
  /// that doesn't exist yet or is empty — it just contributes nothing.
  static const _builtInAssetFolders = ['assets/sounds/', 'assets/systemSound/'];

  /// taskflow_builtin_uri_<assetPath> -> an already-imported content://
  /// uri for that asset, so picking the same built-in sound twice reuses
  /// the existing MediaStore copy instead of re-importing it every time.
  static const _builtInCachePrefix = 'taskflow_builtin_uri_';

  List<BuiltInSoundAsset>? _builtInCache;

  /// Lists the app's bundled sound catalog by reading Flutter's asset
  /// manifest for everything under [_builtInAssetFolder] — so the list
  /// shown in Settings/the task sheet always matches whatever's actually
  /// bundled, without a second hardcoded list to keep in sync. Cached
  /// after the first call since the manifest never changes at runtime.
  Future<List<BuiltInSoundAsset>> listBuiltInSoundAssets() async {
    final cached = _builtInCache;
    if (cached != null) return cached;

    // AssetManifest.json was removed from built Flutter apps — reading it
    // as a raw JSON string via rootBundle.loadString throws "Unable to
    // load asset" now that only the binary AssetManifest.bin is bundled.
    // AssetManifest.loadFromAssetBundle is the supported replacement; it
    // reads whichever manifest format the current engine actually ships.
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    final result =
        manifest
            .listAssets()
            .where(
              (path) =>
                  _builtInAssetFolders.any((folder) => path.startsWith(folder)),
            )
            .map(
              (path) => BuiltInSoundAsset(
                assetPath: path,
                displayName: _prettyName(path.split('/').last),
              ),
            )
            .toList()
          ..sort((a, b) => a.displayName.compareTo(b.displayName));

    _builtInCache = result;
    return result;
  }

  /// Selects one of the app's bundled sounds. The first time a given
  /// asset is picked, its bytes are copied out to a temp file and handed
  /// to the same native "import" channel method [pickAndImport] uses, so
  /// it ends up as a real MediaStore entry the notification system can
  /// resolve a sound from — a bare Flutter asset path can't be used
  /// directly. The resulting uri is cached (see [_builtInCachePrefix])
  /// so picking the same built-in sound again later is instant.
  Future<({bool changed, String? error})> selectBuiltInAsset(
    BuiltInSoundAsset asset,
  ) async {
    await stopPreview();
    final cacheKey = '$_builtInCachePrefix${asset.assetPath}';
    final prefs = await SharedPreferences.getInstance();
    var cachedUri = prefs.getString(cacheKey);
    // A cached uri is only a shortcut: the MediaStore row behind it may
    // have been deleted since (this service deletes the previous
    // imported file whenever the sound changes, and a backup restore or
    // media cleanup can remove it too). Using a dead uri is what caused
    // "FileNotFoundException: No item at content://media/...", so
    // verify it and fall back to a fresh import when it's gone.
    if (cachedUri != null && !await _uriExists(cachedUri)) {
      await prefs.remove(cacheKey);
      cachedUri = null;
    }

    try {
      final uri = cachedUri ?? await _importAsset(asset, cacheKey, prefs);
      final previous = _current;
      await _save(
        AlarmSound(
          uri: uri,
          name: asset.displayName,
          isCustom: true,
          // This app did copy the file into MediaStore (even though the
          // source was its own bundled asset), so it's safe to clean up
          // — on the next pick, selectBuiltInAsset just re-imports it.
          ownedByApp: true,
        ),
      );
      if (previous.ownedByApp && previous.uri != uri) {
        unawaited(_deleteImported(previous.uri));
      }
      return (changed: true, error: null);
    } on PlatformException catch (e) {
      return (changed: false, error: e.message ?? "Couldn't use that sound.");
    }
  }

  Future<String> _importAsset(
    BuiltInSoundAsset asset,
    String cacheKey,
    SharedPreferences prefs,
  ) async {
    final bytes = await rootBundle.load(asset.assetPath);
    final tempDir = await getTemporaryDirectory();
    final fileName = asset.assetPath.split('/').last;
    final tempFile = File('${tempDir.path}/$fileName');
    await tempFile.writeAsBytes(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );

    final uri = await _channel.invokeMethod<String>('import', {
      'path': tempFile.path,
      'name': asset.displayName,
    });
    if (uri == null) {
      throw PlatformException(
        code: 'import_failed',
        message: "Couldn't import the built-in sound.",
      );
    }
    await prefs.setString(cacheKey, uri);
    return uri;
  }

  Future<void> resetToDefault() async {
    await stopPreview();
    final previous = _current;
    await _save(AlarmSound.defaultSound);
    if (previous.ownedByApp) unawaited(_deleteImported(previous.uri));
  }

  Future<void> _deleteImported(String uri) async {
    try {
      await _channel.invokeMethod('delete', {'uri': uri});
    } catch (_) {
      // Best-effort cleanup — a leftover file in Alarms/TaskFlow is harmless.
    }
    // Whether or not the native delete succeeded, no built-in cache
    // entry should keep pointing at this uri — see
    // [_forgetBuiltInCacheFor].
    await _forgetBuiltInCacheFor(uri);
  }

  /// Plays the current sound for a few seconds. Returns an error message
  /// if it couldn't be played.
  Future<String?> preview() async {
    final before = _current;
    await validateCurrent();
    if (before.isCustom && !_current.isCustom) {
      return '"${before.name}" is no longer on this phone — switched back '
          'to the default alarm sound.';
    }
    try {
      await _channel.invokeMethod('preview', {'uri': _current.uri});
      _previewing = true;
      notifyListeners();
      _previewTimer?.cancel();
      _previewTimer = Timer(_previewDuration, stopPreview);
      return null;
    } on PlatformException catch (e) {
      return e.message ?? "Couldn't play that sound.";
    }
  }

  Future<void> stopPreview() async {
    _previewTimer?.cancel();
    if (!_previewing) return;
    _previewing = false;
    notifyListeners();
    try {
      await _channel.invokeMethod('stopPreview');
    } catch (_) {}
  }

  static String _prettyName(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }
}
