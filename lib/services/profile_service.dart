import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile.dart';

/// Service for managing user profiles
/// Profile completion is required before lending or borrowing
class ProfileService {
  static final _firestore = FirebaseFirestore.instance;
  static final _profilesCollection = _firestore.collection('profiles');

  static String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    return user.uid;
  }

  static String get _currentUserEmail {
    return FirebaseAuth.instance.currentUser?.email ?? '';
  }

  /// Get current user's profile (creates empty one if doesn't exist)
  static Future<UserProfile> getCurrentProfile() async {
    final doc = await _profilesCollection.doc(_currentUserId).get();

    if (!doc.exists) {
      // Create empty profile for new user
      final emptyProfile = UserProfile.empty(_currentUserId, _currentUserEmail);
      await _profilesCollection
          .doc(_currentUserId)
          .set(emptyProfile.toFirestore());
      return emptyProfile;
    }

    return UserProfile.fromFirestore(doc);
  }

  /// Check if current user's profile is complete
  /// This is the main guard function for lend/borrow actions
  static Future<bool> isProfileComplete() async {
    try {
      final profile = await getCurrentProfile();
      return profile.isCompleted && profile.hasAllRequiredFields;
    } catch (e) {
      debugPrint('Error checking profile: $e');
      return false;
    }
  }

  /// Save/update user profile
  static Future<UserProfile> saveProfile({
    required String fullName,
    required String department,
    required String year,
    required String contactNumber,
    required String email,
    required String address,
  }) async {
    // Validate all fields are filled
    if (fullName.trim().isEmpty ||
        department.trim().isEmpty ||
        year.trim().isEmpty ||
        contactNumber.trim().isEmpty ||
        email.trim().isEmpty ||
        address.trim().isEmpty) {
      throw Exception('All fields are required');
    }

    final now = DateTime.now();
    final existingDoc = await _profilesCollection.doc(_currentUserId).get();

    final profileData = <String, dynamic>{
      'userId': _currentUserId,
      'fullName': fullName.trim(),
      'department': department.trim(),
      'year': year.trim(),
      'contactNumber': contactNumber.trim(),
      'email': email.trim(),
      'address': address.trim(),
      'isCompleted': true,
      'createdAt': existingDoc.exists
          ? (existingDoc.data()?['createdAt'] ?? Timestamp.now())
          : Timestamp.now(),
      'updatedAt': Timestamp.fromDate(now),
    };

    await _profilesCollection.doc(_currentUserId).set(profileData);

    return UserProfile(
      id: _currentUserId,
      userId: _currentUserId,
      fullName: fullName.trim(),
      department: department.trim(),
      year: year.trim(),
      contactNumber: contactNumber.trim(),
      email: email.trim(),
      address: address.trim(),
      isCompleted: true,
      createdAt: existingDoc.exists
          ? (existingDoc.data()?['createdAt'] as Timestamp?)?.toDate() ?? now
          : now,
      updatedAt: now,
    );
  }

  /// Get profile for a specific user (for viewing other users)
  static Future<UserProfile?> getProfileForUser(String userId) async {
    final doc = await _profilesCollection.doc(userId).get();
    if (!doc.exists) return null;
    return UserProfile.fromFirestore(doc);
  }
}
