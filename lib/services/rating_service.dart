import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_rating.dart';
import '../models/transaction.dart';

/// Service for managing user ratings and trust scores
class RatingService {
  static final _firestore = FirebaseFirestore.instance;
  static final _ratingsCollection = _firestore.collection('user_ratings');
  static final _trustScoresCollection = _firestore.collection('trust_scores');

  static String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not authenticated');
    return user.uid;
  }

  /// Submit a rating for a user after transaction completion
  static Future<void> submitRating({
    required String ratedUserId,
    required String transactionId,
    required String itemName,
    required double rating,
    required bool ratedAsLender,
    String? comment,
  }) async {
    // Check if rating already exists for this transaction/direction
    final existingRating = await _ratingsCollection
        .where('transactionId', isEqualTo: transactionId)
        .where('ratedBy', isEqualTo: _currentUserId)
        .get();

    if (existingRating.docs.isNotEmpty) {
      throw Exception('You have already rated this transaction');
    }

    final ratingId = _ratingsCollection.doc().id;
    final newRating = UserRating(
      id: ratingId,
      ratedBy: _currentUserId,
      ratedTo: ratedUserId,
      transactionId: transactionId,
      itemName: itemName,
      rating: rating,
      comment: comment,
      asLender: ratedAsLender, // The rated user was the lender
      createdAt: DateTime.now(),
    );

    await _ratingsCollection.doc(ratingId).set(newRating.toFirestore());

    // Update trust score
    await _updateTrustScore(ratedUserId);
  }

  /// Update trust score for a user
  static Future<void> _updateTrustScore(String userId) async {
    // Get all ratings for this user
    final ratingsSnapshot = await _ratingsCollection
        .where('ratedTo', isEqualTo: userId)
        .get();

    if (ratingsSnapshot.docs.isEmpty) return;

    double totalRating = 0;
    double lenderRating = 0;
    int lenderCount = 0;
    double borrowerRating = 0;
    int borrowerCount = 0;

    for (final doc in ratingsSnapshot.docs) {
      final rating = UserRating.fromFirestore(doc);
      totalRating += rating.rating;

      if (rating.asLender) {
        lenderRating += rating.rating;
        lenderCount++;
      } else {
        borrowerRating += rating.rating;
        borrowerCount++;
      }
    }

    final totalCount = ratingsSnapshot.docs.length;
    final overallAvg = totalRating / totalCount;
    final lenderAvg = lenderCount > 0 ? lenderRating / lenderCount : 0.0;
    final borrowerAvg = borrowerCount > 0 ? borrowerRating / borrowerCount : 0.0;

    // Get completed transactions count
    final completedAsLender = await _firestore
        .collection('transactions')
        .where('lenderId', isEqualTo: userId)
        .where('status', isEqualTo: TransactionStatus.completed.index)
        .get();

    final completedAsBorrower = await _firestore
        .collection('transactions')
        .where('borrowerId', isEqualTo: userId)
        .where('status', isEqualTo: TransactionStatus.completed.index)
        .get();

    final completedTransactions =
        completedAsLender.docs.length + completedAsBorrower.docs.length;

    // Count on-time returns (where borrower returned before due date)
    int onTimeReturns = 0;
    for (final doc in completedAsBorrower.docs) {
      final t = LendingTransaction.fromFirestore(doc);
      if (t.completionType == 'returned' &&
          t.dueDate != null &&
          t.completedAt != null &&
          !t.completedAt!.isAfter(t.dueDate!)) {
        onTimeReturns++;
      }
    }

    final trustScore = UserTrustScore(
      odId: userId,
      overallRating: overallAvg,
      totalRatings: totalCount,
      lenderRating: lenderAvg,
      lenderRatingCount: lenderCount,
      borrowerRating: borrowerAvg,
      borrowerRatingCount: borrowerCount,
      completedTransactions: completedTransactions,
      onTimeReturns: onTimeReturns,
    );

    await _trustScoresCollection.doc(userId).set(trustScore.toFirestore());
  }

  /// Get trust score for a user
  static Future<UserTrustScore> getTrustScore(String userId) async {
    final doc = await _trustScoresCollection.doc(userId).get();
    if (doc.exists) {
      return UserTrustScore.fromFirestore(doc);
    }
    return UserTrustScore.empty(userId);
  }

  /// Get all ratings for a user
  static Future<List<UserRating>> getUserRatings(String userId) async {
    final snapshot = await _ratingsCollection
        .where('ratedTo', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map((doc) => UserRating.fromFirestore(doc)).toList();
  }

  /// Stream of ratings for a user
  static Stream<List<UserRating>> userRatingsStream(String userId) {
    return _ratingsCollection
        .where('ratedTo', isEqualTo: userId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => UserRating.fromFirestore(doc)).toList());
  }

  /// Check if current user has rated a transaction
  static Future<bool> hasRatedTransaction(String transactionId) async {
    final snapshot = await _ratingsCollection
        .where('transactionId', isEqualTo: transactionId)
        .where('ratedBy', isEqualTo: _currentUserId)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  /// Get rating given by current user for a transaction
  static Future<UserRating?> getMyRatingForTransaction(
      String transactionId) async {
    final snapshot = await _ratingsCollection
        .where('transactionId', isEqualTo: transactionId)
        .where('ratedBy', isEqualTo: _currentUserId)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return UserRating.fromFirestore(snapshot.docs.first);
  }
}
