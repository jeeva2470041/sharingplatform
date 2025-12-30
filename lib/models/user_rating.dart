import 'package:cloud_firestore/cloud_firestore.dart';

/// User rating model for tracking lender/borrower reviews
class UserRating {
  final String id;
  final String ratedBy; // User who gave the rating
  final String ratedTo; // User who received the rating
  final String transactionId;
  final String itemName;
  final double rating; // 1-5 stars
  final String? comment; // Optional review text
  final bool asLender; // Was the rated user the lender in this transaction?
  final DateTime createdAt;

  UserRating({
    required this.id,
    required this.ratedBy,
    required this.ratedTo,
    required this.transactionId,
    required this.itemName,
    required this.rating,
    this.comment,
    required this.asLender,
    required this.createdAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'ratedBy': ratedBy,
      'ratedTo': ratedTo,
      'transactionId': transactionId,
      'itemName': itemName,
      'rating': rating,
      'comment': comment,
      'asLender': asLender,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory UserRating.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? createdAt;
    if (data['createdAt'] != null && data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    }

    return UserRating(
      id: doc.id,
      ratedBy: data['ratedBy'] ?? '',
      ratedTo: data['ratedTo'] ?? '',
      transactionId: data['transactionId'] ?? '',
      itemName: data['itemName'] ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 0,
      comment: data['comment'],
      asLender: data['asLender'] ?? false,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}

/// Aggregated user trust score
class UserTrustScore {
  final String odId;
  final double overallRating;
  final int totalRatings;
  final double lenderRating;
  final int lenderRatingCount;
  final double borrowerRating;
  final int borrowerRatingCount;
  final int completedTransactions;
  final int onTimeReturns;

  UserTrustScore({
    required this.odId,
    required this.overallRating,
    required this.totalRatings,
    required this.lenderRating,
    required this.lenderRatingCount,
    required this.borrowerRating,
    required this.borrowerRatingCount,
    required this.completedTransactions,
    required this.onTimeReturns,
  });

  /// Calculate on-time return percentage
  double get onTimePercentage {
    if (completedTransactions == 0) return 100;
    return (onTimeReturns / completedTransactions) * 100;
  }

  /// Get trust level badge
  String get trustBadge {
    if (totalRatings < 3) return 'New User';
    if (overallRating >= 4.5 && totalRatings >= 10) return 'Trusted ⭐';
    if (overallRating >= 4.0) return 'Reliable';
    if (overallRating >= 3.0) return 'Average';
    return 'Needs Improvement';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'odId': odId,
      'overallRating': overallRating,
      'totalRatings': totalRatings,
      'lenderRating': lenderRating,
      'lenderRatingCount': lenderRatingCount,
      'borrowerRating': borrowerRating,
      'borrowerRatingCount': borrowerRatingCount,
      'completedTransactions': completedTransactions,
      'onTimeReturns': onTimeReturns,
    };
  }

  factory UserTrustScore.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserTrustScore(
      odId: doc.id,
      overallRating: (data['overallRating'] as num?)?.toDouble() ?? 0,
      totalRatings: data['totalRatings'] ?? 0,
      lenderRating: (data['lenderRating'] as num?)?.toDouble() ?? 0,
      lenderRatingCount: data['lenderRatingCount'] ?? 0,
      borrowerRating: (data['borrowerRating'] as num?)?.toDouble() ?? 0,
      borrowerRatingCount: data['borrowerRatingCount'] ?? 0,
      completedTransactions: data['completedTransactions'] ?? 0,
      onTimeReturns: data['onTimeReturns'] ?? 0,
    );
  }

  factory UserTrustScore.empty(String userId) {
    return UserTrustScore(
      odId: userId,
      overallRating: 0,
      totalRatings: 0,
      lenderRating: 0,
      lenderRatingCount: 0,
      borrowerRating: 0,
      borrowerRatingCount: 0,
      completedTransactions: 0,
      onTimeReturns: 0,
    );
  }
}
