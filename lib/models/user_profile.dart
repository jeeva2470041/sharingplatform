import 'package:cloud_firestore/cloud_firestore.dart';

/// User profile model for accountability and trust
class UserProfile {
  final String id;
  final String userId;
  final String fullName;
  final String department;
  final String contactNumber;
  final String email;
  final String address; // hostel / block / room
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.department,
    required this.contactNumber,
    required this.email,
    required this.address,
    this.isCompleted = false,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if all required fields are filled
  bool get hasAllRequiredFields {
    return fullName.trim().isNotEmpty &&
        department.trim().isNotEmpty &&
        contactNumber.trim().isNotEmpty &&
        email.trim().isNotEmpty &&
        address.trim().isNotEmpty;
  }

  /// Create an empty profile for a new user
  factory UserProfile.empty(String userId, String email) {
    return UserProfile(
      id: userId,
      userId: userId,
      fullName: '',
      department: '',
      contactNumber: '',
      email: email,
      address: '',
      isCompleted: false,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'fullName': fullName,
      'department': department,
      'contactNumber': contactNumber,
      'email': email,
      'address': address,
      'isCompleted': isCompleted,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return UserProfile(
      id: doc.id,
      userId: data['userId'] ?? '',
      fullName: data['fullName'] ?? '',
      department: data['department'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      isCompleted: data['isCompleted'] ?? false,
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      updatedAt: parseTimestamp(data['updatedAt']),
    );
  }

  UserProfile copyWith({
    String? fullName,
    String? department,
    String? contactNumber,
    String? email,
    String? address,
    bool? isCompleted,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id,
      userId: userId,
      fullName: fullName ?? this.fullName,
      department: department ?? this.department,
      contactNumber: contactNumber ?? this.contactNumber,
      email: email ?? this.email,
      address: address ?? this.address,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
