/// data/daos/extension_queries.dart
import '../app_database.dart';

/// Extension manifest + extension-record query methods, kept in their
/// own file for the same reason as TodoQueries — one file per concern.
extension ExtensionQueries on AppDatabase {
  // ---- Extensions (installed manifests + files) --------------------

  Future<List<Extension>> getAllExtensions() {
    return select(extensions).get();
  }

  Future<void> upsertExtension(ExtensionsCompanion extension) {
    return into(extensions).insertOnConflictUpdate(extension);
  }

  Future<void> deleteExtension(String id) {
    return (delete(extensions)..where((e) => e.id.equals(id))).go();
  }

  // ---- Extension records --------------------------------------------

  Future<List<ExtensionRecord>> getExtensionRecords(String extensionType) {
    return (select(
      extensionRecords,
    )..where((r) => r.extensionType.equals(extensionType))).get();
  }

  Future<int> addExtensionRecord(String extensionType, String jsonPayload) {
    return into(extensionRecords).insert(
      ExtensionRecordsCompanion.insert(
        extensionType: extensionType,
        payload: jsonPayload,
      ),
    );
  }

  Future<void> deleteExtensionRecord(int id) {
    return (delete(extensionRecords)..where((r) => r.id.equals(id))).go();
  }

  Future<void> deleteExtensionRecordsForType(String extensionType) {
    return (delete(
      extensionRecords,
    )..where((r) => r.extensionType.equals(extensionType))).go();
  }
}
