import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'extension_manifest.dart';

class ExtensionInstallException implements Exception {
  ExtensionInstallException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Installs, lists, and reads data for zip-based extensions. Extensions
/// live at <app support dir>/extensions/<id>/ — a real folder per
/// extension, unzipped from whatever the user picked from Downloads.
class ExtensionManager {
  ExtensionManager._();
  static final ExtensionManager instance = ExtensionManager._();

  Future<Directory> _root() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'extensions'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  /// Scans the extensions folder and returns every installed extension
  /// with a valid manifest.json. Corrupt/unreadable manifests are
  /// skipped rather than crashing the whole list.
  Future<List<InstalledExtension>> loadInstalled() async {
    final root = await _root();
    final result = <InstalledExtension>[];

    await for (final entity in root.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File(p.join(entity.path, 'manifest.json'));
      if (!await manifestFile.exists()) continue;
      try {
        final json =
            jsonDecode(await manifestFile.readAsString())
                as Map<String, dynamic>;
        result.add(
          InstalledExtension(
            manifest: ExtensionManifest.fromJson(json),
            directory: entity,
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return result;
  }

  /// Unzips [zipFile] into extensions/<id>/, keyed by the id declared in
  /// its own manifest.json. Re-installing the same id overwrites the
  /// previous copy (treated as an update).
  Future<InstalledExtension> installFromZip(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
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

    final root = await _root();
    final targetDir = Directory(p.join(root.path, manifest.id));
    if (await targetDir.exists()) await targetDir.delete(recursive: true);
    await targetDir.create(recursive: true);

    for (final file in archive.files) {
      if (!file.isFile) continue;
      final outFile = File(p.join(targetDir.path, file.name));
      await outFile.create(recursive: true);
      await outFile.writeAsBytes(file.content as List<int>);
    }

    return InstalledExtension(manifest: manifest, directory: targetDir);
  }

  Future<void> uninstall(String id) async {
    final root = await _root();
    final dir = Directory(p.join(root.path, id));
    if (await dir.exists()) await dir.delete(recursive: true);
  }

  /// Reads and decodes the JSON data file an extension's manifest points
  /// to (e.g. contacts.json). Returns null if the extension declares no
  /// data file or it's missing.
  Future<dynamic> readDataFile(InstalledExtension extension) async {
    final fileName = extension.manifest.dataFile;
    if (fileName == null) return null;
    final file = File(p.join(extension.directory.path, fileName));
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }
}
