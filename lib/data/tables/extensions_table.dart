/// data/tables/extensions_table.dart
import 'package:drift/drift.dart';

/// Installed extension manifests + their packaged files. Replaces the
/// SharedPreferences JSON blob ExtensionManager used to keep — same
/// data, queryable SQLite storage instead. `filesJson` holds the zip's
/// file contents as a JSON-encoded Map<String,String> (path -> text),
/// same shape ExtensionManager already worked with.
class Extensions extends Table {
  TextColumn get id => text()();
  TextColumn get type => text()();
  TextColumn get name => text()();
  TextColumn get version => text()();
  TextColumn get icon => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get dataFile => text().nullable()();
  TextColumn get codeFile => text().nullable()();
  TextColumn get recordFieldsJson => text().withDefault(const Constant('[]'))();
  TextColumn get filesJson => text().withDefault(const Constant('{}'))();

  @override
  Set<Column> get primaryKey => {id};
}
