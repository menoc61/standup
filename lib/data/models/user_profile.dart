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
