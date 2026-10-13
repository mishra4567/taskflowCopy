// data/tables/contacts_table.dart
import 'package:drift/drift.dart';

/// Saved contacts, in their own table. Until now each contact was a row
/// in the generic ExtensionRecords table (extensionType 'contacts', the
/// fields packed into a JSON string in `payload`) — see
/// ContactQueries.migrateLegacyContacts for how those get moved over.
///
/// `@DataClassName` gives the generated row class the name SavedContact
/// instead of the very generic `Contact`.
@DataClassName('SavedContact')
class Contacts extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firstName => text().withDefault(const Constant(''))();
  TextColumn get secondName => text().withDefault(const Constant(''))();
  TextColumn get number => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
