/// data/tables/extension_records_table.dart
import 'package:drift/drift.dart';

/// A generic bucket for extension-provided data, keyed by the installed
/// extension's manifest `type` (e.g. 'contacts', 'timestamp') rather than
/// a fixed per-extension table — new extension types don't require a
/// schema change here. `payload` holds a JSON-encoded record; shape is
/// whatever that extension type defines.
class ExtensionRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get extensionType => text()();
  TextColumn get payload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
