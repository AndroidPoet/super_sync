// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SyncRecordsTable extends SyncRecords
    with TableInfo<$SyncRecordsTable, SyncRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localVersionMeta = const VerificationMeta(
    'localVersion',
  );
  @override
  late final GeneratedColumn<int> localVersion = GeneratedColumn<int>(
    'local_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverVersionMeta = const VerificationMeta(
    'serverVersion',
  );
  @override
  late final GeneratedColumn<int> serverVersion = GeneratedColumn<int>(
    'server_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    type,
    id,
    dataJson,
    localVersion,
    serverVersion,
    deleted,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('local_version')) {
      context.handle(
        _localVersionMeta,
        localVersion.isAcceptableOrUnknown(
          data['local_version']!,
          _localVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localVersionMeta);
    }
    if (data.containsKey('server_version')) {
      context.handle(
        _serverVersionMeta,
        serverVersion.isAcceptableOrUnknown(
          data['server_version']!,
          _serverVersionMeta,
        ),
      );
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {type, id};
  @override
  SyncRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncRecordRow(
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      localVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}local_version'],
      )!,
      serverVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}server_version'],
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncRecordsTable createAlias(String alias) {
    return $SyncRecordsTable(attachedDatabase, alias);
  }
}

class SyncRecordRow extends DataClass implements Insertable<SyncRecordRow> {
  final String type;
  final String id;
  final String dataJson;
  final int localVersion;
  final int? serverVersion;
  final bool deleted;
  final int updatedAt;
  const SyncRecordRow({
    required this.type,
    required this.id,
    required this.dataJson,
    required this.localVersion,
    this.serverVersion,
    required this.deleted,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['type'] = Variable<String>(type);
    map['id'] = Variable<String>(id);
    map['data_json'] = Variable<String>(dataJson);
    map['local_version'] = Variable<int>(localVersion);
    if (!nullToAbsent || serverVersion != null) {
      map['server_version'] = Variable<int>(serverVersion);
    }
    map['deleted'] = Variable<bool>(deleted);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SyncRecordsCompanion toCompanion(bool nullToAbsent) {
    return SyncRecordsCompanion(
      type: Value(type),
      id: Value(id),
      dataJson: Value(dataJson),
      localVersion: Value(localVersion),
      serverVersion: serverVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(serverVersion),
      deleted: Value(deleted),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncRecordRow(
      type: serializer.fromJson<String>(json['type']),
      id: serializer.fromJson<String>(json['id']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      localVersion: serializer.fromJson<int>(json['localVersion']),
      serverVersion: serializer.fromJson<int?>(json['serverVersion']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'type': serializer.toJson<String>(type),
      'id': serializer.toJson<String>(id),
      'dataJson': serializer.toJson<String>(dataJson),
      'localVersion': serializer.toJson<int>(localVersion),
      'serverVersion': serializer.toJson<int?>(serverVersion),
      'deleted': serializer.toJson<bool>(deleted),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SyncRecordRow copyWith({
    String? type,
    String? id,
    String? dataJson,
    int? localVersion,
    Value<int?> serverVersion = const Value.absent(),
    bool? deleted,
    int? updatedAt,
  }) => SyncRecordRow(
    type: type ?? this.type,
    id: id ?? this.id,
    dataJson: dataJson ?? this.dataJson,
    localVersion: localVersion ?? this.localVersion,
    serverVersion: serverVersion.present
        ? serverVersion.value
        : this.serverVersion,
    deleted: deleted ?? this.deleted,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncRecordRow copyWithCompanion(SyncRecordsCompanion data) {
    return SyncRecordRow(
      type: data.type.present ? data.type.value : this.type,
      id: data.id.present ? data.id.value : this.id,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      localVersion: data.localVersion.present
          ? data.localVersion.value
          : this.localVersion,
      serverVersion: data.serverVersion.present
          ? data.serverVersion.value
          : this.serverVersion,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordRow(')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson, ')
          ..write('localVersion: $localVersion, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    type,
    id,
    dataJson,
    localVersion,
    serverVersion,
    deleted,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncRecordRow &&
          other.type == this.type &&
          other.id == this.id &&
          other.dataJson == this.dataJson &&
          other.localVersion == this.localVersion &&
          other.serverVersion == this.serverVersion &&
          other.deleted == this.deleted &&
          other.updatedAt == this.updatedAt);
}

class SyncRecordsCompanion extends UpdateCompanion<SyncRecordRow> {
  final Value<String> type;
  final Value<String> id;
  final Value<String> dataJson;
  final Value<int> localVersion;
  final Value<int?> serverVersion;
  final Value<bool> deleted;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SyncRecordsCompanion({
    this.type = const Value.absent(),
    this.id = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.localVersion = const Value.absent(),
    this.serverVersion = const Value.absent(),
    this.deleted = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncRecordsCompanion.insert({
    required String type,
    required String id,
    required String dataJson,
    required int localVersion,
    this.serverVersion = const Value.absent(),
    this.deleted = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : type = Value(type),
       id = Value(id),
       dataJson = Value(dataJson),
       localVersion = Value(localVersion),
       updatedAt = Value(updatedAt);
  static Insertable<SyncRecordRow> custom({
    Expression<String>? type,
    Expression<String>? id,
    Expression<String>? dataJson,
    Expression<int>? localVersion,
    Expression<int>? serverVersion,
    Expression<bool>? deleted,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (type != null) 'type': type,
      if (id != null) 'id': id,
      if (dataJson != null) 'data_json': dataJson,
      if (localVersion != null) 'local_version': localVersion,
      if (serverVersion != null) 'server_version': serverVersion,
      if (deleted != null) 'deleted': deleted,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncRecordsCompanion copyWith({
    Value<String>? type,
    Value<String>? id,
    Value<String>? dataJson,
    Value<int>? localVersion,
    Value<int?>? serverVersion,
    Value<bool>? deleted,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncRecordsCompanion(
      type: type ?? this.type,
      id: id ?? this.id,
      dataJson: dataJson ?? this.dataJson,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      deleted: deleted ?? this.deleted,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (localVersion.present) {
      map['local_version'] = Variable<int>(localVersion.value);
    }
    if (serverVersion.present) {
      map['server_version'] = Variable<int>(serverVersion.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncRecordsCompanion(')
          ..write('type: $type, ')
          ..write('id: $id, ')
          ..write('dataJson: $dataJson, ')
          ..write('localVersion: $localVersion, ')
          ..write('serverVersion: $serverVersion, ')
          ..write('deleted: $deleted, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncMutationsTable extends SyncMutations
    with TableInfo<$SyncMutationsTable, SyncMutationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncMutationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idempotencyKeyMeta = const VerificationMeta(
    'idempotencyKey',
  );
  @override
  late final GeneratedColumn<String> idempotencyKey = GeneratedColumn<String>(
    'idempotency_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<int> operation = GeneratedColumn<int>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _baseVersionMeta = const VerificationMeta(
    'baseVersion',
  );
  @override
  late final GeneratedColumn<int> baseVersion = GeneratedColumn<int>(
    'base_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _retryCountMeta = const VerificationMeta(
    'retryCount',
  );
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
    'retry_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextRetryAtMeta = const VerificationMeta(
    'nextRetryAt',
  );
  @override
  late final GeneratedColumn<int> nextRetryAt = GeneratedColumn<int>(
    'next_retry_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    idempotencyKey,
    entityType,
    entityId,
    operation,
    payloadJson,
    baseVersion,
    retryCount,
    nextRetryAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_mutations';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncMutationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('idempotency_key')) {
      context.handle(
        _idempotencyKeyMeta,
        idempotencyKey.isAcceptableOrUnknown(
          data['idempotency_key']!,
          _idempotencyKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_idempotencyKeyMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('base_version')) {
      context.handle(
        _baseVersionMeta,
        baseVersion.isAcceptableOrUnknown(
          data['base_version']!,
          _baseVersionMeta,
        ),
      );
    }
    if (data.containsKey('retry_count')) {
      context.handle(
        _retryCountMeta,
        retryCount.isAcceptableOrUnknown(data['retry_count']!, _retryCountMeta),
      );
    }
    if (data.containsKey('next_retry_at')) {
      context.handle(
        _nextRetryAtMeta,
        nextRetryAt.isAcceptableOrUnknown(
          data['next_retry_at']!,
          _nextRetryAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncMutationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncMutationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      idempotencyKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}idempotency_key'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}operation'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      baseVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}base_version'],
      ),
      retryCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}retry_count'],
      )!,
      nextRetryAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_retry_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SyncMutationsTable createAlias(String alias) {
    return $SyncMutationsTable(attachedDatabase, alias);
  }
}

class SyncMutationRow extends DataClass implements Insertable<SyncMutationRow> {
  final String id;
  final String idempotencyKey;
  final String entityType;
  final String entityId;
  final int operation;
  final String payloadJson;
  final int? baseVersion;
  final int retryCount;
  final int? nextRetryAt;
  final int createdAt;
  const SyncMutationRow({
    required this.id,
    required this.idempotencyKey,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    this.baseVersion,
    required this.retryCount,
    this.nextRetryAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['idempotency_key'] = Variable<String>(idempotencyKey);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<String>(entityId);
    map['operation'] = Variable<int>(operation);
    map['payload_json'] = Variable<String>(payloadJson);
    if (!nullToAbsent || baseVersion != null) {
      map['base_version'] = Variable<int>(baseVersion);
    }
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || nextRetryAt != null) {
      map['next_retry_at'] = Variable<int>(nextRetryAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  SyncMutationsCompanion toCompanion(bool nullToAbsent) {
    return SyncMutationsCompanion(
      id: Value(id),
      idempotencyKey: Value(idempotencyKey),
      entityType: Value(entityType),
      entityId: Value(entityId),
      operation: Value(operation),
      payloadJson: Value(payloadJson),
      baseVersion: baseVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(baseVersion),
      retryCount: Value(retryCount),
      nextRetryAt: nextRetryAt == null && nullToAbsent
          ? const Value.absent()
          : Value(nextRetryAt),
      createdAt: Value(createdAt),
    );
  }

  factory SyncMutationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncMutationRow(
      id: serializer.fromJson<String>(json['id']),
      idempotencyKey: serializer.fromJson<String>(json['idempotencyKey']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<String>(json['entityId']),
      operation: serializer.fromJson<int>(json['operation']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      baseVersion: serializer.fromJson<int?>(json['baseVersion']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      nextRetryAt: serializer.fromJson<int?>(json['nextRetryAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'idempotencyKey': serializer.toJson<String>(idempotencyKey),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<String>(entityId),
      'operation': serializer.toJson<int>(operation),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'baseVersion': serializer.toJson<int?>(baseVersion),
      'retryCount': serializer.toJson<int>(retryCount),
      'nextRetryAt': serializer.toJson<int?>(nextRetryAt),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  SyncMutationRow copyWith({
    String? id,
    String? idempotencyKey,
    String? entityType,
    String? entityId,
    int? operation,
    String? payloadJson,
    Value<int?> baseVersion = const Value.absent(),
    int? retryCount,
    Value<int?> nextRetryAt = const Value.absent(),
    int? createdAt,
  }) => SyncMutationRow(
    id: id ?? this.id,
    idempotencyKey: idempotencyKey ?? this.idempotencyKey,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    operation: operation ?? this.operation,
    payloadJson: payloadJson ?? this.payloadJson,
    baseVersion: baseVersion.present ? baseVersion.value : this.baseVersion,
    retryCount: retryCount ?? this.retryCount,
    nextRetryAt: nextRetryAt.present ? nextRetryAt.value : this.nextRetryAt,
    createdAt: createdAt ?? this.createdAt,
  );
  SyncMutationRow copyWithCompanion(SyncMutationsCompanion data) {
    return SyncMutationRow(
      id: data.id.present ? data.id.value : this.id,
      idempotencyKey: data.idempotencyKey.present
          ? data.idempotencyKey.value
          : this.idempotencyKey,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      operation: data.operation.present ? data.operation.value : this.operation,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      baseVersion: data.baseVersion.present
          ? data.baseVersion.value
          : this.baseVersion,
      retryCount: data.retryCount.present
          ? data.retryCount.value
          : this.retryCount,
      nextRetryAt: data.nextRetryAt.present
          ? data.nextRetryAt.value
          : this.nextRetryAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncMutationRow(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    idempotencyKey,
    entityType,
    entityId,
    operation,
    payloadJson,
    baseVersion,
    retryCount,
    nextRetryAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncMutationRow &&
          other.id == this.id &&
          other.idempotencyKey == this.idempotencyKey &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.operation == this.operation &&
          other.payloadJson == this.payloadJson &&
          other.baseVersion == this.baseVersion &&
          other.retryCount == this.retryCount &&
          other.nextRetryAt == this.nextRetryAt &&
          other.createdAt == this.createdAt);
}

class SyncMutationsCompanion extends UpdateCompanion<SyncMutationRow> {
  final Value<String> id;
  final Value<String> idempotencyKey;
  final Value<String> entityType;
  final Value<String> entityId;
  final Value<int> operation;
  final Value<String> payloadJson;
  final Value<int?> baseVersion;
  final Value<int> retryCount;
  final Value<int?> nextRetryAt;
  final Value<int> createdAt;
  final Value<int> rowid;
  const SyncMutationsCompanion({
    this.id = const Value.absent(),
    this.idempotencyKey = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.operation = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.baseVersion = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncMutationsCompanion.insert({
    required String id,
    required String idempotencyKey,
    required String entityType,
    required String entityId,
    required int operation,
    required String payloadJson,
    this.baseVersion = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.nextRetryAt = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       idempotencyKey = Value(idempotencyKey),
       entityType = Value(entityType),
       entityId = Value(entityId),
       operation = Value(operation),
       payloadJson = Value(payloadJson),
       createdAt = Value(createdAt);
  static Insertable<SyncMutationRow> custom({
    Expression<String>? id,
    Expression<String>? idempotencyKey,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? operation,
    Expression<String>? payloadJson,
    Expression<int>? baseVersion,
    Expression<int>? retryCount,
    Expression<int>? nextRetryAt,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (idempotencyKey != null) 'idempotency_key': idempotencyKey,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (operation != null) 'operation': operation,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (baseVersion != null) 'base_version': baseVersion,
      if (retryCount != null) 'retry_count': retryCount,
      if (nextRetryAt != null) 'next_retry_at': nextRetryAt,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncMutationsCompanion copyWith({
    Value<String>? id,
    Value<String>? idempotencyKey,
    Value<String>? entityType,
    Value<String>? entityId,
    Value<int>? operation,
    Value<String>? payloadJson,
    Value<int?>? baseVersion,
    Value<int>? retryCount,
    Value<int?>? nextRetryAt,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return SyncMutationsCompanion(
      id: id ?? this.id,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      operation: operation ?? this.operation,
      payloadJson: payloadJson ?? this.payloadJson,
      baseVersion: baseVersion ?? this.baseVersion,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (idempotencyKey.present) {
      map['idempotency_key'] = Variable<String>(idempotencyKey.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<int>(operation.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (baseVersion.present) {
      map['base_version'] = Variable<int>(baseVersion.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (nextRetryAt.present) {
      map['next_retry_at'] = Variable<int>(nextRetryAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncMutationsCompanion(')
          ..write('id: $id, ')
          ..write('idempotencyKey: $idempotencyKey, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('operation: $operation, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('baseVersion: $baseVersion, ')
          ..write('retryCount: $retryCount, ')
          ..write('nextRetryAt: $nextRetryAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      ),
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  final String key;
  final String? value;
  const SyncCursorRow({required this.key, this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<String>(value);
    }
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      key: Value(key),
      value: value == null && nullToAbsent
          ? const Value.absent()
          : Value(value),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String?>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String?>(value),
    };
  }

  SyncCursorRow copyWith({
    String? key,
    Value<String?> value = const Value.absent(),
  }) => SyncCursorRow(
    key: key ?? this.key,
    value: value.present ? value.value : this.value,
  );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> key;
  final Value<String?> value;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String key,
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? key,
    Value<String?>? value,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$SuperSyncDatabase extends GeneratedDatabase {
  _$SuperSyncDatabase(QueryExecutor e) : super(e);
  $SuperSyncDatabaseManager get managers => $SuperSyncDatabaseManager(this);
  late final $SyncRecordsTable syncRecords = $SyncRecordsTable(this);
  late final $SyncMutationsTable syncMutations = $SyncMutationsTable(this);
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final Index idxRecordsType = Index(
    'idx_records_type',
    'CREATE INDEX idx_records_type ON sync_records (type)',
  );
  late final Index idxMutationsEntity = Index(
    'idx_mutations_entity',
    'CREATE INDEX idx_mutations_entity ON sync_mutations (entity_type, entity_id)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    syncRecords,
    syncMutations,
    syncCursors,
    idxRecordsType,
    idxMutationsEntity,
  ];
}

typedef $$SyncRecordsTableCreateCompanionBuilder =
    SyncRecordsCompanion Function({
      required String type,
      required String id,
      required String dataJson,
      required int localVersion,
      Value<int?> serverVersion,
      Value<bool> deleted,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SyncRecordsTableUpdateCompanionBuilder =
    SyncRecordsCompanion Function({
      Value<String> type,
      Value<String> id,
      Value<String> dataJson,
      Value<int> localVersion,
      Value<int?> serverVersion,
      Value<bool> deleted,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SyncRecordsTableFilterComposer
    extends Composer<_$SuperSyncDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncRecordsTableOrderingComposer
    extends Composer<_$SuperSyncDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncRecordsTableAnnotationComposer
    extends Composer<_$SuperSyncDatabase, $SyncRecordsTable> {
  $$SyncRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<int> get localVersion => $composableBuilder(
    column: $table.localVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get serverVersion => $composableBuilder(
    column: $table.serverVersion,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncRecordsTableTableManager
    extends
        RootTableManager<
          _$SuperSyncDatabase,
          $SyncRecordsTable,
          SyncRecordRow,
          $$SyncRecordsTableFilterComposer,
          $$SyncRecordsTableOrderingComposer,
          $$SyncRecordsTableAnnotationComposer,
          $$SyncRecordsTableCreateCompanionBuilder,
          $$SyncRecordsTableUpdateCompanionBuilder,
          (
            SyncRecordRow,
            BaseReferences<
              _$SuperSyncDatabase,
              $SyncRecordsTable,
              SyncRecordRow
            >,
          ),
          SyncRecordRow,
          PrefetchHooks Function()
        > {
  $$SyncRecordsTableTableManager(
    _$SuperSyncDatabase db,
    $SyncRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> type = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int> localVersion = const Value.absent(),
                Value<int?> serverVersion = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion(
                type: type,
                id: id,
                dataJson: dataJson,
                localVersion: localVersion,
                serverVersion: serverVersion,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String type,
                required String id,
                required String dataJson,
                required int localVersion,
                Value<int?> serverVersion = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncRecordsCompanion.insert(
                type: type,
                id: id,
                dataJson: dataJson,
                localVersion: localVersion,
                serverVersion: serverVersion,
                deleted: deleted,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$SuperSyncDatabase,
      $SyncRecordsTable,
      SyncRecordRow,
      $$SyncRecordsTableFilterComposer,
      $$SyncRecordsTableOrderingComposer,
      $$SyncRecordsTableAnnotationComposer,
      $$SyncRecordsTableCreateCompanionBuilder,
      $$SyncRecordsTableUpdateCompanionBuilder,
      (
        SyncRecordRow,
        BaseReferences<_$SuperSyncDatabase, $SyncRecordsTable, SyncRecordRow>,
      ),
      SyncRecordRow,
      PrefetchHooks Function()
    >;
typedef $$SyncMutationsTableCreateCompanionBuilder =
    SyncMutationsCompanion Function({
      required String id,
      required String idempotencyKey,
      required String entityType,
      required String entityId,
      required int operation,
      required String payloadJson,
      Value<int?> baseVersion,
      Value<int> retryCount,
      Value<int?> nextRetryAt,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$SyncMutationsTableUpdateCompanionBuilder =
    SyncMutationsCompanion Function({
      Value<String> id,
      Value<String> idempotencyKey,
      Value<String> entityType,
      Value<String> entityId,
      Value<int> operation,
      Value<String> payloadJson,
      Value<int?> baseVersion,
      Value<int> retryCount,
      Value<int?> nextRetryAt,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$SyncMutationsTableFilterComposer
    extends Composer<_$SuperSyncDatabase, $SyncMutationsTable> {
  $$SyncMutationsTableFilterComposer({
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

  ColumnFilters<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncMutationsTableOrderingComposer
    extends Composer<_$SuperSyncDatabase, $SyncMutationsTable> {
  $$SyncMutationsTableOrderingComposer({
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

  ColumnOrderings<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncMutationsTableAnnotationComposer
    extends Composer<_$SuperSyncDatabase, $SyncMutationsTable> {
  $$SyncMutationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get idempotencyKey => $composableBuilder(
    column: $table.idempotencyKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get baseVersion => $composableBuilder(
    column: $table.baseVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get retryCount => $composableBuilder(
    column: $table.retryCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextRetryAt => $composableBuilder(
    column: $table.nextRetryAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SyncMutationsTableTableManager
    extends
        RootTableManager<
          _$SuperSyncDatabase,
          $SyncMutationsTable,
          SyncMutationRow,
          $$SyncMutationsTableFilterComposer,
          $$SyncMutationsTableOrderingComposer,
          $$SyncMutationsTableAnnotationComposer,
          $$SyncMutationsTableCreateCompanionBuilder,
          $$SyncMutationsTableUpdateCompanionBuilder,
          (
            SyncMutationRow,
            BaseReferences<
              _$SuperSyncDatabase,
              $SyncMutationsTable,
              SyncMutationRow
            >,
          ),
          SyncMutationRow,
          PrefetchHooks Function()
        > {
  $$SyncMutationsTableTableManager(
    _$SuperSyncDatabase db,
    $SyncMutationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncMutationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncMutationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncMutationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> idempotencyKey = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> operation = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int?> baseVersion = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncMutationsCompanion(
                id: id,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                baseVersion: baseVersion,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String idempotencyKey,
                required String entityType,
                required String entityId,
                required int operation,
                required String payloadJson,
                Value<int?> baseVersion = const Value.absent(),
                Value<int> retryCount = const Value.absent(),
                Value<int?> nextRetryAt = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncMutationsCompanion.insert(
                id: id,
                idempotencyKey: idempotencyKey,
                entityType: entityType,
                entityId: entityId,
                operation: operation,
                payloadJson: payloadJson,
                baseVersion: baseVersion,
                retryCount: retryCount,
                nextRetryAt: nextRetryAt,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncMutationsTableProcessedTableManager =
    ProcessedTableManager<
      _$SuperSyncDatabase,
      $SyncMutationsTable,
      SyncMutationRow,
      $$SyncMutationsTableFilterComposer,
      $$SyncMutationsTableOrderingComposer,
      $$SyncMutationsTableAnnotationComposer,
      $$SyncMutationsTableCreateCompanionBuilder,
      $$SyncMutationsTableUpdateCompanionBuilder,
      (
        SyncMutationRow,
        BaseReferences<
          _$SuperSyncDatabase,
          $SyncMutationsTable,
          SyncMutationRow
        >,
      ),
      SyncMutationRow,
      PrefetchHooks Function()
    >;
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String key,
      Value<String?> value,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> key,
      Value<String?> value,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$SuperSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$SuperSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$SuperSyncDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$SuperSyncDatabase,
          $SyncCursorsTable,
          SyncCursorRow,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<
              _$SuperSyncDatabase,
              $SyncCursorsTable,
              SyncCursorRow
            >,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(
    _$SuperSyncDatabase db,
    $SyncCursorsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                Value<String?> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$SuperSyncDatabase,
      $SyncCursorsTable,
      SyncCursorRow,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$SuperSyncDatabase, $SyncCursorsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;

class $SuperSyncDatabaseManager {
  final _$SuperSyncDatabase _db;
  $SuperSyncDatabaseManager(this._db);
  $$SyncRecordsTableTableManager get syncRecords =>
      $$SyncRecordsTableTableManager(_db, _db.syncRecords);
  $$SyncMutationsTableTableManager get syncMutations =>
      $$SyncMutationsTableTableManager(_db, _db.syncMutations);
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
}
