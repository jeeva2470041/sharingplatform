import 'package:cloud_firestore/cloud_firestore.dart';

/// Status for individual item requests
enum ItemRequestStatus {
  pending,   // Request waiting for lender decision
  approved,  // Lender approved this request
  rejected,  // Lender rejected this request
  expired,   // Request expired (after 2 days)
  cancelled, // Requester cancelled the request
}

/// Model for tracking multiple requests per item
/// Allows lenders to receive up to 5 concurrent requests and choose one to approve
class ItemRequest {
  final String id;
  final String itemId;
  final String requesterId;
  final String? requesterName;
  final String? requesterEmail;
  final int borrowDurationDays;
  final double depositAmount;
  final ItemRequestStatus status;
  final DateTime createdAt;
  final DateTime expiresAt; // Auto-expires after 2 days
  final String? rejectionReason;

  /// Maximum requests allowed per item
  static const int maxRequestsPerItem = 5;
  
  /// Request expiry duration in days
  static const int expiryDays = 2;

  ItemRequest({
    required this.id,
    required this.itemId,
    required this.requesterId,
    this.requesterName,
    this.requesterEmail,
    required this.borrowDurationDays,
    required this.depositAmount,
    this.status = ItemRequestStatus.pending,
    required this.createdAt,
    required this.expiresAt,
    this.rejectionReason,
  });

  /// Check if request has expired
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Check if request is still actionable (pending and not expired)
  bool get isActionable => status == ItemRequestStatus.pending && !isExpired;

  /// Get time remaining until expiry
  Duration get timeUntilExpiry => expiresAt.difference(DateTime.now());

  /// Get human-readable expiry text
  String get expiryText {
    if (isExpired) return 'Expired';
    final remaining = timeUntilExpiry;
    if (remaining.inHours < 1) {
      return '${remaining.inMinutes} min left';
    } else if (remaining.inHours < 24) {
      return '${remaining.inHours}h left';
    } else {
      return '${remaining.inDays}d left';
    }
  }

  /// Get status text
  String get statusText {
    if (isExpired && status == ItemRequestStatus.pending) return 'Expired';
    switch (status) {
      case ItemRequestStatus.pending:
        return 'Pending';
      case ItemRequestStatus.approved:
        return 'Approved';
      case ItemRequestStatus.rejected:
        return 'Rejected';
      case ItemRequestStatus.expired:
        return 'Expired';
      case ItemRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  /// Create a new request with auto-calculated expiry
  factory ItemRequest.create({
    required String id,
    required String itemId,
    required String requesterId,
    String? requesterName,
    String? requesterEmail,
    required int borrowDurationDays,
    required double depositAmount,
  }) {
    final now = DateTime.now();
    return ItemRequest(
      id: id,
      itemId: itemId,
      requesterId: requesterId,
      requesterName: requesterName,
      requesterEmail: requesterEmail,
      borrowDurationDays: borrowDurationDays,
      depositAmount: depositAmount,
      status: ItemRequestStatus.pending,
      createdAt: now,
      expiresAt: now.add(const Duration(days: expiryDays)),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'itemId': itemId,
      'requesterId': requesterId,
      'requesterName': requesterName,
      'requesterEmail': requesterEmail,
      'borrowDurationDays': borrowDurationDays,
      'depositAmount': depositAmount,
      'status': status.index,
      'createdAt': Timestamp.fromDate(createdAt),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'rejectionReason': rejectionReason,
    };
  }

  factory ItemRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime createdAt = DateTime.now();
    if (data['createdAt'] != null) {
      final timestamp = data['createdAt'];
      if (timestamp is Timestamp) {
        createdAt = timestamp.toDate();
      }
    }

    DateTime expiresAt = createdAt.add(const Duration(days: expiryDays));
    if (data['expiresAt'] != null) {
      final timestamp = data['expiresAt'];
      if (timestamp is Timestamp) {
        expiresAt = timestamp.toDate();
      }
    }

    return ItemRequest(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      requesterId: data['requesterId'] ?? '',
      requesterName: data['requesterName'],
      requesterEmail: data['requesterEmail'],
      borrowDurationDays: data['borrowDurationDays'] ?? 1,
      depositAmount: (data['depositAmount'] ?? 0).toDouble(),
      status: ItemRequestStatus.values[data['status'] ?? 0],
      createdAt: createdAt,
      expiresAt: expiresAt,
      rejectionReason: data['rejectionReason'],
    );
  }

  ItemRequest copyWith({
    String? id,
    String? itemId,
    String? requesterId,
    String? requesterName,
    String? requesterEmail,
    int? borrowDurationDays,
    double? depositAmount,
    ItemRequestStatus? status,
    DateTime? createdAt,
    DateTime? expiresAt,
    String? rejectionReason,
  }) {
    return ItemRequest(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      requesterId: requesterId ?? this.requesterId,
      requesterName: requesterName ?? this.requesterName,
      requesterEmail: requesterEmail ?? this.requesterEmail,
      borrowDurationDays: borrowDurationDays ?? this.borrowDurationDays,
      depositAmount: depositAmount ?? this.depositAmount,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
