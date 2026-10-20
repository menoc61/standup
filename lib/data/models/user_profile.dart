class UserProfile {
  final String id;
  final String name;
  final String? designation;
  final String? department;
  final String? email;
  final String? organizationId;
  final String? organizationName;
  final String role; // 'employee', 'admin'
  final DateTime createdAt;

  UserProfile({
    required this.id,
    required this.name,
    this.designation,
    this.department,
    this.email,
    this.organizationId,
    this.organizationName,
    this.role = 'employee',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isAdmin => role == 'admin';

  UserProfile copyWith({
    String? id,
    String? name,
    String? designation,
    String? department,
    String? email,
    String? organizationId,
    String? organizationName,
    bool clearOrganization = false,
    String? role,
    DateTime? createdAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      organizationId: clearOrganization
          ? null
          : organizationId ?? this.organizationId,
      organizationName: clearOrganization
          ? null
          : organizationName ?? this.organizationName,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'designation': designation,
      'department': department,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Employee',
      designation: json['designation'] as String?,
      department: json['department'] as String?,
      email: json['email'] as String?,
      organizationId: json['organization_id'] as String?,
      organizationName: json['organization_name'] as String?,
      role: json['role'] as String? ?? 'employee',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}

String? _remoteText(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Applies a remote `profiles` row over the device's copy.
///
/// The local profile is a copy that starts as `Employee`, with no department, on
/// any device that has not seen this account before. Pushing it before reading
/// the remote row erases the name, designation and department the person set
/// elsewhere — so authentication has to merge remote first, then write back only
/// what the remote lacks.
///
/// Organisation and role are server-authoritative: the client never writes them,
/// so a remote `organization_id` of null means the person was removed from the
/// workspace and the local cache must follow rather than keep stale access.
UserProfile mergeRemoteProfile(UserProfile local, Map<String, dynamic> remote) {
  final organizationId = _remoteText(remote['organization_id']);
  return UserProfile(
    id: local.id,
    name: _remoteText(remote['name']) ?? local.name,
    designation: _remoteText(remote['designation']) ?? local.designation,
    department: _remoteText(remote['department']) ?? local.department,
    email: local.email,
    organizationId: organizationId,
    organizationName: organizationId == null ? null : local.organizationName,
    role: _remoteText(remote['role']) ?? local.role,
    createdAt: local.createdAt,
  );
}

/// Whether the merged profile holds something the remote row is missing.
///
/// Only these three fields are client-writable, so this is also the list that
/// may be pushed. An empty remote value that the local copy can fill is a first
/// sign-in from a device that had a profile before the account existed.
bool profileNeedsPush(UserProfile local, Map<String, dynamic> remote) {
  final missingName = _remoteText(remote['name']) == null;
  final missingDesignation = _remoteText(remote['designation']) == null;
  final missingDepartment = _remoteText(remote['department']) == null;
  return (missingName && local.name.trim().isNotEmpty) ||
      (missingDesignation && (local.designation?.trim().isNotEmpty ?? false)) ||
      (missingDepartment && (local.department?.trim().isNotEmpty ?? false));
}
