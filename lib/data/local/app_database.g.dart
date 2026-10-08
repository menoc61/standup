// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfilesTableTable extends UserProfilesTable
    with TableInfo<$UserProfilesTableTable, UserProfilesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _designationMeta = const VerificationMeta(
    'designation',
  );
  @override
  late final GeneratedColumn<String> designation = GeneratedColumn<String>(
    'designation',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _departmentMeta = const VerificationMeta(
    'department',
  );
  @override
  late final GeneratedColumn<String> department = GeneratedColumn<String>(
    'department',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _emailMeta = const VerificationMeta('email');
  @override
  late final GeneratedColumn<String> email = GeneratedColumn<String>(
    'email',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('employee'),
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
  List<GeneratedColumn> get $columns => [
    id,
    name,
    designation,
    department,
    email,
    organizationId,
    role,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfilesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('designation')) {
      context.handle(
        _designationMeta,
        designation.isAcceptableOrUnknown(
          data['designation']!,
          _designationMeta,
        ),
      );
    }
    if (data.containsKey('department')) {
      context.handle(
        _departmentMeta,
        department.isAcceptableOrUnknown(data['department']!, _departmentMeta),
      );
    }
    if (data.containsKey('email')) {
      context.handle(
        _emailMeta,
        email.isAcceptableOrUnknown(data['email']!, _emailMeta),
      );
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
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
  UserProfilesTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfilesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      designation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}designation'],
      ),
      department: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}department'],
      ),
      email: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}email'],
      ),
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UserProfilesTableTable createAlias(String alias) {
    return $UserProfilesTableTable(attachedDatabase, alias);
  }
}

class UserProfilesTableData extends DataClass
    implements Insertable<UserProfilesTableData> {
  final String id;
  final String name;
  final String? designation;
  final String? department;
  final String? email;
  final String? organizationId;
  final String role;
  final DateTime createdAt;
  const UserProfilesTableData({
    required this.id,
    required this.name,
    this.designation,
    this.department,
    this.email,
    this.organizationId,
    required this.role,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || designation != null) {
      map['designation'] = Variable<String>(designation);
    }
    if (!nullToAbsent || department != null) {
      map['department'] = Variable<String>(department);
    }
    if (!nullToAbsent || email != null) {
      map['email'] = Variable<String>(email);
    }
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    map['role'] = Variable<String>(role);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UserProfilesTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesTableCompanion(
      id: Value(id),
      name: Value(name),
      designation: designation == null && nullToAbsent
          ? const Value.absent()
          : Value(designation),
      department: department == null && nullToAbsent
          ? const Value.absent()
          : Value(department),
      email: email == null && nullToAbsent
          ? const Value.absent()
          : Value(email),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      role: Value(role),
      createdAt: Value(createdAt),
    );
  }

  factory UserProfilesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfilesTableData(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      designation: serializer.fromJson<String?>(json['designation']),
      department: serializer.fromJson<String?>(json['department']),
      email: serializer.fromJson<String?>(json['email']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      role: serializer.fromJson<String>(json['role']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'designation': serializer.toJson<String?>(designation),
      'department': serializer.toJson<String?>(department),
      'email': serializer.toJson<String?>(email),
      'organizationId': serializer.toJson<String?>(organizationId),
      'role': serializer.toJson<String>(role),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UserProfilesTableData copyWith({
    String? id,
    String? name,
    Value<String?> designation = const Value.absent(),
    Value<String?> department = const Value.absent(),
    Value<String?> email = const Value.absent(),
    Value<String?> organizationId = const Value.absent(),
    String? role,
    DateTime? createdAt,
  }) => UserProfilesTableData(
    id: id ?? this.id,
    name: name ?? this.name,
    designation: designation.present ? designation.value : this.designation,
    department: department.present ? department.value : this.department,
    email: email.present ? email.value : this.email,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    role: role ?? this.role,
    createdAt: createdAt ?? this.createdAt,
  );
  UserProfilesTableData copyWithCompanion(UserProfilesTableCompanion data) {
    return UserProfilesTableData(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      designation: data.designation.present
          ? data.designation.value
          : this.designation,
      department: data.department.present
          ? data.department.value
          : this.department,
      email: data.email.present ? data.email.value : this.email,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      role: data.role.present ? data.role.value : this.role,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesTableData(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('designation: $designation, ')
          ..write('department: $department, ')
          ..write('email: $email, ')
          ..write('organizationId: $organizationId, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    designation,
    department,
    email,
    organizationId,
    role,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfilesTableData &&
          other.id == this.id &&
          other.name == this.name &&
          other.designation == this.designation &&
          other.department == this.department &&
          other.email == this.email &&
          other.organizationId == this.organizationId &&
          other.role == this.role &&
          other.createdAt == this.createdAt);
}

class UserProfilesTableCompanion
    extends UpdateCompanion<UserProfilesTableData> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> designation;
  final Value<String?> department;
  final Value<String?> email;
  final Value<String?> organizationId;
  final Value<String> role;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const UserProfilesTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.designation = const Value.absent(),
    this.department = const Value.absent(),
    this.email = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.role = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserProfilesTableCompanion.insert({
    required String id,
    required String name,
    this.designation = const Value.absent(),
    this.department = const Value.absent(),
    this.email = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.role = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name);
  static Insertable<UserProfilesTableData> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? designation,
    Expression<String>? department,
    Expression<String>? email,
    Expression<String>? organizationId,
    Expression<String>? role,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (designation != null) 'designation': designation,
      if (department != null) 'department': department,
      if (email != null) 'email': email,
      if (organizationId != null) 'organization_id': organizationId,
      if (role != null) 'role': role,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserProfilesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String?>? designation,
    Value<String?>? department,
    Value<String?>? email,
    Value<String?>? organizationId,
    Value<String>? role,
    Value<DateTime>? createdAt,
    Value<int>? rowid,
  }) {
    return UserProfilesTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      organizationId: organizationId ?? this.organizationId,
      role: role ?? this.role,
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
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (designation.present) {
      map['designation'] = Variable<String>(designation.value);
    }
    if (department.present) {
      map['department'] = Variable<String>(department.value);
    }
    if (email.present) {
      map['email'] = Variable<String>(email.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('designation: $designation, ')
          ..write('department: $department, ')
          ..write('email: $email, ')
          ..write('organizationId: $organizationId, ')
          ..write('role: $role, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserPreferencesTableTable extends UserPreferencesTable
    with TableInfo<$UserPreferencesTableTable, UserPreferencesTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserPreferencesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _themeModeMeta = const VerificationMeta(
    'themeMode',
  );
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
    'theme_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('system'),
  );
  static const VerificationMeta _colorSystemMeta = const VerificationMeta(
    'colorSystem',
  );
  @override
  late final GeneratedColumn<String> colorSystem = GeneratedColumn<String>(
    'color_system',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('emerald'),
  );
  static const VerificationMeta _notificationFrequencyMeta =
      const VerificationMeta('notificationFrequency');
  @override
  late final GeneratedColumn<int> notificationFrequency = GeneratedColumn<int>(
    'notification_frequency',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(60),
  );
  static const VerificationMeta _soundEnabledMeta = const VerificationMeta(
    'soundEnabled',
  );
  @override
  late final GeneratedColumn<bool> soundEnabled = GeneratedColumn<bool>(
    'sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sound_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _hapticsEnabledMeta = const VerificationMeta(
    'hapticsEnabled',
  );
  @override
  late final GeneratedColumn<bool> hapticsEnabled = GeneratedColumn<bool>(
    'haptics_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("haptics_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _statisticsOptInMeta = const VerificationMeta(
    'statisticsOptIn',
  );
  @override
  late final GeneratedColumn<bool> statisticsOptIn = GeneratedColumn<bool>(
    'statistics_opt_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("statistics_opt_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _onboardingCompletedMeta =
      const VerificationMeta('onboardingCompleted');
  @override
  late final GeneratedColumn<bool> onboardingCompleted = GeneratedColumn<bool>(
    'onboarding_completed',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_completed" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _selectedSoundMeta = const VerificationMeta(
    'selectedSound',
  );
  @override
  late final GeneratedColumn<String> selectedSound = GeneratedColumn<String>(
    'selected_sound',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('chime'),
  );
  static const VerificationMeta _quietHoursMeta = const VerificationMeta(
    'quietHours',
  );
  @override
  late final GeneratedColumn<String> quietHours = GeneratedColumn<String>(
    'quiet_hours',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _streakGoalMeta = const VerificationMeta(
    'streakGoal',
  );
  @override
  late final GeneratedColumn<int> streakGoal = GeneratedColumn<int>(
    'streak_goal',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(8),
  );
  static const VerificationMeta _actionWindowMinutesMeta =
      const VerificationMeta('actionWindowMinutes');
  @override
  late final GeneratedColumn<int> actionWindowMinutes = GeneratedColumn<int>(
    'action_window_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(5),
  );
  static const VerificationMeta _enforceActionWindowMeta =
      const VerificationMeta('enforceActionWindow');
  @override
  late final GeneratedColumn<bool> enforceActionWindow = GeneratedColumn<bool>(
    'enforce_action_window',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enforce_action_window" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    themeMode,
    colorSystem,
    notificationFrequency,
    soundEnabled,
    hapticsEnabled,
    statisticsOptIn,
    onboardingCompleted,
    selectedSound,
    quietHours,
    streakGoal,
    actionWindowMinutes,
    enforceActionWindow,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_preferences_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserPreferencesTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('theme_mode')) {
      context.handle(
        _themeModeMeta,
        themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta),
      );
    }
    if (data.containsKey('color_system')) {
      context.handle(
        _colorSystemMeta,
        colorSystem.isAcceptableOrUnknown(
          data['color_system']!,
          _colorSystemMeta,
        ),
      );
    }
    if (data.containsKey('notification_frequency')) {
      context.handle(
        _notificationFrequencyMeta,
        notificationFrequency.isAcceptableOrUnknown(
          data['notification_frequency']!,
          _notificationFrequencyMeta,
        ),
      );
    }
    if (data.containsKey('sound_enabled')) {
      context.handle(
        _soundEnabledMeta,
        soundEnabled.isAcceptableOrUnknown(
          data['sound_enabled']!,
          _soundEnabledMeta,
        ),
      );
    }
    if (data.containsKey('haptics_enabled')) {
      context.handle(
        _hapticsEnabledMeta,
        hapticsEnabled.isAcceptableOrUnknown(
          data['haptics_enabled']!,
          _hapticsEnabledMeta,
        ),
      );
    }
    if (data.containsKey('statistics_opt_in')) {
      context.handle(
        _statisticsOptInMeta,
        statisticsOptIn.isAcceptableOrUnknown(
          data['statistics_opt_in']!,
          _statisticsOptInMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_completed')) {
      context.handle(
        _onboardingCompletedMeta,
        onboardingCompleted.isAcceptableOrUnknown(
          data['onboarding_completed']!,
          _onboardingCompletedMeta,
        ),
      );
    }
    if (data.containsKey('selected_sound')) {
      context.handle(
        _selectedSoundMeta,
        selectedSound.isAcceptableOrUnknown(
          data['selected_sound']!,
          _selectedSoundMeta,
        ),
      );
    }
    if (data.containsKey('quiet_hours')) {
      context.handle(
        _quietHoursMeta,
        quietHours.isAcceptableOrUnknown(data['quiet_hours']!, _quietHoursMeta),
      );
    }
    if (data.containsKey('streak_goal')) {
      context.handle(
        _streakGoalMeta,
        streakGoal.isAcceptableOrUnknown(data['streak_goal']!, _streakGoalMeta),
      );
    }
    if (data.containsKey('action_window_minutes')) {
      context.handle(
        _actionWindowMinutesMeta,
        actionWindowMinutes.isAcceptableOrUnknown(
          data['action_window_minutes']!,
          _actionWindowMinutesMeta,
        ),
      );
    }
    if (data.containsKey('enforce_action_window')) {
      context.handle(
        _enforceActionWindowMeta,
        enforceActionWindow.isAcceptableOrUnknown(
          data['enforce_action_window']!,
          _enforceActionWindowMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserPreferencesTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserPreferencesTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      themeMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}theme_mode'],
      )!,
      colorSystem: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_system'],
      )!,
      notificationFrequency: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}notification_frequency'],
      )!,
      soundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sound_enabled'],
      )!,
      hapticsEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}haptics_enabled'],
      )!,
      statisticsOptIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}statistics_opt_in'],
      )!,
      onboardingCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_completed'],
      )!,
      selectedSound: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}selected_sound'],
      )!,
      quietHours: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quiet_hours'],
      ),
      streakGoal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}streak_goal'],
      )!,
      actionWindowMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}action_window_minutes'],
      )!,
      enforceActionWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enforce_action_window'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserPreferencesTableTable createAlias(String alias) {
    return $UserPreferencesTableTable(attachedDatabase, alias);
  }
}

class UserPreferencesTableData extends DataClass
    implements Insertable<UserPreferencesTableData> {
  final String id;
  final String userId;
  final String themeMode;
  final String colorSystem;
  final int notificationFrequency;
  final bool soundEnabled;
  final bool hapticsEnabled;
  final bool statisticsOptIn;
  final bool onboardingCompleted;
  final String selectedSound;
  final String? quietHours;
  final int streakGoal;
  final int actionWindowMinutes;
  final bool enforceActionWindow;
  final DateTime updatedAt;
  const UserPreferencesTableData({
    required this.id,
    required this.userId,
    required this.themeMode,
    required this.colorSystem,
    required this.notificationFrequency,
    required this.soundEnabled,
    required this.hapticsEnabled,
    required this.statisticsOptIn,
    required this.onboardingCompleted,
    required this.selectedSound,
    this.quietHours,
    required this.streakGoal,
    required this.actionWindowMinutes,
    required this.enforceActionWindow,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['theme_mode'] = Variable<String>(themeMode);
    map['color_system'] = Variable<String>(colorSystem);
    map['notification_frequency'] = Variable<int>(notificationFrequency);
    map['sound_enabled'] = Variable<bool>(soundEnabled);
    map['haptics_enabled'] = Variable<bool>(hapticsEnabled);
    map['statistics_opt_in'] = Variable<bool>(statisticsOptIn);
    map['onboarding_completed'] = Variable<bool>(onboardingCompleted);
    map['selected_sound'] = Variable<String>(selectedSound);
    if (!nullToAbsent || quietHours != null) {
      map['quiet_hours'] = Variable<String>(quietHours);
    }
    map['streak_goal'] = Variable<int>(streakGoal);
    map['action_window_minutes'] = Variable<int>(actionWindowMinutes);
    map['enforce_action_window'] = Variable<bool>(enforceActionWindow);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserPreferencesTableCompanion toCompanion(bool nullToAbsent) {
    return UserPreferencesTableCompanion(
      id: Value(id),
      userId: Value(userId),
      themeMode: Value(themeMode),
      colorSystem: Value(colorSystem),
      notificationFrequency: Value(notificationFrequency),
      soundEnabled: Value(soundEnabled),
      hapticsEnabled: Value(hapticsEnabled),
      statisticsOptIn: Value(statisticsOptIn),
      onboardingCompleted: Value(onboardingCompleted),
      selectedSound: Value(selectedSound),
      quietHours: quietHours == null && nullToAbsent
          ? const Value.absent()
          : Value(quietHours),
      streakGoal: Value(streakGoal),
      actionWindowMinutes: Value(actionWindowMinutes),
      enforceActionWindow: Value(enforceActionWindow),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserPreferencesTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserPreferencesTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      colorSystem: serializer.fromJson<String>(json['colorSystem']),
      notificationFrequency: serializer.fromJson<int>(
        json['notificationFrequency'],
      ),
      soundEnabled: serializer.fromJson<bool>(json['soundEnabled']),
      hapticsEnabled: serializer.fromJson<bool>(json['hapticsEnabled']),
      statisticsOptIn: serializer.fromJson<bool>(json['statisticsOptIn']),
      onboardingCompleted: serializer.fromJson<bool>(
        json['onboardingCompleted'],
      ),
      selectedSound: serializer.fromJson<String>(json['selectedSound']),
      quietHours: serializer.fromJson<String?>(json['quietHours']),
      streakGoal: serializer.fromJson<int>(json['streakGoal']),
      actionWindowMinutes: serializer.fromJson<int>(
        json['actionWindowMinutes'],
      ),
      enforceActionWindow: serializer.fromJson<bool>(
        json['enforceActionWindow'],
      ),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'themeMode': serializer.toJson<String>(themeMode),
      'colorSystem': serializer.toJson<String>(colorSystem),
      'notificationFrequency': serializer.toJson<int>(notificationFrequency),
      'soundEnabled': serializer.toJson<bool>(soundEnabled),
      'hapticsEnabled': serializer.toJson<bool>(hapticsEnabled),
      'statisticsOptIn': serializer.toJson<bool>(statisticsOptIn),
      'onboardingCompleted': serializer.toJson<bool>(onboardingCompleted),
      'selectedSound': serializer.toJson<String>(selectedSound),
      'quietHours': serializer.toJson<String?>(quietHours),
      'streakGoal': serializer.toJson<int>(streakGoal),
      'actionWindowMinutes': serializer.toJson<int>(actionWindowMinutes),
      'enforceActionWindow': serializer.toJson<bool>(enforceActionWindow),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserPreferencesTableData copyWith({
    String? id,
    String? userId,
    String? themeMode,
    String? colorSystem,
    int? notificationFrequency,
    bool? soundEnabled,
    bool? hapticsEnabled,
    bool? statisticsOptIn,
    bool? onboardingCompleted,
    String? selectedSound,
    Value<String?> quietHours = const Value.absent(),
    int? streakGoal,
    int? actionWindowMinutes,
    bool? enforceActionWindow,
    DateTime? updatedAt,
  }) => UserPreferencesTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    themeMode: themeMode ?? this.themeMode,
    colorSystem: colorSystem ?? this.colorSystem,
    notificationFrequency: notificationFrequency ?? this.notificationFrequency,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
    statisticsOptIn: statisticsOptIn ?? this.statisticsOptIn,
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    selectedSound: selectedSound ?? this.selectedSound,
    quietHours: quietHours.present ? quietHours.value : this.quietHours,
    streakGoal: streakGoal ?? this.streakGoal,
    actionWindowMinutes: actionWindowMinutes ?? this.actionWindowMinutes,
    enforceActionWindow: enforceActionWindow ?? this.enforceActionWindow,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserPreferencesTableData copyWithCompanion(
    UserPreferencesTableCompanion data,
  ) {
    return UserPreferencesTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      colorSystem: data.colorSystem.present
          ? data.colorSystem.value
          : this.colorSystem,
      notificationFrequency: data.notificationFrequency.present
          ? data.notificationFrequency.value
          : this.notificationFrequency,
      soundEnabled: data.soundEnabled.present
          ? data.soundEnabled.value
          : this.soundEnabled,
      hapticsEnabled: data.hapticsEnabled.present
          ? data.hapticsEnabled.value
          : this.hapticsEnabled,
      statisticsOptIn: data.statisticsOptIn.present
          ? data.statisticsOptIn.value
          : this.statisticsOptIn,
      onboardingCompleted: data.onboardingCompleted.present
          ? data.onboardingCompleted.value
          : this.onboardingCompleted,
      selectedSound: data.selectedSound.present
          ? data.selectedSound.value
          : this.selectedSound,
      quietHours: data.quietHours.present
          ? data.quietHours.value
          : this.quietHours,
      streakGoal: data.streakGoal.present
          ? data.streakGoal.value
          : this.streakGoal,
      actionWindowMinutes: data.actionWindowMinutes.present
          ? data.actionWindowMinutes.value
          : this.actionWindowMinutes,
      enforceActionWindow: data.enforceActionWindow.present
          ? data.enforceActionWindow.value
          : this.enforceActionWindow,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('themeMode: $themeMode, ')
          ..write('colorSystem: $colorSystem, ')
          ..write('notificationFrequency: $notificationFrequency, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('statisticsOptIn: $statisticsOptIn, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('selectedSound: $selectedSound, ')
          ..write('quietHours: $quietHours, ')
          ..write('streakGoal: $streakGoal, ')
          ..write('actionWindowMinutes: $actionWindowMinutes, ')
          ..write('enforceActionWindow: $enforceActionWindow, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    themeMode,
    colorSystem,
    notificationFrequency,
    soundEnabled,
    hapticsEnabled,
    statisticsOptIn,
    onboardingCompleted,
    selectedSound,
    quietHours,
    streakGoal,
    actionWindowMinutes,
    enforceActionWindow,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserPreferencesTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.themeMode == this.themeMode &&
          other.colorSystem == this.colorSystem &&
          other.notificationFrequency == this.notificationFrequency &&
          other.soundEnabled == this.soundEnabled &&
          other.hapticsEnabled == this.hapticsEnabled &&
          other.statisticsOptIn == this.statisticsOptIn &&
          other.onboardingCompleted == this.onboardingCompleted &&
          other.selectedSound == this.selectedSound &&
          other.quietHours == this.quietHours &&
          other.streakGoal == this.streakGoal &&
          other.actionWindowMinutes == this.actionWindowMinutes &&
          other.enforceActionWindow == this.enforceActionWindow &&
          other.updatedAt == this.updatedAt);
}

class UserPreferencesTableCompanion
    extends UpdateCompanion<UserPreferencesTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> themeMode;
  final Value<String> colorSystem;
  final Value<int> notificationFrequency;
  final Value<bool> soundEnabled;
  final Value<bool> hapticsEnabled;
  final Value<bool> statisticsOptIn;
  final Value<bool> onboardingCompleted;
  final Value<String> selectedSound;
  final Value<String?> quietHours;
  final Value<int> streakGoal;
  final Value<int> actionWindowMinutes;
  final Value<bool> enforceActionWindow;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const UserPreferencesTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.colorSystem = const Value.absent(),
    this.notificationFrequency = const Value.absent(),
    this.soundEnabled = const Value.absent(),
    this.hapticsEnabled = const Value.absent(),
    this.statisticsOptIn = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.selectedSound = const Value.absent(),
    this.quietHours = const Value.absent(),
    this.streakGoal = const Value.absent(),
    this.actionWindowMinutes = const Value.absent(),
    this.enforceActionWindow = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UserPreferencesTableCompanion.insert({
    required String id,
    required String userId,
    this.themeMode = const Value.absent(),
    this.colorSystem = const Value.absent(),
    this.notificationFrequency = const Value.absent(),
    this.soundEnabled = const Value.absent(),
    this.hapticsEnabled = const Value.absent(),
    this.statisticsOptIn = const Value.absent(),
    this.onboardingCompleted = const Value.absent(),
    this.selectedSound = const Value.absent(),
    this.quietHours = const Value.absent(),
    this.streakGoal = const Value.absent(),
    this.actionWindowMinutes = const Value.absent(),
    this.enforceActionWindow = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId);
  static Insertable<UserPreferencesTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? themeMode,
    Expression<String>? colorSystem,
    Expression<int>? notificationFrequency,
    Expression<bool>? soundEnabled,
    Expression<bool>? hapticsEnabled,
    Expression<bool>? statisticsOptIn,
    Expression<bool>? onboardingCompleted,
    Expression<String>? selectedSound,
    Expression<String>? quietHours,
    Expression<int>? streakGoal,
    Expression<int>? actionWindowMinutes,
    Expression<bool>? enforceActionWindow,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (themeMode != null) 'theme_mode': themeMode,
      if (colorSystem != null) 'color_system': colorSystem,
      if (notificationFrequency != null)
        'notification_frequency': notificationFrequency,
      if (soundEnabled != null) 'sound_enabled': soundEnabled,
      if (hapticsEnabled != null) 'haptics_enabled': hapticsEnabled,
      if (statisticsOptIn != null) 'statistics_opt_in': statisticsOptIn,
      if (onboardingCompleted != null)
        'onboarding_completed': onboardingCompleted,
      if (selectedSound != null) 'selected_sound': selectedSound,
      if (quietHours != null) 'quiet_hours': quietHours,
      if (streakGoal != null) 'streak_goal': streakGoal,
      if (actionWindowMinutes != null)
        'action_window_minutes': actionWindowMinutes,
      if (enforceActionWindow != null)
        'enforce_action_window': enforceActionWindow,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UserPreferencesTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? themeMode,
    Value<String>? colorSystem,
    Value<int>? notificationFrequency,
    Value<bool>? soundEnabled,
    Value<bool>? hapticsEnabled,
    Value<bool>? statisticsOptIn,
    Value<bool>? onboardingCompleted,
    Value<String>? selectedSound,
    Value<String?>? quietHours,
    Value<int>? streakGoal,
    Value<int>? actionWindowMinutes,
    Value<bool>? enforceActionWindow,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return UserPreferencesTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      themeMode: themeMode ?? this.themeMode,
      colorSystem: colorSystem ?? this.colorSystem,
      notificationFrequency:
          notificationFrequency ?? this.notificationFrequency,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      hapticsEnabled: hapticsEnabled ?? this.hapticsEnabled,
      statisticsOptIn: statisticsOptIn ?? this.statisticsOptIn,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      selectedSound: selectedSound ?? this.selectedSound,
      quietHours: quietHours ?? this.quietHours,
      streakGoal: streakGoal ?? this.streakGoal,
      actionWindowMinutes: actionWindowMinutes ?? this.actionWindowMinutes,
      enforceActionWindow: enforceActionWindow ?? this.enforceActionWindow,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (colorSystem.present) {
      map['color_system'] = Variable<String>(colorSystem.value);
    }
    if (notificationFrequency.present) {
      map['notification_frequency'] = Variable<int>(
        notificationFrequency.value,
      );
    }
    if (soundEnabled.present) {
      map['sound_enabled'] = Variable<bool>(soundEnabled.value);
    }
    if (hapticsEnabled.present) {
      map['haptics_enabled'] = Variable<bool>(hapticsEnabled.value);
    }
    if (statisticsOptIn.present) {
      map['statistics_opt_in'] = Variable<bool>(statisticsOptIn.value);
    }
    if (onboardingCompleted.present) {
      map['onboarding_completed'] = Variable<bool>(onboardingCompleted.value);
    }
    if (selectedSound.present) {
      map['selected_sound'] = Variable<String>(selectedSound.value);
    }
    if (quietHours.present) {
      map['quiet_hours'] = Variable<String>(quietHours.value);
    }
    if (streakGoal.present) {
      map['streak_goal'] = Variable<int>(streakGoal.value);
    }
    if (actionWindowMinutes.present) {
      map['action_window_minutes'] = Variable<int>(actionWindowMinutes.value);
    }
    if (enforceActionWindow.present) {
      map['enforce_action_window'] = Variable<bool>(enforceActionWindow.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserPreferencesTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('themeMode: $themeMode, ')
          ..write('colorSystem: $colorSystem, ')
          ..write('notificationFrequency: $notificationFrequency, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('hapticsEnabled: $hapticsEnabled, ')
          ..write('statisticsOptIn: $statisticsOptIn, ')
          ..write('onboardingCompleted: $onboardingCompleted, ')
          ..write('selectedSound: $selectedSound, ')
          ..write('quietHours: $quietHours, ')
          ..write('streakGoal: $streakGoal, ')
          ..write('actionWindowMinutes: $actionWindowMinutes, ')
          ..write('enforceActionWindow: $enforceActionWindow, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderLogsTableTable extends ReminderLogsTable
    with TableInfo<$ReminderLogsTableTable, ReminderLogsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderLogsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledTimeMeta = const VerificationMeta(
    'scheduledTime',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledTime =
      GeneratedColumn<DateTime>(
        'scheduled_time',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _actionTakenMeta = const VerificationMeta(
    'actionTaken',
  );
  @override
  late final GeneratedColumn<String> actionTaken = GeneratedColumn<String>(
    'action_taken',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozeDurationMeta = const VerificationMeta(
    'snoozeDuration',
  );
  @override
  late final GeneratedColumn<int> snoozeDuration = GeneratedColumn<int>(
    'snooze_duration',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _timestampMeta = const VerificationMeta(
    'timestamp',
  );
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
    'timestamp',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _syncedToCloudMeta = const VerificationMeta(
    'syncedToCloud',
  );
  @override
  late final GeneratedColumn<bool> syncedToCloud = GeneratedColumn<bool>(
    'synced_to_cloud',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced_to_cloud" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    scheduledTime,
    actionTaken,
    snoozeDuration,
    timestamp,
    syncedToCloud,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_logs_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderLogsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('scheduled_time')) {
      context.handle(
        _scheduledTimeMeta,
        scheduledTime.isAcceptableOrUnknown(
          data['scheduled_time']!,
          _scheduledTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledTimeMeta);
    }
    if (data.containsKey('action_taken')) {
      context.handle(
        _actionTakenMeta,
        actionTaken.isAcceptableOrUnknown(
          data['action_taken']!,
          _actionTakenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actionTakenMeta);
    }
    if (data.containsKey('snooze_duration')) {
      context.handle(
        _snoozeDurationMeta,
        snoozeDuration.isAcceptableOrUnknown(
          data['snooze_duration']!,
          _snoozeDurationMeta,
        ),
      );
    }
    if (data.containsKey('timestamp')) {
      context.handle(
        _timestampMeta,
        timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta),
      );
    }
    if (data.containsKey('synced_to_cloud')) {
      context.handle(
        _syncedToCloudMeta,
        syncedToCloud.isAcceptableOrUnknown(
          data['synced_to_cloud']!,
          _syncedToCloudMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderLogsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderLogsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      scheduledTime: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_time'],
      )!,
      actionTaken: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}action_taken'],
      )!,
      snoozeDuration: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_duration'],
      )!,
      timestamp: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}timestamp'],
      )!,
      syncedToCloud: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced_to_cloud'],
      )!,
    );
  }

  @override
  $ReminderLogsTableTable createAlias(String alias) {
    return $ReminderLogsTableTable(attachedDatabase, alias);
  }
}

class ReminderLogsTableData extends DataClass
    implements Insertable<ReminderLogsTableData> {
  final String id;
  final String userId;
  final DateTime scheduledTime;
  final String actionTaken;
  final int snoozeDuration;
  final DateTime timestamp;
  final bool syncedToCloud;
  const ReminderLogsTableData({
    required this.id,
    required this.userId,
    required this.scheduledTime,
    required this.actionTaken,
    required this.snoozeDuration,
    required this.timestamp,
    required this.syncedToCloud,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['scheduled_time'] = Variable<DateTime>(scheduledTime);
    map['action_taken'] = Variable<String>(actionTaken);
    map['snooze_duration'] = Variable<int>(snoozeDuration);
    map['timestamp'] = Variable<DateTime>(timestamp);
    map['synced_to_cloud'] = Variable<bool>(syncedToCloud);
    return map;
  }

  ReminderLogsTableCompanion toCompanion(bool nullToAbsent) {
    return ReminderLogsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      scheduledTime: Value(scheduledTime),
      actionTaken: Value(actionTaken),
      snoozeDuration: Value(snoozeDuration),
      timestamp: Value(timestamp),
      syncedToCloud: Value(syncedToCloud),
    );
  }

  factory ReminderLogsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderLogsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      scheduledTime: serializer.fromJson<DateTime>(json['scheduledTime']),
      actionTaken: serializer.fromJson<String>(json['actionTaken']),
      snoozeDuration: serializer.fromJson<int>(json['snoozeDuration']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      syncedToCloud: serializer.fromJson<bool>(json['syncedToCloud']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'scheduledTime': serializer.toJson<DateTime>(scheduledTime),
      'actionTaken': serializer.toJson<String>(actionTaken),
      'snoozeDuration': serializer.toJson<int>(snoozeDuration),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'syncedToCloud': serializer.toJson<bool>(syncedToCloud),
    };
  }

  ReminderLogsTableData copyWith({
    String? id,
    String? userId,
    DateTime? scheduledTime,
    String? actionTaken,
    int? snoozeDuration,
    DateTime? timestamp,
    bool? syncedToCloud,
  }) => ReminderLogsTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    scheduledTime: scheduledTime ?? this.scheduledTime,
    actionTaken: actionTaken ?? this.actionTaken,
    snoozeDuration: snoozeDuration ?? this.snoozeDuration,
    timestamp: timestamp ?? this.timestamp,
    syncedToCloud: syncedToCloud ?? this.syncedToCloud,
  );
  ReminderLogsTableData copyWithCompanion(ReminderLogsTableCompanion data) {
    return ReminderLogsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      scheduledTime: data.scheduledTime.present
          ? data.scheduledTime.value
          : this.scheduledTime,
      actionTaken: data.actionTaken.present
          ? data.actionTaken.value
          : this.actionTaken,
      snoozeDuration: data.snoozeDuration.present
          ? data.snoozeDuration.value
          : this.snoozeDuration,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      syncedToCloud: data.syncedToCloud.present
          ? data.syncedToCloud.value
          : this.syncedToCloud,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLogsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('scheduledTime: $scheduledTime, ')
          ..write('actionTaken: $actionTaken, ')
          ..write('snoozeDuration: $snoozeDuration, ')
          ..write('timestamp: $timestamp, ')
          ..write('syncedToCloud: $syncedToCloud')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    scheduledTime,
    actionTaken,
    snoozeDuration,
    timestamp,
    syncedToCloud,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderLogsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.scheduledTime == this.scheduledTime &&
          other.actionTaken == this.actionTaken &&
          other.snoozeDuration == this.snoozeDuration &&
          other.timestamp == this.timestamp &&
          other.syncedToCloud == this.syncedToCloud);
}

class ReminderLogsTableCompanion
    extends UpdateCompanion<ReminderLogsTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<DateTime> scheduledTime;
  final Value<String> actionTaken;
  final Value<int> snoozeDuration;
  final Value<DateTime> timestamp;
  final Value<bool> syncedToCloud;
  final Value<int> rowid;
  const ReminderLogsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.scheduledTime = const Value.absent(),
    this.actionTaken = const Value.absent(),
    this.snoozeDuration = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderLogsTableCompanion.insert({
    required String id,
    required String userId,
    required DateTime scheduledTime,
    required String actionTaken,
    this.snoozeDuration = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       scheduledTime = Value(scheduledTime),
       actionTaken = Value(actionTaken);
  static Insertable<ReminderLogsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<DateTime>? scheduledTime,
    Expression<String>? actionTaken,
    Expression<int>? snoozeDuration,
    Expression<DateTime>? timestamp,
    Expression<bool>? syncedToCloud,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (scheduledTime != null) 'scheduled_time': scheduledTime,
      if (actionTaken != null) 'action_taken': actionTaken,
      if (snoozeDuration != null) 'snooze_duration': snoozeDuration,
      if (timestamp != null) 'timestamp': timestamp,
      if (syncedToCloud != null) 'synced_to_cloud': syncedToCloud,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderLogsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<DateTime>? scheduledTime,
    Value<String>? actionTaken,
    Value<int>? snoozeDuration,
    Value<DateTime>? timestamp,
    Value<bool>? syncedToCloud,
    Value<int>? rowid,
  }) {
    return ReminderLogsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      actionTaken: actionTaken ?? this.actionTaken,
      snoozeDuration: snoozeDuration ?? this.snoozeDuration,
      timestamp: timestamp ?? this.timestamp,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (scheduledTime.present) {
      map['scheduled_time'] = Variable<DateTime>(scheduledTime.value);
    }
    if (actionTaken.present) {
      map['action_taken'] = Variable<String>(actionTaken.value);
    }
    if (snoozeDuration.present) {
      map['snooze_duration'] = Variable<int>(snoozeDuration.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (syncedToCloud.present) {
      map['synced_to_cloud'] = Variable<bool>(syncedToCloud.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderLogsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('scheduledTime: $scheduledTime, ')
          ..write('actionTaken: $actionTaken, ')
          ..write('snoozeDuration: $snoozeDuration, ')
          ..write('timestamp: $timestamp, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnalyticsDailyTableTable extends AnalyticsDailyTable
    with TableInfo<$AnalyticsDailyTableTable, AnalyticsDailyTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnalyticsDailyTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<String> date = GeneratedColumn<String>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remindersSentMeta = const VerificationMeta(
    'remindersSent',
  );
  @override
  late final GeneratedColumn<int> remindersSent = GeneratedColumn<int>(
    'reminders_sent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remindersCompletedMeta =
      const VerificationMeta('remindersCompleted');
  @override
  late final GeneratedColumn<int> remindersCompleted = GeneratedColumn<int>(
    'reminders_completed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remindersSnoozedMeta = const VerificationMeta(
    'remindersSnoozed',
  );
  @override
  late final GeneratedColumn<int> remindersSnoozed = GeneratedColumn<int>(
    'reminders_snoozed',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _remindersSkippedMeta = const VerificationMeta(
    'remindersSkipped',
  );
  @override
  late final GeneratedColumn<int> remindersSkipped = GeneratedColumn<int>(
    'reminders_skipped',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalStandTimeMeta = const VerificationMeta(
    'totalStandTime',
  );
  @override
  late final GeneratedColumn<int> totalStandTime = GeneratedColumn<int>(
    'total_stand_time',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _organizationIdMeta = const VerificationMeta(
    'organizationId',
  );
  @override
  late final GeneratedColumn<String> organizationId = GeneratedColumn<String>(
    'organization_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _syncedToCloudMeta = const VerificationMeta(
    'syncedToCloud',
  );
  @override
  late final GeneratedColumn<bool> syncedToCloud = GeneratedColumn<bool>(
    'synced_to_cloud',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("synced_to_cloud" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    date,
    remindersSent,
    remindersCompleted,
    remindersSnoozed,
    remindersSkipped,
    totalStandTime,
    organizationId,
    syncedToCloud,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'analytics_daily_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<AnalyticsDailyTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('reminders_sent')) {
      context.handle(
        _remindersSentMeta,
        remindersSent.isAcceptableOrUnknown(
          data['reminders_sent']!,
          _remindersSentMeta,
        ),
      );
    }
    if (data.containsKey('reminders_completed')) {
      context.handle(
        _remindersCompletedMeta,
        remindersCompleted.isAcceptableOrUnknown(
          data['reminders_completed']!,
          _remindersCompletedMeta,
        ),
      );
    }
    if (data.containsKey('reminders_snoozed')) {
      context.handle(
        _remindersSnoozedMeta,
        remindersSnoozed.isAcceptableOrUnknown(
          data['reminders_snoozed']!,
          _remindersSnoozedMeta,
        ),
      );
    }
    if (data.containsKey('reminders_skipped')) {
      context.handle(
        _remindersSkippedMeta,
        remindersSkipped.isAcceptableOrUnknown(
          data['reminders_skipped']!,
          _remindersSkippedMeta,
        ),
      );
    }
    if (data.containsKey('total_stand_time')) {
      context.handle(
        _totalStandTimeMeta,
        totalStandTime.isAcceptableOrUnknown(
          data['total_stand_time']!,
          _totalStandTimeMeta,
        ),
      );
    }
    if (data.containsKey('organization_id')) {
      context.handle(
        _organizationIdMeta,
        organizationId.isAcceptableOrUnknown(
          data['organization_id']!,
          _organizationIdMeta,
        ),
      );
    }
    if (data.containsKey('synced_to_cloud')) {
      context.handle(
        _syncedToCloudMeta,
        syncedToCloud.isAcceptableOrUnknown(
          data['synced_to_cloud']!,
          _syncedToCloudMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AnalyticsDailyTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AnalyticsDailyTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date'],
      )!,
      remindersSent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminders_sent'],
      )!,
      remindersCompleted: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminders_completed'],
      )!,
      remindersSnoozed: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminders_snoozed'],
      )!,
      remindersSkipped: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reminders_skipped'],
      )!,
      totalStandTime: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_stand_time'],
      )!,
      organizationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}organization_id'],
      ),
      syncedToCloud: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}synced_to_cloud'],
      )!,
    );
  }

  @override
  $AnalyticsDailyTableTable createAlias(String alias) {
    return $AnalyticsDailyTableTable(attachedDatabase, alias);
  }
}

class AnalyticsDailyTableData extends DataClass
    implements Insertable<AnalyticsDailyTableData> {
  final String id;
  final String userId;
  final String date;
  final int remindersSent;
  final int remindersCompleted;
  final int remindersSnoozed;
  final int remindersSkipped;
  final int totalStandTime;
  final String? organizationId;
  final bool syncedToCloud;
  const AnalyticsDailyTableData({
    required this.id,
    required this.userId,
    required this.date,
    required this.remindersSent,
    required this.remindersCompleted,
    required this.remindersSnoozed,
    required this.remindersSkipped,
    required this.totalStandTime,
    this.organizationId,
    required this.syncedToCloud,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['date'] = Variable<String>(date);
    map['reminders_sent'] = Variable<int>(remindersSent);
    map['reminders_completed'] = Variable<int>(remindersCompleted);
    map['reminders_snoozed'] = Variable<int>(remindersSnoozed);
    map['reminders_skipped'] = Variable<int>(remindersSkipped);
    map['total_stand_time'] = Variable<int>(totalStandTime);
    if (!nullToAbsent || organizationId != null) {
      map['organization_id'] = Variable<String>(organizationId);
    }
    map['synced_to_cloud'] = Variable<bool>(syncedToCloud);
    return map;
  }

  AnalyticsDailyTableCompanion toCompanion(bool nullToAbsent) {
    return AnalyticsDailyTableCompanion(
      id: Value(id),
      userId: Value(userId),
      date: Value(date),
      remindersSent: Value(remindersSent),
      remindersCompleted: Value(remindersCompleted),
      remindersSnoozed: Value(remindersSnoozed),
      remindersSkipped: Value(remindersSkipped),
      totalStandTime: Value(totalStandTime),
      organizationId: organizationId == null && nullToAbsent
          ? const Value.absent()
          : Value(organizationId),
      syncedToCloud: Value(syncedToCloud),
    );
  }

  factory AnalyticsDailyTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AnalyticsDailyTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      date: serializer.fromJson<String>(json['date']),
      remindersSent: serializer.fromJson<int>(json['remindersSent']),
      remindersCompleted: serializer.fromJson<int>(json['remindersCompleted']),
      remindersSnoozed: serializer.fromJson<int>(json['remindersSnoozed']),
      remindersSkipped: serializer.fromJson<int>(json['remindersSkipped']),
      totalStandTime: serializer.fromJson<int>(json['totalStandTime']),
      organizationId: serializer.fromJson<String?>(json['organizationId']),
      syncedToCloud: serializer.fromJson<bool>(json['syncedToCloud']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'date': serializer.toJson<String>(date),
      'remindersSent': serializer.toJson<int>(remindersSent),
      'remindersCompleted': serializer.toJson<int>(remindersCompleted),
      'remindersSnoozed': serializer.toJson<int>(remindersSnoozed),
      'remindersSkipped': serializer.toJson<int>(remindersSkipped),
      'totalStandTime': serializer.toJson<int>(totalStandTime),
      'organizationId': serializer.toJson<String?>(organizationId),
      'syncedToCloud': serializer.toJson<bool>(syncedToCloud),
    };
  }

  AnalyticsDailyTableData copyWith({
    String? id,
    String? userId,
    String? date,
    int? remindersSent,
    int? remindersCompleted,
    int? remindersSnoozed,
    int? remindersSkipped,
    int? totalStandTime,
    Value<String?> organizationId = const Value.absent(),
    bool? syncedToCloud,
  }) => AnalyticsDailyTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    date: date ?? this.date,
    remindersSent: remindersSent ?? this.remindersSent,
    remindersCompleted: remindersCompleted ?? this.remindersCompleted,
    remindersSnoozed: remindersSnoozed ?? this.remindersSnoozed,
    remindersSkipped: remindersSkipped ?? this.remindersSkipped,
    totalStandTime: totalStandTime ?? this.totalStandTime,
    organizationId: organizationId.present
        ? organizationId.value
        : this.organizationId,
    syncedToCloud: syncedToCloud ?? this.syncedToCloud,
  );
  AnalyticsDailyTableData copyWithCompanion(AnalyticsDailyTableCompanion data) {
    return AnalyticsDailyTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      date: data.date.present ? data.date.value : this.date,
      remindersSent: data.remindersSent.present
          ? data.remindersSent.value
          : this.remindersSent,
      remindersCompleted: data.remindersCompleted.present
          ? data.remindersCompleted.value
          : this.remindersCompleted,
      remindersSnoozed: data.remindersSnoozed.present
          ? data.remindersSnoozed.value
          : this.remindersSnoozed,
      remindersSkipped: data.remindersSkipped.present
          ? data.remindersSkipped.value
          : this.remindersSkipped,
      totalStandTime: data.totalStandTime.present
          ? data.totalStandTime.value
          : this.totalStandTime,
      organizationId: data.organizationId.present
          ? data.organizationId.value
          : this.organizationId,
      syncedToCloud: data.syncedToCloud.present
          ? data.syncedToCloud.value
          : this.syncedToCloud,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsDailyTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('date: $date, ')
          ..write('remindersSent: $remindersSent, ')
          ..write('remindersCompleted: $remindersCompleted, ')
          ..write('remindersSnoozed: $remindersSnoozed, ')
          ..write('remindersSkipped: $remindersSkipped, ')
          ..write('totalStandTime: $totalStandTime, ')
          ..write('organizationId: $organizationId, ')
          ..write('syncedToCloud: $syncedToCloud')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    date,
    remindersSent,
    remindersCompleted,
    remindersSnoozed,
    remindersSkipped,
    totalStandTime,
    organizationId,
    syncedToCloud,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AnalyticsDailyTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.date == this.date &&
          other.remindersSent == this.remindersSent &&
          other.remindersCompleted == this.remindersCompleted &&
          other.remindersSnoozed == this.remindersSnoozed &&
          other.remindersSkipped == this.remindersSkipped &&
          other.totalStandTime == this.totalStandTime &&
          other.organizationId == this.organizationId &&
          other.syncedToCloud == this.syncedToCloud);
}

class AnalyticsDailyTableCompanion
    extends UpdateCompanion<AnalyticsDailyTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> date;
  final Value<int> remindersSent;
  final Value<int> remindersCompleted;
  final Value<int> remindersSnoozed;
  final Value<int> remindersSkipped;
  final Value<int> totalStandTime;
  final Value<String?> organizationId;
  final Value<bool> syncedToCloud;
  final Value<int> rowid;
  const AnalyticsDailyTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.date = const Value.absent(),
    this.remindersSent = const Value.absent(),
    this.remindersCompleted = const Value.absent(),
    this.remindersSnoozed = const Value.absent(),
    this.remindersSkipped = const Value.absent(),
    this.totalStandTime = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnalyticsDailyTableCompanion.insert({
    required String id,
    required String userId,
    required String date,
    this.remindersSent = const Value.absent(),
    this.remindersCompleted = const Value.absent(),
    this.remindersSnoozed = const Value.absent(),
    this.remindersSkipped = const Value.absent(),
    this.totalStandTime = const Value.absent(),
    this.organizationId = const Value.absent(),
    this.syncedToCloud = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       date = Value(date);
  static Insertable<AnalyticsDailyTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? date,
    Expression<int>? remindersSent,
    Expression<int>? remindersCompleted,
    Expression<int>? remindersSnoozed,
    Expression<int>? remindersSkipped,
    Expression<int>? totalStandTime,
    Expression<String>? organizationId,
    Expression<bool>? syncedToCloud,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (date != null) 'date': date,
      if (remindersSent != null) 'reminders_sent': remindersSent,
      if (remindersCompleted != null) 'reminders_completed': remindersCompleted,
      if (remindersSnoozed != null) 'reminders_snoozed': remindersSnoozed,
      if (remindersSkipped != null) 'reminders_skipped': remindersSkipped,
      if (totalStandTime != null) 'total_stand_time': totalStandTime,
      if (organizationId != null) 'organization_id': organizationId,
      if (syncedToCloud != null) 'synced_to_cloud': syncedToCloud,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnalyticsDailyTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? date,
    Value<int>? remindersSent,
    Value<int>? remindersCompleted,
    Value<int>? remindersSnoozed,
    Value<int>? remindersSkipped,
    Value<int>? totalStandTime,
    Value<String?>? organizationId,
    Value<bool>? syncedToCloud,
    Value<int>? rowid,
  }) {
    return AnalyticsDailyTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      remindersSent: remindersSent ?? this.remindersSent,
      remindersCompleted: remindersCompleted ?? this.remindersCompleted,
      remindersSnoozed: remindersSnoozed ?? this.remindersSnoozed,
      remindersSkipped: remindersSkipped ?? this.remindersSkipped,
      totalStandTime: totalStandTime ?? this.totalStandTime,
      organizationId: organizationId ?? this.organizationId,
      syncedToCloud: syncedToCloud ?? this.syncedToCloud,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (date.present) {
      map['date'] = Variable<String>(date.value);
    }
    if (remindersSent.present) {
      map['reminders_sent'] = Variable<int>(remindersSent.value);
    }
    if (remindersCompleted.present) {
      map['reminders_completed'] = Variable<int>(remindersCompleted.value);
    }
    if (remindersSnoozed.present) {
      map['reminders_snoozed'] = Variable<int>(remindersSnoozed.value);
    }
    if (remindersSkipped.present) {
      map['reminders_skipped'] = Variable<int>(remindersSkipped.value);
    }
    if (totalStandTime.present) {
      map['total_stand_time'] = Variable<int>(totalStandTime.value);
    }
    if (organizationId.present) {
      map['organization_id'] = Variable<String>(organizationId.value);
    }
    if (syncedToCloud.present) {
      map['synced_to_cloud'] = Variable<bool>(syncedToCloud.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnalyticsDailyTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('date: $date, ')
          ..write('remindersSent: $remindersSent, ')
          ..write('remindersCompleted: $remindersCompleted, ')
          ..write('remindersSnoozed: $remindersSnoozed, ')
          ..write('remindersSkipped: $remindersSkipped, ')
          ..write('totalStandTime: $totalStandTime, ')
          ..write('organizationId: $organizationId, ')
          ..write('syncedToCloud: $syncedToCloud, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTableTable userProfilesTable =
      $UserProfilesTableTable(this);
  late final $UserPreferencesTableTable userPreferencesTable =
      $UserPreferencesTableTable(this);
  late final $ReminderLogsTableTable reminderLogsTable =
      $ReminderLogsTableTable(this);
  late final $AnalyticsDailyTableTable analyticsDailyTable =
      $AnalyticsDailyTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfilesTable,
    userPreferencesTable,
    reminderLogsTable,
    analyticsDailyTable,
  ];
}

typedef $$UserProfilesTableTableCreateCompanionBuilder =
    UserProfilesTableCompanion Function({
      required String id,
      required String name,
      Value<String?> designation,
      Value<String?> department,
      Value<String?> email,
      Value<String?> organizationId,
      Value<String> role,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });
typedef $$UserProfilesTableTableUpdateCompanionBuilder =
    UserProfilesTableCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String?> designation,
      Value<String?> department,
      Value<String?> email,
      Value<String?> organizationId,
      Value<String> role,
      Value<DateTime> createdAt,
      Value<int> rowid,
    });

class $$UserProfilesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get email => $composableBuilder(
    column: $table.email,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTableTable> {
  $$UserProfilesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get designation => $composableBuilder(
    column: $table.designation,
    builder: (column) => column,
  );

  GeneratedColumn<String> get department => $composableBuilder(
    column: $table.department,
    builder: (column) => column,
  );

  GeneratedColumn<String> get email =>
      $composableBuilder(column: $table.email, builder: (column) => column);

  GeneratedColumn<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UserProfilesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTableTable,
          UserProfilesTableData,
          $$UserProfilesTableTableFilterComposer,
          $$UserProfilesTableTableOrderingComposer,
          $$UserProfilesTableTableAnnotationComposer,
          $$UserProfilesTableTableCreateCompanionBuilder,
          $$UserProfilesTableTableUpdateCompanionBuilder,
          (
            UserProfilesTableData,
            BaseReferences<
              _$AppDatabase,
              $UserProfilesTableTable,
              UserProfilesTableData
            >,
          ),
          UserProfilesTableData,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableTableManager(
    _$AppDatabase db,
    $UserProfilesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> designation = const Value.absent(),
                Value<String?> department = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesTableCompanion(
                id: id,
                name: name,
                designation: designation,
                department: department,
                email: email,
                organizationId: organizationId,
                role: role,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                Value<String?> designation = const Value.absent(),
                Value<String?> department = const Value.absent(),
                Value<String?> email = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserProfilesTableCompanion.insert(
                id: id,
                name: name,
                designation: designation,
                department: department,
                email: email,
                organizationId: organizationId,
                role: role,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfilesTableTable, UserProfilesTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfilesTableTable,
                    UserProfilesTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTableTable,
      UserProfilesTableData,
      $$UserProfilesTableTableFilterComposer,
      $$UserProfilesTableTableOrderingComposer,
      $$UserProfilesTableTableAnnotationComposer,
      $$UserProfilesTableTableCreateCompanionBuilder,
      $$UserProfilesTableTableUpdateCompanionBuilder,
      (
        UserProfilesTableData,
        BaseReferences<
          _$AppDatabase,
          $UserProfilesTableTable,
          UserProfilesTableData
        >,
      ),
      UserProfilesTableData,
      PrefetchHooks Function()
    >;
typedef $$UserPreferencesTableTableCreateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      required String id,
      required String userId,
      Value<String> themeMode,
      Value<String> colorSystem,
      Value<int> notificationFrequency,
      Value<bool> soundEnabled,
      Value<bool> hapticsEnabled,
      Value<bool> statisticsOptIn,
      Value<bool> onboardingCompleted,
      Value<String> selectedSound,
      Value<String?> quietHours,
      Value<int> streakGoal,
      Value<int> actionWindowMinutes,
      Value<bool> enforceActionWindow,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$UserPreferencesTableTableUpdateCompanionBuilder =
    UserPreferencesTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> themeMode,
      Value<String> colorSystem,
      Value<int> notificationFrequency,
      Value<bool> soundEnabled,
      Value<bool> hapticsEnabled,
      Value<bool> statisticsOptIn,
      Value<bool> onboardingCompleted,
      Value<String> selectedSound,
      Value<String?> quietHours,
      Value<int> streakGoal,
      Value<int> actionWindowMinutes,
      Value<bool> enforceActionWindow,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$UserPreferencesTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorSystem => $composableBuilder(
    column: $table.colorSystem,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get notificationFrequency => $composableBuilder(
    column: $table.notificationFrequency,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get statisticsOptIn => $composableBuilder(
    column: $table.statisticsOptIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get selectedSound => $composableBuilder(
    column: $table.selectedSound,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quietHours => $composableBuilder(
    column: $table.quietHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get streakGoal => $composableBuilder(
    column: $table.streakGoal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actionWindowMinutes => $composableBuilder(
    column: $table.actionWindowMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enforceActionWindow => $composableBuilder(
    column: $table.enforceActionWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserPreferencesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get themeMode => $composableBuilder(
    column: $table.themeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorSystem => $composableBuilder(
    column: $table.colorSystem,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get notificationFrequency => $composableBuilder(
    column: $table.notificationFrequency,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get statisticsOptIn => $composableBuilder(
    column: $table.statisticsOptIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get selectedSound => $composableBuilder(
    column: $table.selectedSound,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quietHours => $composableBuilder(
    column: $table.quietHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get streakGoal => $composableBuilder(
    column: $table.streakGoal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actionWindowMinutes => $composableBuilder(
    column: $table.actionWindowMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enforceActionWindow => $composableBuilder(
    column: $table.enforceActionWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserPreferencesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserPreferencesTableTable> {
  $$UserPreferencesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<String> get colorSystem => $composableBuilder(
    column: $table.colorSystem,
    builder: (column) => column,
  );

  GeneratedColumn<int> get notificationFrequency => $composableBuilder(
    column: $table.notificationFrequency,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get hapticsEnabled => $composableBuilder(
    column: $table.hapticsEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get statisticsOptIn => $composableBuilder(
    column: $table.statisticsOptIn,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingCompleted => $composableBuilder(
    column: $table.onboardingCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<String> get selectedSound => $composableBuilder(
    column: $table.selectedSound,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quietHours => $composableBuilder(
    column: $table.quietHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get streakGoal => $composableBuilder(
    column: $table.streakGoal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actionWindowMinutes => $composableBuilder(
    column: $table.actionWindowMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enforceActionWindow => $composableBuilder(
    column: $table.enforceActionWindow,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserPreferencesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesTableData,
          $$UserPreferencesTableTableFilterComposer,
          $$UserPreferencesTableTableOrderingComposer,
          $$UserPreferencesTableTableAnnotationComposer,
          $$UserPreferencesTableTableCreateCompanionBuilder,
          $$UserPreferencesTableTableUpdateCompanionBuilder,
          (
            UserPreferencesTableData,
            BaseReferences<
              _$AppDatabase,
              $UserPreferencesTableTable,
              UserPreferencesTableData
            >,
          ),
          UserPreferencesTableData,
          PrefetchHooks Function()
        > {
  $$UserPreferencesTableTableTableManager(
    _$AppDatabase db,
    $UserPreferencesTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserPreferencesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserPreferencesTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UserPreferencesTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> themeMode = const Value.absent(),
                Value<String> colorSystem = const Value.absent(),
                Value<int> notificationFrequency = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> statisticsOptIn = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<String> selectedSound = const Value.absent(),
                Value<String?> quietHours = const Value.absent(),
                Value<int> streakGoal = const Value.absent(),
                Value<int> actionWindowMinutes = const Value.absent(),
                Value<bool> enforceActionWindow = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion(
                id: id,
                userId: userId,
                themeMode: themeMode,
                colorSystem: colorSystem,
                notificationFrequency: notificationFrequency,
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                statisticsOptIn: statisticsOptIn,
                onboardingCompleted: onboardingCompleted,
                selectedSound: selectedSound,
                quietHours: quietHours,
                streakGoal: streakGoal,
                actionWindowMinutes: actionWindowMinutes,
                enforceActionWindow: enforceActionWindow,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                Value<String> themeMode = const Value.absent(),
                Value<String> colorSystem = const Value.absent(),
                Value<int> notificationFrequency = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
                Value<bool> hapticsEnabled = const Value.absent(),
                Value<bool> statisticsOptIn = const Value.absent(),
                Value<bool> onboardingCompleted = const Value.absent(),
                Value<String> selectedSound = const Value.absent(),
                Value<String?> quietHours = const Value.absent(),
                Value<int> streakGoal = const Value.absent(),
                Value<int> actionWindowMinutes = const Value.absent(),
                Value<bool> enforceActionWindow = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UserPreferencesTableCompanion.insert(
                id: id,
                userId: userId,
                themeMode: themeMode,
                colorSystem: colorSystem,
                notificationFrequency: notificationFrequency,
                soundEnabled: soundEnabled,
                hapticsEnabled: hapticsEnabled,
                statisticsOptIn: statisticsOptIn,
                onboardingCompleted: onboardingCompleted,
                selectedSound: selectedSound,
                quietHours: quietHours,
                streakGoal: streakGoal,
                actionWindowMinutes: actionWindowMinutes,
                enforceActionWindow: enforceActionWindow,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $UserPreferencesTableTable,
                    UserPreferencesTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserPreferencesTableTable,
                    UserPreferencesTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserPreferencesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserPreferencesTableTable,
      UserPreferencesTableData,
      $$UserPreferencesTableTableFilterComposer,
      $$UserPreferencesTableTableOrderingComposer,
      $$UserPreferencesTableTableAnnotationComposer,
      $$UserPreferencesTableTableCreateCompanionBuilder,
      $$UserPreferencesTableTableUpdateCompanionBuilder,
      (
        UserPreferencesTableData,
        BaseReferences<
          _$AppDatabase,
          $UserPreferencesTableTable,
          UserPreferencesTableData
        >,
      ),
      UserPreferencesTableData,
      PrefetchHooks Function()
    >;
typedef $$ReminderLogsTableTableCreateCompanionBuilder =
    ReminderLogsTableCompanion Function({
      required String id,
      required String userId,
      required DateTime scheduledTime,
      required String actionTaken,
      Value<int> snoozeDuration,
      Value<DateTime> timestamp,
      Value<bool> syncedToCloud,
      Value<int> rowid,
    });
typedef $$ReminderLogsTableTableUpdateCompanionBuilder =
    ReminderLogsTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<DateTime> scheduledTime,
      Value<String> actionTaken,
      Value<int> snoozeDuration,
      Value<DateTime> timestamp,
      Value<bool> syncedToCloud,
      Value<int> rowid,
    });

class $$ReminderLogsTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderLogsTableTable> {
  $$ReminderLogsTableTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actionTaken => $composableBuilder(
    column: $table.actionTaken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozeDuration => $composableBuilder(
    column: $table.snoozeDuration,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderLogsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderLogsTableTable> {
  $$ReminderLogsTableTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actionTaken => $composableBuilder(
    column: $table.actionTaken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeDuration => $composableBuilder(
    column: $table.snoozeDuration,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
    column: $table.timestamp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderLogsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderLogsTableTable> {
  $$ReminderLogsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledTime => $composableBuilder(
    column: $table.scheduledTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get actionTaken => $composableBuilder(
    column: $table.actionTaken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeDuration => $composableBuilder(
    column: $table.snoozeDuration,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => column,
  );
}

class $$ReminderLogsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderLogsTableTable,
          ReminderLogsTableData,
          $$ReminderLogsTableTableFilterComposer,
          $$ReminderLogsTableTableOrderingComposer,
          $$ReminderLogsTableTableAnnotationComposer,
          $$ReminderLogsTableTableCreateCompanionBuilder,
          $$ReminderLogsTableTableUpdateCompanionBuilder,
          (
            ReminderLogsTableData,
            BaseReferences<
              _$AppDatabase,
              $ReminderLogsTableTable,
              ReminderLogsTableData
            >,
          ),
          ReminderLogsTableData,
          PrefetchHooks Function()
        > {
  $$ReminderLogsTableTableTableManager(
    _$AppDatabase db,
    $ReminderLogsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderLogsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderLogsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderLogsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<DateTime> scheduledTime = const Value.absent(),
                Value<String> actionTaken = const Value.absent(),
                Value<int> snoozeDuration = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<bool> syncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderLogsTableCompanion(
                id: id,
                userId: userId,
                scheduledTime: scheduledTime,
                actionTaken: actionTaken,
                snoozeDuration: snoozeDuration,
                timestamp: timestamp,
                syncedToCloud: syncedToCloud,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required DateTime scheduledTime,
                required String actionTaken,
                Value<int> snoozeDuration = const Value.absent(),
                Value<DateTime> timestamp = const Value.absent(),
                Value<bool> syncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ReminderLogsTableCompanion.insert(
                id: id,
                userId: userId,
                scheduledTime: scheduledTime,
                actionTaken: actionTaken,
                snoozeDuration: snoozeDuration,
                timestamp: timestamp,
                syncedToCloud: syncedToCloud,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderLogsTableTable, ReminderLogsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $ReminderLogsTableTable,
                    ReminderLogsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderLogsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderLogsTableTable,
      ReminderLogsTableData,
      $$ReminderLogsTableTableFilterComposer,
      $$ReminderLogsTableTableOrderingComposer,
      $$ReminderLogsTableTableAnnotationComposer,
      $$ReminderLogsTableTableCreateCompanionBuilder,
      $$ReminderLogsTableTableUpdateCompanionBuilder,
      (
        ReminderLogsTableData,
        BaseReferences<
          _$AppDatabase,
          $ReminderLogsTableTable,
          ReminderLogsTableData
        >,
      ),
      ReminderLogsTableData,
      PrefetchHooks Function()
    >;
typedef $$AnalyticsDailyTableTableCreateCompanionBuilder =
    AnalyticsDailyTableCompanion Function({
      required String id,
      required String userId,
      required String date,
      Value<int> remindersSent,
      Value<int> remindersCompleted,
      Value<int> remindersSnoozed,
      Value<int> remindersSkipped,
      Value<int> totalStandTime,
      Value<String?> organizationId,
      Value<bool> syncedToCloud,
      Value<int> rowid,
    });
typedef $$AnalyticsDailyTableTableUpdateCompanionBuilder =
    AnalyticsDailyTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> date,
      Value<int> remindersSent,
      Value<int> remindersCompleted,
      Value<int> remindersSnoozed,
      Value<int> remindersSkipped,
      Value<int> totalStandTime,
      Value<String?> organizationId,
      Value<bool> syncedToCloud,
      Value<int> rowid,
    });

class $$AnalyticsDailyTableTableFilterComposer
    extends Composer<_$AppDatabase, $AnalyticsDailyTableTable> {
  $$AnalyticsDailyTableTableFilterComposer({
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

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindersSent => $composableBuilder(
    column: $table.remindersSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindersCompleted => $composableBuilder(
    column: $table.remindersCompleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindersSnoozed => $composableBuilder(
    column: $table.remindersSnoozed,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remindersSkipped => $composableBuilder(
    column: $table.remindersSkipped,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalStandTime => $composableBuilder(
    column: $table.totalStandTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AnalyticsDailyTableTableOrderingComposer
    extends Composer<_$AppDatabase, $AnalyticsDailyTableTable> {
  $$AnalyticsDailyTableTableOrderingComposer({
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

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindersSent => $composableBuilder(
    column: $table.remindersSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindersCompleted => $composableBuilder(
    column: $table.remindersCompleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindersSnoozed => $composableBuilder(
    column: $table.remindersSnoozed,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remindersSkipped => $composableBuilder(
    column: $table.remindersSkipped,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalStandTime => $composableBuilder(
    column: $table.totalStandTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AnalyticsDailyTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $AnalyticsDailyTableTable> {
  $$AnalyticsDailyTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<int> get remindersSent => $composableBuilder(
    column: $table.remindersSent,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindersCompleted => $composableBuilder(
    column: $table.remindersCompleted,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindersSnoozed => $composableBuilder(
    column: $table.remindersSnoozed,
    builder: (column) => column,
  );

  GeneratedColumn<int> get remindersSkipped => $composableBuilder(
    column: $table.remindersSkipped,
    builder: (column) => column,
  );

  GeneratedColumn<int> get totalStandTime => $composableBuilder(
    column: $table.totalStandTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get organizationId => $composableBuilder(
    column: $table.organizationId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get syncedToCloud => $composableBuilder(
    column: $table.syncedToCloud,
    builder: (column) => column,
  );
}

class $$AnalyticsDailyTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnalyticsDailyTableTable,
          AnalyticsDailyTableData,
          $$AnalyticsDailyTableTableFilterComposer,
          $$AnalyticsDailyTableTableOrderingComposer,
          $$AnalyticsDailyTableTableAnnotationComposer,
          $$AnalyticsDailyTableTableCreateCompanionBuilder,
          $$AnalyticsDailyTableTableUpdateCompanionBuilder,
          (
            AnalyticsDailyTableData,
            BaseReferences<
              _$AppDatabase,
              $AnalyticsDailyTableTable,
              AnalyticsDailyTableData
            >,
          ),
          AnalyticsDailyTableData,
          PrefetchHooks Function()
        > {
  $$AnalyticsDailyTableTableTableManager(
    _$AppDatabase db,
    $AnalyticsDailyTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AnalyticsDailyTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AnalyticsDailyTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$AnalyticsDailyTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> date = const Value.absent(),
                Value<int> remindersSent = const Value.absent(),
                Value<int> remindersCompleted = const Value.absent(),
                Value<int> remindersSnoozed = const Value.absent(),
                Value<int> remindersSkipped = const Value.absent(),
                Value<int> totalStandTime = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<bool> syncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsDailyTableCompanion(
                id: id,
                userId: userId,
                date: date,
                remindersSent: remindersSent,
                remindersCompleted: remindersCompleted,
                remindersSnoozed: remindersSnoozed,
                remindersSkipped: remindersSkipped,
                totalStandTime: totalStandTime,
                organizationId: organizationId,
                syncedToCloud: syncedToCloud,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String date,
                Value<int> remindersSent = const Value.absent(),
                Value<int> remindersCompleted = const Value.absent(),
                Value<int> remindersSnoozed = const Value.absent(),
                Value<int> remindersSkipped = const Value.absent(),
                Value<int> totalStandTime = const Value.absent(),
                Value<String?> organizationId = const Value.absent(),
                Value<bool> syncedToCloud = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AnalyticsDailyTableCompanion.insert(
                id: id,
                userId: userId,
                date: date,
                remindersSent: remindersSent,
                remindersCompleted: remindersCompleted,
                remindersSnoozed: remindersSnoozed,
                remindersSkipped: remindersSkipped,
                totalStandTime: totalStandTime,
                organizationId: organizationId,
                syncedToCloud: syncedToCloud,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $AnalyticsDailyTableTable,
                    AnalyticsDailyTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $AnalyticsDailyTableTable,
                    AnalyticsDailyTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnalyticsDailyTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnalyticsDailyTableTable,
      AnalyticsDailyTableData,
      $$AnalyticsDailyTableTableFilterComposer,
      $$AnalyticsDailyTableTableOrderingComposer,
      $$AnalyticsDailyTableTableAnnotationComposer,
      $$AnalyticsDailyTableTableCreateCompanionBuilder,
      $$AnalyticsDailyTableTableUpdateCompanionBuilder,
      (
        AnalyticsDailyTableData,
        BaseReferences<
          _$AppDatabase,
          $AnalyticsDailyTableTable,
          AnalyticsDailyTableData
        >,
      ),
      AnalyticsDailyTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableTableManager get userProfilesTable =>
      $$UserProfilesTableTableTableManager(_db, _db.userProfilesTable);
  $$UserPreferencesTableTableTableManager get userPreferencesTable =>
      $$UserPreferencesTableTableTableManager(_db, _db.userPreferencesTable);
  $$ReminderLogsTableTableTableManager get reminderLogsTable =>
      $$ReminderLogsTableTableTableManager(_db, _db.reminderLogsTable);
  $$AnalyticsDailyTableTableTableManager get analyticsDailyTable =>
      $$AnalyticsDailyTableTableTableManager(_db, _db.analyticsDailyTable);
}
