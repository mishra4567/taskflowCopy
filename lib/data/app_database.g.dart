// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TodosTable extends Todos with TableInfo<$TodosTable, Todo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TodosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueDateMeta = const VerificationMeta(
    'dueDate',
  );
  @override
  late final GeneratedColumn<DateTime> dueDate = GeneratedColumn<DateTime>(
    'due_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _notificationEnabledMeta =
      const VerificationMeta('notificationEnabled');
  @override
  late final GeneratedColumn<bool> notificationEnabled = GeneratedColumn<bool>(
    'notification_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("notification_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _alarmEnabledMeta = const VerificationMeta(
    'alarmEnabled',
  );
  @override
  late final GeneratedColumn<bool> alarmEnabled = GeneratedColumn<bool>(
    'alarm_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("alarm_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    category,
    priority,
    dueDate,
    isDone,
    notificationEnabled,
    alarmEnabled,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'todos';
  @override
  VerificationContext validateIntegrity(
    Insertable<Todo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('due_date')) {
      context.handle(
        _dueDateMeta,
        dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta),
      );
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    if (data.containsKey('notification_enabled')) {
      context.handle(
        _notificationEnabledMeta,
        notificationEnabled.isAcceptableOrUnknown(
          data['notification_enabled']!,
          _notificationEnabledMeta,
        ),
      );
    }
    if (data.containsKey('alarm_enabled')) {
      context.handle(
        _alarmEnabledMeta,
        alarmEnabled.isAcceptableOrUnknown(
          data['alarm_enabled']!,
          _alarmEnabledMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Todo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Todo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      dueDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}due_date'],
      ),
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
      notificationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}notification_enabled'],
      )!,
      alarmEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}alarm_enabled'],
      )!,
    );
  }

  @override
  $TodosTable createAlias(String alias) {
    return $TodosTable(attachedDatabase, alias);
  }
}

class Todo extends DataClass implements Insertable<Todo> {
  final String id;
  final String title;
  final String category;
  final String priority;
  final DateTime? dueDate;
  final bool isDone;
  final bool notificationEnabled;
  final bool alarmEnabled;
  const Todo({
    required this.id,
    required this.title,
    required this.category,
    required this.priority,
    this.dueDate,
    required this.isDone,
    required this.notificationEnabled,
    required this.alarmEnabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['category'] = Variable<String>(category);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || dueDate != null) {
      map['due_date'] = Variable<DateTime>(dueDate);
    }
    map['is_done'] = Variable<bool>(isDone);
    map['notification_enabled'] = Variable<bool>(notificationEnabled);
    map['alarm_enabled'] = Variable<bool>(alarmEnabled);
    return map;
  }

  TodosCompanion toCompanion(bool nullToAbsent) {
    return TodosCompanion(
      id: Value(id),
      title: Value(title),
      category: Value(category),
      priority: Value(priority),
      dueDate: dueDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueDate),
      isDone: Value(isDone),
      notificationEnabled: Value(notificationEnabled),
      alarmEnabled: Value(alarmEnabled),
    );
  }

  factory Todo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Todo(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      category: serializer.fromJson<String>(json['category']),
      priority: serializer.fromJson<String>(json['priority']),
      dueDate: serializer.fromJson<DateTime?>(json['dueDate']),
      isDone: serializer.fromJson<bool>(json['isDone']),
      notificationEnabled: serializer.fromJson<bool>(
        json['notificationEnabled'],
      ),
      alarmEnabled: serializer.fromJson<bool>(json['alarmEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'category': serializer.toJson<String>(category),
      'priority': serializer.toJson<String>(priority),
      'dueDate': serializer.toJson<DateTime?>(dueDate),
      'isDone': serializer.toJson<bool>(isDone),
      'notificationEnabled': serializer.toJson<bool>(notificationEnabled),
      'alarmEnabled': serializer.toJson<bool>(alarmEnabled),
    };
  }

  Todo copyWith({
    String? id,
    String? title,
    String? category,
    String? priority,
    Value<DateTime?> dueDate = const Value.absent(),
    bool? isDone,
    bool? notificationEnabled,
    bool? alarmEnabled,
  }) => Todo(
    id: id ?? this.id,
    title: title ?? this.title,
    category: category ?? this.category,
    priority: priority ?? this.priority,
    dueDate: dueDate.present ? dueDate.value : this.dueDate,
    isDone: isDone ?? this.isDone,
    notificationEnabled: notificationEnabled ?? this.notificationEnabled,
    alarmEnabled: alarmEnabled ?? this.alarmEnabled,
  );
  Todo copyWithCompanion(TodosCompanion data) {
    return Todo(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      category: data.category.present ? data.category.value : this.category,
      priority: data.priority.present ? data.priority.value : this.priority,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
      notificationEnabled: data.notificationEnabled.present
          ? data.notificationEnabled.value
          : this.notificationEnabled,
      alarmEnabled: data.alarmEnabled.present
          ? data.alarmEnabled.value
          : this.alarmEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Todo(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('isDone: $isDone, ')
          ..write('notificationEnabled: $notificationEnabled, ')
          ..write('alarmEnabled: $alarmEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    category,
    priority,
    dueDate,
    isDone,
    notificationEnabled,
    alarmEnabled,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Todo &&
          other.id == this.id &&
          other.title == this.title &&
          other.category == this.category &&
          other.priority == this.priority &&
          other.dueDate == this.dueDate &&
          other.isDone == this.isDone &&
          other.notificationEnabled == this.notificationEnabled &&
          other.alarmEnabled == this.alarmEnabled);
}

class TodosCompanion extends UpdateCompanion<Todo> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> category;
  final Value<String> priority;
  final Value<DateTime?> dueDate;
  final Value<bool> isDone;
  final Value<bool> notificationEnabled;
  final Value<bool> alarmEnabled;
  final Value<int> rowid;
  const TodosCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.category = const Value.absent(),
    this.priority = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.isDone = const Value.absent(),
    this.notificationEnabled = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TodosCompanion.insert({
    required String id,
    required String title,
    required String category,
    required String priority,
    this.dueDate = const Value.absent(),
    this.isDone = const Value.absent(),
    this.notificationEnabled = const Value.absent(),
    this.alarmEnabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       title = Value(title),
       category = Value(category),
       priority = Value(priority);
  static Insertable<Todo> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? category,
    Expression<String>? priority,
    Expression<DateTime>? dueDate,
    Expression<bool>? isDone,
    Expression<bool>? notificationEnabled,
    Expression<bool>? alarmEnabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (priority != null) 'priority': priority,
      if (dueDate != null) 'due_date': dueDate,
      if (isDone != null) 'is_done': isDone,
      if (notificationEnabled != null)
        'notification_enabled': notificationEnabled,
      if (alarmEnabled != null) 'alarm_enabled': alarmEnabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TodosCompanion copyWith({
    Value<String>? id,
    Value<String>? title,
    Value<String>? category,
    Value<String>? priority,
    Value<DateTime?>? dueDate,
    Value<bool>? isDone,
    Value<bool>? notificationEnabled,
    Value<bool>? alarmEnabled,
    Value<int>? rowid,
  }) {
    return TodosCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isDone: isDone ?? this.isDone,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      alarmEnabled: alarmEnabled ?? this.alarmEnabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<DateTime>(dueDate.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    if (notificationEnabled.present) {
      map['notification_enabled'] = Variable<bool>(notificationEnabled.value);
    }
    if (alarmEnabled.present) {
      map['alarm_enabled'] = Variable<bool>(alarmEnabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TodosCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('category: $category, ')
          ..write('priority: $priority, ')
          ..write('dueDate: $dueDate, ')
          ..write('isDone: $isDone, ')
          ..write('notificationEnabled: $notificationEnabled, ')
          ..write('alarmEnabled: $alarmEnabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SubtasksTable extends Subtasks with TableInfo<$SubtasksTable, Subtask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SubtasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _todoIdMeta = const VerificationMeta('todoId');
  @override
  late final GeneratedColumn<String> todoId = GeneratedColumn<String>(
    'todo_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES todos (id)',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDoneMeta = const VerificationMeta('isDone');
  @override
  late final GeneratedColumn<bool> isDone = GeneratedColumn<bool>(
    'is_done',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_done" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, todoId, title, isDone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'subtasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Subtask> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('todo_id')) {
      context.handle(
        _todoIdMeta,
        todoId.isAcceptableOrUnknown(data['todo_id']!, _todoIdMeta),
      );
    } else if (isInserting) {
      context.missing(_todoIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('is_done')) {
      context.handle(
        _isDoneMeta,
        isDone.isAcceptableOrUnknown(data['is_done']!, _isDoneMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Subtask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Subtask(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      todoId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}todo_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      isDone: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_done'],
      )!,
    );
  }

  @override
  $SubtasksTable createAlias(String alias) {
    return $SubtasksTable(attachedDatabase, alias);
  }
}

class Subtask extends DataClass implements Insertable<Subtask> {
  final int id;
  final String todoId;
  final String title;
  final bool isDone;
  const Subtask({
    required this.id,
    required this.todoId,
    required this.title,
    required this.isDone,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['todo_id'] = Variable<String>(todoId);
    map['title'] = Variable<String>(title);
    map['is_done'] = Variable<bool>(isDone);
    return map;
  }

  SubtasksCompanion toCompanion(bool nullToAbsent) {
    return SubtasksCompanion(
      id: Value(id),
      todoId: Value(todoId),
      title: Value(title),
      isDone: Value(isDone),
    );
  }

  factory Subtask.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Subtask(
      id: serializer.fromJson<int>(json['id']),
      todoId: serializer.fromJson<String>(json['todoId']),
      title: serializer.fromJson<String>(json['title']),
      isDone: serializer.fromJson<bool>(json['isDone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'todoId': serializer.toJson<String>(todoId),
      'title': serializer.toJson<String>(title),
      'isDone': serializer.toJson<bool>(isDone),
    };
  }

  Subtask copyWith({int? id, String? todoId, String? title, bool? isDone}) =>
      Subtask(
        id: id ?? this.id,
        todoId: todoId ?? this.todoId,
        title: title ?? this.title,
        isDone: isDone ?? this.isDone,
      );
  Subtask copyWithCompanion(SubtasksCompanion data) {
    return Subtask(
      id: data.id.present ? data.id.value : this.id,
      todoId: data.todoId.present ? data.todoId.value : this.todoId,
      title: data.title.present ? data.title.value : this.title,
      isDone: data.isDone.present ? data.isDone.value : this.isDone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Subtask(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, todoId, title, isDone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Subtask &&
          other.id == this.id &&
          other.todoId == this.todoId &&
          other.title == this.title &&
          other.isDone == this.isDone);
}

class SubtasksCompanion extends UpdateCompanion<Subtask> {
  final Value<int> id;
  final Value<String> todoId;
  final Value<String> title;
  final Value<bool> isDone;
  const SubtasksCompanion({
    this.id = const Value.absent(),
    this.todoId = const Value.absent(),
    this.title = const Value.absent(),
    this.isDone = const Value.absent(),
  });
  SubtasksCompanion.insert({
    this.id = const Value.absent(),
    required String todoId,
    required String title,
    this.isDone = const Value.absent(),
  }) : todoId = Value(todoId),
       title = Value(title);
  static Insertable<Subtask> custom({
    Expression<int>? id,
    Expression<String>? todoId,
    Expression<String>? title,
    Expression<bool>? isDone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (todoId != null) 'todo_id': todoId,
      if (title != null) 'title': title,
      if (isDone != null) 'is_done': isDone,
    });
  }

  SubtasksCompanion copyWith({
    Value<int>? id,
    Value<String>? todoId,
    Value<String>? title,
    Value<bool>? isDone,
  }) {
    return SubtasksCompanion(
      id: id ?? this.id,
      todoId: todoId ?? this.todoId,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (todoId.present) {
      map['todo_id'] = Variable<String>(todoId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (isDone.present) {
      map['is_done'] = Variable<bool>(isDone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SubtasksCompanion(')
          ..write('id: $id, ')
          ..write('todoId: $todoId, ')
          ..write('title: $title, ')
          ..write('isDone: $isDone')
          ..write(')'))
        .toString();
  }
}

class $ExtensionsTable extends Extensions
    with TableInfo<$ExtensionsTable, Extension> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtensionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _iconMeta = const VerificationMeta('icon');
  @override
  late final GeneratedColumn<String> icon = GeneratedColumn<String>(
    'icon',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dataFileMeta = const VerificationMeta(
    'dataFile',
  );
  @override
  late final GeneratedColumn<String> dataFile = GeneratedColumn<String>(
    'data_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _codeFileMeta = const VerificationMeta(
    'codeFile',
  );
  @override
  late final GeneratedColumn<String> codeFile = GeneratedColumn<String>(
    'code_file',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordFieldsJsonMeta = const VerificationMeta(
    'recordFieldsJson',
  );
  @override
  late final GeneratedColumn<String> recordFieldsJson = GeneratedColumn<String>(
    'record_fields_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _filesJsonMeta = const VerificationMeta(
    'filesJson',
  );
  @override
  late final GeneratedColumn<String> filesJson = GeneratedColumn<String>(
    'files_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    type,
    name,
    version,
    icon,
    description,
    dataFile,
    codeFile,
    recordFieldsJson,
    filesJson,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extensions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Extension> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('icon')) {
      context.handle(
        _iconMeta,
        icon.isAcceptableOrUnknown(data['icon']!, _iconMeta),
      );
    } else if (isInserting) {
      context.missing(_iconMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('data_file')) {
      context.handle(
        _dataFileMeta,
        dataFile.isAcceptableOrUnknown(data['data_file']!, _dataFileMeta),
      );
    }
    if (data.containsKey('code_file')) {
      context.handle(
        _codeFileMeta,
        codeFile.isAcceptableOrUnknown(data['code_file']!, _codeFileMeta),
      );
    }
    if (data.containsKey('record_fields_json')) {
      context.handle(
        _recordFieldsJsonMeta,
        recordFieldsJson.isAcceptableOrUnknown(
          data['record_fields_json']!,
          _recordFieldsJsonMeta,
        ),
      );
    }
    if (data.containsKey('files_json')) {
      context.handle(
        _filesJsonMeta,
        filesJson.isAcceptableOrUnknown(data['files_json']!, _filesJsonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Extension map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Extension(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      )!,
      icon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}icon'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      )!,
      dataFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_file'],
      ),
      codeFile: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}code_file'],
      ),
      recordFieldsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_fields_json'],
      )!,
      filesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}files_json'],
      )!,
    );
  }

  @override
  $ExtensionsTable createAlias(String alias) {
    return $ExtensionsTable(attachedDatabase, alias);
  }
}

class Extension extends DataClass implements Insertable<Extension> {
  final String id;
  final String type;
  final String name;
  final String version;
  final String icon;
  final String description;
  final String? dataFile;
  final String? codeFile;
  final String recordFieldsJson;
  final String filesJson;
  const Extension({
    required this.id,
    required this.type,
    required this.name,
    required this.version,
    required this.icon,
    required this.description,
    this.dataFile,
    this.codeFile,
    required this.recordFieldsJson,
    required this.filesJson,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['version'] = Variable<String>(version);
    map['icon'] = Variable<String>(icon);
    map['description'] = Variable<String>(description);
    if (!nullToAbsent || dataFile != null) {
      map['data_file'] = Variable<String>(dataFile);
    }
    if (!nullToAbsent || codeFile != null) {
      map['code_file'] = Variable<String>(codeFile);
    }
    map['record_fields_json'] = Variable<String>(recordFieldsJson);
    map['files_json'] = Variable<String>(filesJson);
    return map;
  }

  ExtensionsCompanion toCompanion(bool nullToAbsent) {
    return ExtensionsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      version: Value(version),
      icon: Value(icon),
      description: Value(description),
      dataFile: dataFile == null && nullToAbsent
          ? const Value.absent()
          : Value(dataFile),
      codeFile: codeFile == null && nullToAbsent
          ? const Value.absent()
          : Value(codeFile),
      recordFieldsJson: Value(recordFieldsJson),
      filesJson: Value(filesJson),
    );
  }

  factory Extension.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Extension(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      version: serializer.fromJson<String>(json['version']),
      icon: serializer.fromJson<String>(json['icon']),
      description: serializer.fromJson<String>(json['description']),
      dataFile: serializer.fromJson<String?>(json['dataFile']),
      codeFile: serializer.fromJson<String?>(json['codeFile']),
      recordFieldsJson: serializer.fromJson<String>(json['recordFieldsJson']),
      filesJson: serializer.fromJson<String>(json['filesJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'version': serializer.toJson<String>(version),
      'icon': serializer.toJson<String>(icon),
      'description': serializer.toJson<String>(description),
      'dataFile': serializer.toJson<String?>(dataFile),
      'codeFile': serializer.toJson<String?>(codeFile),
      'recordFieldsJson': serializer.toJson<String>(recordFieldsJson),
      'filesJson': serializer.toJson<String>(filesJson),
    };
  }

  Extension copyWith({
    String? id,
    String? type,
    String? name,
    String? version,
    String? icon,
    String? description,
    Value<String?> dataFile = const Value.absent(),
    Value<String?> codeFile = const Value.absent(),
    String? recordFieldsJson,
    String? filesJson,
  }) => Extension(
    id: id ?? this.id,
    type: type ?? this.type,
    name: name ?? this.name,
    version: version ?? this.version,
    icon: icon ?? this.icon,
    description: description ?? this.description,
    dataFile: dataFile.present ? dataFile.value : this.dataFile,
    codeFile: codeFile.present ? codeFile.value : this.codeFile,
    recordFieldsJson: recordFieldsJson ?? this.recordFieldsJson,
    filesJson: filesJson ?? this.filesJson,
  );
  Extension copyWithCompanion(ExtensionsCompanion data) {
    return Extension(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      version: data.version.present ? data.version.value : this.version,
      icon: data.icon.present ? data.icon.value : this.icon,
      description: data.description.present
          ? data.description.value
          : this.description,
      dataFile: data.dataFile.present ? data.dataFile.value : this.dataFile,
      codeFile: data.codeFile.present ? data.codeFile.value : this.codeFile,
      recordFieldsJson: data.recordFieldsJson.present
          ? data.recordFieldsJson.value
          : this.recordFieldsJson,
      filesJson: data.filesJson.present ? data.filesJson.value : this.filesJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Extension(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('icon: $icon, ')
          ..write('description: $description, ')
          ..write('dataFile: $dataFile, ')
          ..write('codeFile: $codeFile, ')
          ..write('recordFieldsJson: $recordFieldsJson, ')
          ..write('filesJson: $filesJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    type,
    name,
    version,
    icon,
    description,
    dataFile,
    codeFile,
    recordFieldsJson,
    filesJson,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Extension &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.version == this.version &&
          other.icon == this.icon &&
          other.description == this.description &&
          other.dataFile == this.dataFile &&
          other.codeFile == this.codeFile &&
          other.recordFieldsJson == this.recordFieldsJson &&
          other.filesJson == this.filesJson);
}

class ExtensionsCompanion extends UpdateCompanion<Extension> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> version;
  final Value<String> icon;
  final Value<String> description;
  final Value<String?> dataFile;
  final Value<String?> codeFile;
  final Value<String> recordFieldsJson;
  final Value<String> filesJson;
  final Value<int> rowid;
  const ExtensionsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.version = const Value.absent(),
    this.icon = const Value.absent(),
    this.description = const Value.absent(),
    this.dataFile = const Value.absent(),
    this.codeFile = const Value.absent(),
    this.recordFieldsJson = const Value.absent(),
    this.filesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ExtensionsCompanion.insert({
    required String id,
    required String type,
    required String name,
    required String version,
    required String icon,
    this.description = const Value.absent(),
    this.dataFile = const Value.absent(),
    this.codeFile = const Value.absent(),
    this.recordFieldsJson = const Value.absent(),
    this.filesJson = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       type = Value(type),
       name = Value(name),
       version = Value(version),
       icon = Value(icon);
  static Insertable<Extension> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? version,
    Expression<String>? icon,
    Expression<String>? description,
    Expression<String>? dataFile,
    Expression<String>? codeFile,
    Expression<String>? recordFieldsJson,
    Expression<String>? filesJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (version != null) 'version': version,
      if (icon != null) 'icon': icon,
      if (description != null) 'description': description,
      if (dataFile != null) 'data_file': dataFile,
      if (codeFile != null) 'code_file': codeFile,
      if (recordFieldsJson != null) 'record_fields_json': recordFieldsJson,
      if (filesJson != null) 'files_json': filesJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ExtensionsCompanion copyWith({
    Value<String>? id,
    Value<String>? type,
    Value<String>? name,
    Value<String>? version,
    Value<String>? icon,
    Value<String>? description,
    Value<String?>? dataFile,
    Value<String?>? codeFile,
    Value<String>? recordFieldsJson,
    Value<String>? filesJson,
    Value<int>? rowid,
  }) {
    return ExtensionsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      version: version ?? this.version,
      icon: icon ?? this.icon,
      description: description ?? this.description,
      dataFile: dataFile ?? this.dataFile,
      codeFile: codeFile ?? this.codeFile,
      recordFieldsJson: recordFieldsJson ?? this.recordFieldsJson,
      filesJson: filesJson ?? this.filesJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (icon.present) {
      map['icon'] = Variable<String>(icon.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (dataFile.present) {
      map['data_file'] = Variable<String>(dataFile.value);
    }
    if (codeFile.present) {
      map['code_file'] = Variable<String>(codeFile.value);
    }
    if (recordFieldsJson.present) {
      map['record_fields_json'] = Variable<String>(recordFieldsJson.value);
    }
    if (filesJson.present) {
      map['files_json'] = Variable<String>(filesJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtensionsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('version: $version, ')
          ..write('icon: $icon, ')
          ..write('description: $description, ')
          ..write('dataFile: $dataFile, ')
          ..write('codeFile: $codeFile, ')
          ..write('recordFieldsJson: $recordFieldsJson, ')
          ..write('filesJson: $filesJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ExtensionRecordsTable extends ExtensionRecords
    with TableInfo<$ExtensionRecordsTable, ExtensionRecord> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ExtensionRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _extensionTypeMeta = const VerificationMeta(
    'extensionType',
  );
  @override
  late final GeneratedColumn<String> extensionType = GeneratedColumn<String>(
    'extension_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, extensionType, payload, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'extension_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<ExtensionRecord> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('extension_type')) {
      context.handle(
        _extensionTypeMeta,
        extensionType.isAcceptableOrUnknown(
          data['extension_type']!,
          _extensionTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_extensionTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ExtensionRecord map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ExtensionRecord(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      extensionType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extension_type'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ExtensionRecordsTable createAlias(String alias) {
    return $ExtensionRecordsTable(attachedDatabase, alias);
  }
}

class ExtensionRecord extends DataClass implements Insertable<ExtensionRecord> {
  final int id;
  final String extensionType;
  final String payload;
  final DateTime createdAt;
  const ExtensionRecord({
    required this.id,
    required this.extensionType,
    required this.payload,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['extension_type'] = Variable<String>(extensionType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ExtensionRecordsCompanion toCompanion(bool nullToAbsent) {
    return ExtensionRecordsCompanion(
      id: Value(id),
      extensionType: Value(extensionType),
      payload: Value(payload),
      createdAt: Value(createdAt),
    );
  }

  factory ExtensionRecord.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ExtensionRecord(
      id: serializer.fromJson<int>(json['id']),
      extensionType: serializer.fromJson<String>(json['extensionType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'extensionType': serializer.toJson<String>(extensionType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ExtensionRecord copyWith({
    int? id,
    String? extensionType,
    String? payload,
    DateTime? createdAt,
  }) => ExtensionRecord(
    id: id ?? this.id,
    extensionType: extensionType ?? this.extensionType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
  );
  ExtensionRecord copyWithCompanion(ExtensionRecordsCompanion data) {
    return ExtensionRecord(
      id: data.id.present ? data.id.value : this.id,
      extensionType: data.extensionType.present
          ? data.extensionType.value
          : this.extensionType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ExtensionRecord(')
          ..write('id: $id, ')
          ..write('extensionType: $extensionType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, extensionType, payload, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ExtensionRecord &&
          other.id == this.id &&
          other.extensionType == this.extensionType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt);
}

class ExtensionRecordsCompanion extends UpdateCompanion<ExtensionRecord> {
  final Value<int> id;
  final Value<String> extensionType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  const ExtensionRecordsCompanion({
    this.id = const Value.absent(),
    this.extensionType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ExtensionRecordsCompanion.insert({
    this.id = const Value.absent(),
    required String extensionType,
    required String payload,
    this.createdAt = const Value.absent(),
  }) : extensionType = Value(extensionType),
       payload = Value(payload);
  static Insertable<ExtensionRecord> custom({
    Expression<int>? id,
    Expression<String>? extensionType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (extensionType != null) 'extension_type': extensionType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ExtensionRecordsCompanion copyWith({
    Value<int>? id,
    Value<String>? extensionType,
    Value<String>? payload,
    Value<DateTime>? createdAt,
  }) {
    return ExtensionRecordsCompanion(
      id: id ?? this.id,
      extensionType: extensionType ?? this.extensionType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (extensionType.present) {
      map['extension_type'] = Variable<String>(extensionType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ExtensionRecordsCompanion(')
          ..write('id: $id, ')
          ..write('extensionType: $extensionType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TodosTable todos = $TodosTable(this);
  late final $SubtasksTable subtasks = $SubtasksTable(this);
  late final $ExtensionsTable extensions = $ExtensionsTable(this);
  late final $ExtensionRecordsTable extensionRecords = $ExtensionRecordsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    todos,
    subtasks,
    extensions,
    extensionRecords,
  ];
}

typedef $$TodosTableCreateCompanionBuilder =
    TodosCompanion Function({
      required String id,
      required String title,
      required String category,
      required String priority,
      Value<DateTime?> dueDate,
      Value<bool> isDone,
      Value<bool> notificationEnabled,
      Value<bool> alarmEnabled,
      Value<int> rowid,
    });
typedef $$TodosTableUpdateCompanionBuilder =
    TodosCompanion Function({
      Value<String> id,
      Value<String> title,
      Value<String> category,
      Value<String> priority,
      Value<DateTime?> dueDate,
      Value<bool> isDone,
      Value<bool> notificationEnabled,
      Value<bool> alarmEnabled,
      Value<int> rowid,
    });

final class $$TodosTableReferences
    extends BaseReferences<_$AppDatabase, $TodosTable, Todo> {
  $$TodosTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$SubtasksTable, List<Subtask>> _subtasksRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.subtasks,
    aliasName: $_aliasNameGenerator(db.todos.id, db.subtasks.todoId),
  );

  $$SubtasksTableProcessedTableManager get subtasksRefs {
    final manager = $$SubtasksTableTableManager(
      $_db,
      $_db.subtasks,
    ).filter((f) => f.todoId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_subtasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TodosTableFilterComposer extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> subtasksRefs(
    Expression<bool> Function($$SubtasksTableFilterComposer f) f,
  ) {
    final $$SubtasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableFilterComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodosTableOrderingComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dueDate => $composableBuilder(
    column: $table.dueDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TodosTableAnnotationComposer
    extends Composer<_$AppDatabase, $TodosTable> {
  $$TodosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<DateTime> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  GeneratedColumn<bool> get notificationEnabled => $composableBuilder(
    column: $table.notificationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get alarmEnabled => $composableBuilder(
    column: $table.alarmEnabled,
    builder: (column) => column,
  );

  Expression<T> subtasksRefs<T extends Object>(
    Expression<T> Function($$SubtasksTableAnnotationComposer a) f,
  ) {
    final $$SubtasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.subtasks,
      getReferencedColumn: (t) => t.todoId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SubtasksTableAnnotationComposer(
            $db: $db,
            $table: $db.subtasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TodosTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TodosTable,
          Todo,
          $$TodosTableFilterComposer,
          $$TodosTableOrderingComposer,
          $$TodosTableAnnotationComposer,
          $$TodosTableCreateCompanionBuilder,
          $$TodosTableUpdateCompanionBuilder,
          (Todo, $$TodosTableReferences),
          Todo,
          PrefetchHooks Function({bool subtasksRefs})
        > {
  $$TodosTableTableManager(_$AppDatabase db, $TodosTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TodosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TodosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TodosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> category = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<DateTime?> dueDate = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<bool> notificationEnabled = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion(
                id: id,
                title: title,
                category: category,
                priority: priority,
                dueDate: dueDate,
                isDone: isDone,
                notificationEnabled: notificationEnabled,
                alarmEnabled: alarmEnabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String title,
                required String category,
                required String priority,
                Value<DateTime?> dueDate = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
                Value<bool> notificationEnabled = const Value.absent(),
                Value<bool> alarmEnabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TodosCompanion.insert(
                id: id,
                title: title,
                category: category,
                priority: priority,
                dueDate: dueDate,
                isDone: isDone,
                notificationEnabled: notificationEnabled,
                alarmEnabled: alarmEnabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TodosTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({subtasksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (subtasksRefs) db.subtasks],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (subtasksRefs)
                    await $_getPrefetchedData<Todo, $TodosTable, Subtask>(
                      currentTable: table,
                      referencedTable: $$TodosTableReferences
                          ._subtasksRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TodosTableReferences(db, table, p0).subtasksRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.todoId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TodosTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TodosTable,
      Todo,
      $$TodosTableFilterComposer,
      $$TodosTableOrderingComposer,
      $$TodosTableAnnotationComposer,
      $$TodosTableCreateCompanionBuilder,
      $$TodosTableUpdateCompanionBuilder,
      (Todo, $$TodosTableReferences),
      Todo,
      PrefetchHooks Function({bool subtasksRefs})
    >;
typedef $$SubtasksTableCreateCompanionBuilder =
    SubtasksCompanion Function({
      Value<int> id,
      required String todoId,
      required String title,
      Value<bool> isDone,
    });
typedef $$SubtasksTableUpdateCompanionBuilder =
    SubtasksCompanion Function({
      Value<int> id,
      Value<String> todoId,
      Value<String> title,
      Value<bool> isDone,
    });

final class $$SubtasksTableReferences
    extends BaseReferences<_$AppDatabase, $SubtasksTable, Subtask> {
  $$SubtasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TodosTable _todoIdTable(_$AppDatabase db) => db.todos.createAlias(
    $_aliasNameGenerator(db.subtasks.todoId, db.todos.id),
  );

  $$TodosTableProcessedTableManager get todoId {
    final $_column = $_itemColumn<String>('todo_id')!;

    final manager = $$TodosTableTableManager(
      $_db,
      $_db.todos,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_todoIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$SubtasksTableFilterComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnFilters(column),
  );

  $$TodosTableFilterComposer get todoId {
    final $$TodosTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableFilterComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableOrderingComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDone => $composableBuilder(
    column: $table.isDone,
    builder: (column) => ColumnOrderings(column),
  );

  $$TodosTableOrderingComposer get todoId {
    final $$TodosTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableOrderingComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $SubtasksTable> {
  $$SubtasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<bool> get isDone =>
      $composableBuilder(column: $table.isDone, builder: (column) => column);

  $$TodosTableAnnotationComposer get todoId {
    final $$TodosTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.todoId,
      referencedTable: $db.todos,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TodosTableAnnotationComposer(
            $db: $db,
            $table: $db.todos,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SubtasksTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SubtasksTable,
          Subtask,
          $$SubtasksTableFilterComposer,
          $$SubtasksTableOrderingComposer,
          $$SubtasksTableAnnotationComposer,
          $$SubtasksTableCreateCompanionBuilder,
          $$SubtasksTableUpdateCompanionBuilder,
          (Subtask, $$SubtasksTableReferences),
          Subtask,
          PrefetchHooks Function({bool todoId})
        > {
  $$SubtasksTableTableManager(_$AppDatabase db, $SubtasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SubtasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SubtasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SubtasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> todoId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<bool> isDone = const Value.absent(),
              }) => SubtasksCompanion(
                id: id,
                todoId: todoId,
                title: title,
                isDone: isDone,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String todoId,
                required String title,
                Value<bool> isDone = const Value.absent(),
              }) => SubtasksCompanion.insert(
                id: id,
                todoId: todoId,
                title: title,
                isDone: isDone,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SubtasksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({todoId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (todoId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.todoId,
                                referencedTable: $$SubtasksTableReferences
                                    ._todoIdTable(db),
                                referencedColumn: $$SubtasksTableReferences
                                    ._todoIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$SubtasksTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SubtasksTable,
      Subtask,
      $$SubtasksTableFilterComposer,
      $$SubtasksTableOrderingComposer,
      $$SubtasksTableAnnotationComposer,
      $$SubtasksTableCreateCompanionBuilder,
      $$SubtasksTableUpdateCompanionBuilder,
      (Subtask, $$SubtasksTableReferences),
      Subtask,
      PrefetchHooks Function({bool todoId})
    >;
typedef $$ExtensionsTableCreateCompanionBuilder =
    ExtensionsCompanion Function({
      required String id,
      required String type,
      required String name,
      required String version,
      required String icon,
      Value<String> description,
      Value<String?> dataFile,
      Value<String?> codeFile,
      Value<String> recordFieldsJson,
      Value<String> filesJson,
      Value<int> rowid,
    });
typedef $$ExtensionsTableUpdateCompanionBuilder =
    ExtensionsCompanion Function({
      Value<String> id,
      Value<String> type,
      Value<String> name,
      Value<String> version,
      Value<String> icon,
      Value<String> description,
      Value<String?> dataFile,
      Value<String?> codeFile,
      Value<String> recordFieldsJson,
      Value<String> filesJson,
      Value<int> rowid,
    });

class $$ExtensionsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtensionsTable> {
  $$ExtensionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataFile => $composableBuilder(
    column: $table.dataFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codeFile => $composableBuilder(
    column: $table.codeFile,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordFieldsJson => $composableBuilder(
    column: $table.recordFieldsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filesJson => $composableBuilder(
    column: $table.filesJson,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtensionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtensionsTable> {
  $$ExtensionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get icon => $composableBuilder(
    column: $table.icon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataFile => $composableBuilder(
    column: $table.dataFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codeFile => $composableBuilder(
    column: $table.codeFile,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordFieldsJson => $composableBuilder(
    column: $table.recordFieldsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filesJson => $composableBuilder(
    column: $table.filesJson,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtensionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtensionsTable> {
  $$ExtensionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get icon =>
      $composableBuilder(column: $table.icon, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataFile =>
      $composableBuilder(column: $table.dataFile, builder: (column) => column);

  GeneratedColumn<String> get codeFile =>
      $composableBuilder(column: $table.codeFile, builder: (column) => column);

  GeneratedColumn<String> get recordFieldsJson => $composableBuilder(
    column: $table.recordFieldsJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filesJson =>
      $composableBuilder(column: $table.filesJson, builder: (column) => column);
}

class $$ExtensionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtensionsTable,
          Extension,
          $$ExtensionsTableFilterComposer,
          $$ExtensionsTableOrderingComposer,
          $$ExtensionsTableAnnotationComposer,
          $$ExtensionsTableCreateCompanionBuilder,
          $$ExtensionsTableUpdateCompanionBuilder,
          (
            Extension,
            BaseReferences<_$AppDatabase, $ExtensionsTable, Extension>,
          ),
          Extension,
          PrefetchHooks Function()
        > {
  $$ExtensionsTableTableManager(_$AppDatabase db, $ExtensionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtensionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtensionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtensionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> version = const Value.absent(),
                Value<String> icon = const Value.absent(),
                Value<String> description = const Value.absent(),
                Value<String?> dataFile = const Value.absent(),
                Value<String?> codeFile = const Value.absent(),
                Value<String> recordFieldsJson = const Value.absent(),
                Value<String> filesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtensionsCompanion(
                id: id,
                type: type,
                name: name,
                version: version,
                icon: icon,
                description: description,
                dataFile: dataFile,
                codeFile: codeFile,
                recordFieldsJson: recordFieldsJson,
                filesJson: filesJson,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String type,
                required String name,
                required String version,
                required String icon,
                Value<String> description = const Value.absent(),
                Value<String?> dataFile = const Value.absent(),
                Value<String?> codeFile = const Value.absent(),
                Value<String> recordFieldsJson = const Value.absent(),
                Value<String> filesJson = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ExtensionsCompanion.insert(
                id: id,
                type: type,
                name: name,
                version: version,
                icon: icon,
                description: description,
                dataFile: dataFile,
                codeFile: codeFile,
                recordFieldsJson: recordFieldsJson,
                filesJson: filesJson,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExtensionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtensionsTable,
      Extension,
      $$ExtensionsTableFilterComposer,
      $$ExtensionsTableOrderingComposer,
      $$ExtensionsTableAnnotationComposer,
      $$ExtensionsTableCreateCompanionBuilder,
      $$ExtensionsTableUpdateCompanionBuilder,
      (Extension, BaseReferences<_$AppDatabase, $ExtensionsTable, Extension>),
      Extension,
      PrefetchHooks Function()
    >;
typedef $$ExtensionRecordsTableCreateCompanionBuilder =
    ExtensionRecordsCompanion Function({
      Value<int> id,
      required String extensionType,
      required String payload,
      Value<DateTime> createdAt,
    });
typedef $$ExtensionRecordsTableUpdateCompanionBuilder =
    ExtensionRecordsCompanion Function({
      Value<int> id,
      Value<String> extensionType,
      Value<String> payload,
      Value<DateTime> createdAt,
    });

class $$ExtensionRecordsTableFilterComposer
    extends Composer<_$AppDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extensionType => $composableBuilder(
    column: $table.extensionType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ExtensionRecordsTableOrderingComposer
    extends Composer<_$AppDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extensionType => $composableBuilder(
    column: $table.extensionType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ExtensionRecordsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ExtensionRecordsTable> {
  $$ExtensionRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get extensionType => $composableBuilder(
    column: $table.extensionType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ExtensionRecordsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ExtensionRecordsTable,
          ExtensionRecord,
          $$ExtensionRecordsTableFilterComposer,
          $$ExtensionRecordsTableOrderingComposer,
          $$ExtensionRecordsTableAnnotationComposer,
          $$ExtensionRecordsTableCreateCompanionBuilder,
          $$ExtensionRecordsTableUpdateCompanionBuilder,
          (
            ExtensionRecord,
            BaseReferences<
              _$AppDatabase,
              $ExtensionRecordsTable,
              ExtensionRecord
            >,
          ),
          ExtensionRecord,
          PrefetchHooks Function()
        > {
  $$ExtensionRecordsTableTableManager(
    _$AppDatabase db,
    $ExtensionRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ExtensionRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ExtensionRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ExtensionRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> extensionType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExtensionRecordsCompanion(
                id: id,
                extensionType: extensionType,
                payload: payload,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String extensionType,
                required String payload,
                Value<DateTime> createdAt = const Value.absent(),
              }) => ExtensionRecordsCompanion.insert(
                id: id,
                extensionType: extensionType,
                payload: payload,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ExtensionRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ExtensionRecordsTable,
      ExtensionRecord,
      $$ExtensionRecordsTableFilterComposer,
      $$ExtensionRecordsTableOrderingComposer,
      $$ExtensionRecordsTableAnnotationComposer,
      $$ExtensionRecordsTableCreateCompanionBuilder,
      $$ExtensionRecordsTableUpdateCompanionBuilder,
      (
        ExtensionRecord,
        BaseReferences<_$AppDatabase, $ExtensionRecordsTable, ExtensionRecord>,
      ),
      ExtensionRecord,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TodosTableTableManager get todos =>
      $$TodosTableTableManager(_db, _db.todos);
  $$SubtasksTableTableManager get subtasks =>
      $$SubtasksTableTableManager(_db, _db.subtasks);
  $$ExtensionsTableTableManager get extensions =>
      $$ExtensionsTableTableManager(_db, _db.extensions);
  $$ExtensionRecordsTableTableManager get extensionRecords =>
      $$ExtensionRecordsTableTableManager(_db, _db.extensionRecords);
}
