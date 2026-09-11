import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'extension_manifest.dart';

class ExtensionInstallException implements Exception {
  ExtensionInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Cross-platform extension storage (Web, Android, iOS, desktop).
/// Installed zips are persisted in [SharedPreferences] so the same code
/// path works everywhere — no dart:io filesystem access required.
class ExtensionManager {
  ExtensionManager._();
  static final ExtensionManager instance = ExtensionManager._();

  static const _prefsKey = 'taskflow_installed_extensions';

  Future<Map<String, dynamic>> _loadStore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return {};
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _saveStore(Map<String, dynamic> store) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(store));
  }

  Map<String, String>? _filesFor(
    Map<String, dynamic> store,
    InstalledExtension extension,
  ) {
    final entry = store[extension.storageId];
    if (entry is! Map) return null;
    final files = entry['files'];
    if (files is! Map) return null;
    return files.map((key, value) => MapEntry('$key', '$value'));
  }

  Future<List<InstalledExtension>> loadInstalled() async {
    final store = await _loadStore();
    final result = <InstalledExtension>[];

    for (final entry in store.values) {
      if (entry is! Map) continue;
      final manifestJson = entry['manifest'];
      if (manifestJson is! Map) continue;
      try {
        final manifest = ExtensionManifest.fromJson(
          Map<String, dynamic>.from(manifestJson),
        );
        result.add(
          InstalledExtension(manifest: manifest, storageId: manifest.id),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  Future<InstalledExtension> installFromZipBytes(Uint8List bytes) async {
    final archive = ZipDecoder().decodeBytes(bytes);

    final manifestEntry = archive.files.firstWhere(
      (f) => p.basename(f.name) == 'manifest.json',
      orElse: () => throw ExtensionInstallException(
        'This file has no manifest.json — not a valid extension package.',
      ),
    );
    final manifestJson =
        jsonDecode(utf8.decode(manifestEntry.content as List<int>))
            as Map<String, dynamic>;
    final manifest = ExtensionManifest.fromJson(manifestJson);

    final files = <String, String>{};
    for (final file in archive.files) {
      if (!file.isFile) continue;
      final content = file.content as List<int>;
      files[file.name] = utf8.decode(content, allowMalformed: true);
    }

    final store = await _loadStore();
    store[manifest.id] = {
      'manifest': manifest.toJson(),
      'files': files,
    };
    await _saveStore(store);

    return InstalledExtension(manifest: manifest, storageId: manifest.id);
  }

  Future<void> uninstall(String id) async {
    final store = await _loadStore();
    store.remove(id);
    await _saveStore(store);
  }

  Future<dynamic> readDataFile(InstalledExtension extension) async {
    final fileName = extension.manifest.dataFile;
    if (fileName == null) return null;
    final store = await _loadStore();
    final files = _filesFor(store, extension);
    final raw = files?[fileName];
    if (raw == null) return null;
    return jsonDecode(raw);
  }

  Future<String?> readCodeFile(InstalledExtension extension) async {
    final fileName = extension.manifest.codeFile;
    if (fileName == null) return null;
    final store = await _loadStore();
    final files = _filesFor(store, extension);
    return files?[fileName];
  }
}
