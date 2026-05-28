/// Represents a Kiba user stored in Firestore.
class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.phone,
    this.teamId,
    this.isActive = true,
    this.createdAt,
  });

  final String uid;
  final String email;
  final String displayName;
  final String role; // field_advisor | manager | admin
  final String? photoUrl;
  final String? phone;
  final String? teamId;
  final bool isActive;
  final DateTime? createdAt;

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      role: map['role'] as String? ?? 'field_advisor',
      photoUrl: map['photoUrl'] as String?,
      phone: map['phone'] as String?,
      teamId: map['teamId'] as String?,
      isActive: map['isActive'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      if (photoUrl != null) 'photoUrl': photoUrl,
      if (phone != null) 'phone': phone,
      if (teamId != null) 'teamId': teamId,
      'isActive': isActive,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? displayName,
    String? role,
    String? photoUrl,
    String? phone,
    String? teamId,
    bool? isActive,
  }) {
    return UserModel(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      teamId: teamId ?? this.teamId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  // Individual role checks
  bool get isFieldAdvisor => role == 'field_advisor';
  bool get isClerk => role == 'clerk';
  bool get isAdmin => role == 'admin';

  // FA and Clerk are equal — both are regular users who manage own data only
  bool get isRegularUser => isFieldAdvisor || isClerk;

  // Only admin can administer other users
  bool get canAdministerOthers => isAdmin;

  @override
  String toString() => 'UserModel(uid: $uid, email: $email, role: $role)';
}
