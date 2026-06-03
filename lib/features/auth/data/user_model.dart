import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  const UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.status,
    required this.isActive,
    this.gender,
    this.phone,
    this.teamId,
    this.employeeId,
    this.photoUrl,
    this.createdAt,
    this.approvedAt,
    this.approvedBy,
    this.rejectionReason,
    // Extended profile
    this.age,
    this.aadharNo,
    this.panCard,
    this.emergencyContactName,
    this.emergencyContactPhone,
    this.address,
  });

  final String  uid;
  final String  email;
  final String  displayName;
  final String  role;       // field_advisor | clerk | admin
  final String  status;     // pending | approved | rejected
  final bool    isActive;
  final String? gender;     // male | female | other
  final String? phone;
  final String? teamId;
  final String? employeeId;
  final String? photoUrl;
  final DateTime? createdAt;
  final DateTime? approvedAt;
  final String?   approvedBy;     // admin uid who approved/rejected
  final String?   rejectionReason;

  // Extended profile
  final int?    age;
  final String? aadharNo;           // stored masked e.g. XXXX-XXXX-1234
  final String? panCard;            // stored masked e.g. ABCXX1234X
  final String? emergencyContactName;
  final String? emergencyContactPhone;
  final String? address;

  // ── Deserialization ────────────────────────────────────────────────────────
  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid:              uid,
      email:            map['email']       as String? ?? '',
      displayName:      map['displayName'] as String? ?? '',
      role:             map['role']        as String? ?? 'field_advisor',
      status:           map['status']      as String? ?? 'approved',
      isActive:         map['isActive']    as bool?   ?? false,
      gender:           map['gender']      as String?,
      phone:            map['phone']       as String?,
      teamId:           map['teamId']      as String?,
      employeeId:       map['employeeId']  as String?,
      photoUrl:         map['photoUrl']    as String?,
      createdAt:        _toDateTime(map['createdAt']),
      approvedAt:       _toDateTime(map['approvedAt']),
      approvedBy:       map['approvedBy']      as String?,
      rejectionReason:  map['rejectionReason'] as String?,
      age:                    map['age']                    as int?,
      aadharNo:               map['aadharNo']               as String?,
      panCard:                map['panCard']                as String?,
      emergencyContactName:   map['emergencyContactName']   as String?,
      emergencyContactPhone:  map['emergencyContactPhone']  as String?,
      address:                map['address']                as String?,
    );
  }

  // ── Serialization ──────────────────────────────────────────────────────────
  Map<String, dynamic> toMap() {
    return {
      'uid':        uid,
      'email':      email,
      'displayName': displayName,
      'role':       role,
      'status':     status,
      'isActive':   isActive,
      if (gender   != null) 'gender':   gender,
      if (phone    != null) 'phone':    phone,
      if (teamId      != null) 'teamId':     teamId,
      if (employeeId  != null) 'employeeId': employeeId,
      if (photoUrl    != null) 'photoUrl':   photoUrl,
      'createdAt':  createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : FieldValue.serverTimestamp(),
      'approvedAt':       approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy':       approvedBy,
      'rejectionReason':  rejectionReason,
      if (age                   != null) 'age':                   age,
      if (aadharNo              != null) 'aadharNo':              aadharNo,
      if (panCard               != null) 'panCard':               panCard,
      if (emergencyContactName  != null) 'emergencyContactName':  emergencyContactName,
      if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
      if (address               != null) 'address':               address,
    };
  }

  // ── CopyWith ───────────────────────────────────────────────────────────────
  UserModel copyWith({
    String?   displayName,
    String?   role,
    String?   status,
    bool?     isActive,
    String?   gender,
    String?   phone,
    String?   teamId,
    String?   employeeId,
    String?   photoUrl,
    DateTime? approvedAt,
    String?   approvedBy,
    String?   rejectionReason,
    int?      age,
    String?   aadharNo,
    String?   panCard,
    String?   emergencyContactName,
    String?   emergencyContactPhone,
    String?   address,
  }) {
    return UserModel(
      uid:                    uid,
      email:                  email,
      displayName:            displayName            ?? this.displayName,
      role:                   role                   ?? this.role,
      status:                 status                 ?? this.status,
      isActive:               isActive               ?? this.isActive,
      gender:                 gender                 ?? this.gender,
      phone:                  phone                  ?? this.phone,
      teamId:                 teamId                 ?? this.teamId,
      employeeId:             employeeId             ?? this.employeeId,
      photoUrl:               photoUrl               ?? this.photoUrl,
      createdAt:              createdAt,
      approvedAt:             approvedAt             ?? this.approvedAt,
      approvedBy:             approvedBy             ?? this.approvedBy,
      rejectionReason:        rejectionReason        ?? this.rejectionReason,
      age:                    age                    ?? this.age,
      aadharNo:               aadharNo               ?? this.aadharNo,
      panCard:                panCard                ?? this.panCard,
      emergencyContactName:   emergencyContactName   ?? this.emergencyContactName,
      emergencyContactPhone:  emergencyContactPhone  ?? this.emergencyContactPhone,
      address:                address                ?? this.address,
    );
  }

  // ── Convenience getters ────────────────────────────────────────────────────
  bool get isFieldAdvisor => role == 'field_advisor';
  bool get isClerk        => role == 'clerk';
  bool get isAdmin        => role == 'admin';
  bool get isPending      => status == 'pending';
  bool get isApproved     => status == 'approved' && isActive;
  bool get isRejected     => status == 'rejected';

  // ── Private helpers ────────────────────────────────────────────────────────
  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String)    return DateTime.tryParse(value);
    return null;
  }

  @override
  String toString() =>
      'UserModel(uid: $uid, email: $email, role: $role, status: $status)';
}
