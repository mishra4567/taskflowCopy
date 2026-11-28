import 'package:drift/drift.dart';

/// A record deleted for good on this phone. Without it the other phones
/// can't tell "deleted" from "never heard of it". Written by triggers (see
/// AppDatabase._ensureSyncSchema), never by app code.
class SyncTombstones extends Table {
  /// 'task' | 'expense' | 'contact'
  TextColumn get kind => text()();
  TextColumn get uuid => text()();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {kind, uuid};
}
