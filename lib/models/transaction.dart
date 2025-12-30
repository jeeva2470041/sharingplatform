import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction status for the lending workflow
enum TransactionStatus {
  requested, // Borrower sent request, no credits deducted
  approved, // Lender approved, waiting for physical handover
  active, // QR verified, credits locked, item in use
  completed, // Item returned or kept, transaction finished
  cancelled, // Request was rejected or cancelled
}

/// Borrow duration options
enum BorrowDuration {
  oneDay,
  threeDays,
  oneWeek,
  twoWeeks,
  oneMonth,
  custom,
}

extension BorrowDurationExtension on BorrowDuration {
  String get label {
    switch (this) {
      case BorrowDuration.oneDay:
        return '1 Day';
      case BorrowDuration.threeDays:
        return '3 Days';
      case BorrowDuration.oneWeek:
        return '1 Week';
      case BorrowDuration.twoWeeks:
        return '2 Weeks';
      case BorrowDuration.oneMonth:
        return '1 Month';
      case BorrowDuration.custom:
        return 'Custom';
    }
  }

  int get days {
    switch (this) {
      case BorrowDuration.oneDay:
        return 1;
      case BorrowDuration.threeDays:
        return 3;
      case BorrowDuration.oneWeek:
        return 7;
      case BorrowDuration.twoWeeks:
        return 14;
      case BorrowDuration.oneMonth:
        return 30;
      case BorrowDuration.custom:
        return 0; // Custom will be set separately
    }
  }
}

/// Transaction model for tracking the lending lifecycle
/// Credits are only deducted after QR verification
class LendingTransaction {
  final String id;
  final String itemId;
  final String itemName;
  final String lenderId; // Item owner
  final String borrowerId; // Requester
  final double depositAmount; // Agreed credit amount
  final TransactionStatus status;
  final String? qrCode; // Generated QR for handover verification
  final String? returnQrCode; // Generated QR for return verification
  final DateTime createdAt;
  final DateTime? handoverAt; // When handover QR was scanned
  final DateTime? completedAt; // When returned/settled
  final String? completionType; // 'returned' or 'kept'
  final int? borrowDurationDays; // How many days to borrow
  final DateTime? dueDate; // When the item should be returned

  LendingTransaction({
    required this.id,
    required this.itemId,
    required this.itemName,
    required this.lenderId,
    required this.borrowerId,
    required this.depositAmount,
    this.status = TransactionStatus.requested,
    this.qrCode,
    this.returnQrCode,
    required this.createdAt,
    this.handoverAt,
    this.completedAt,
    this.completionType,
    this.borrowDurationDays,
    this.dueDate,
  });

  /// Generate a unique QR code for handover
  static String generateQrCode(String transactionId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'HANDOVER_${transactionId}_$timestamp';
  }

  /// Generate a unique QR code for return
  static String generateReturnQrCode(String transactionId) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'RETURN_${transactionId}_$timestamp';
  }

  /// Check if transaction is in a valid state for handover
  bool get canInitiateHandover => status == TransactionStatus.approved;

  /// Check if borrower can initiate return
  bool get canInitiateReturn => status == TransactionStatus.active;

  /// Check if transaction is already completed
  bool get isCompleted => status == TransactionStatus.completed;

  /// Check if item is overdue
  bool get isOverdue {
    if (status != TransactionStatus.active || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  /// Get days until due (negative if overdue)
  int get daysUntilDue {
    if (dueDate == null) return 0;
    return dueDate!.difference(DateTime.now()).inDays;
  }

  /// Get due status text
  String get dueStatusText {
    if (dueDate == null) return 'No due date';
    final days = daysUntilDue;
    if (days < 0) return 'Overdue by ${-days} day${-days == 1 ? '' : 's'}';
    if (days == 0) return 'Due today';
    if (days == 1) return 'Due tomorrow';
    return 'Due in $days days';
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'itemId': itemId,
      'itemName': itemName,
      'lenderId': lenderId,
      'borrowerId': borrowerId,
      'depositAmount': depositAmount,
      'status': status.index,
      'qrCode': qrCode,
      'returnQrCode': returnQrCode,
      'createdAt': Timestamp.fromDate(createdAt),
      'handoverAt': handoverAt != null ? Timestamp.fromDate(handoverAt!) : null,
      'completedAt': completedAt != null
          ? Timestamp.fromDate(completedAt!)
          : null,
      'completionType': completionType,
      'borrowDurationDays': borrowDurationDays,
      'dueDate': dueDate != null ? Timestamp.fromDate(dueDate!) : null,
    };
  }

  factory LendingTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    DateTime? parseTimestamp(dynamic value) {
      if (value == null) return null;
      if (value is Timestamp) return value.toDate();
      return null;
    }

    return LendingTransaction(
      id: doc.id,
      itemId: data['itemId'] ?? '',
      itemName: data['itemName'] ?? '',
      lenderId: data['lenderId'] ?? '',
      borrowerId: data['borrowerId'] ?? '',
      depositAmount: (data['depositAmount'] as num?)?.toDouble() ?? 0,
      status: TransactionStatus.values[data['status'] ?? 0],
      qrCode: data['qrCode'],
      returnQrCode: data['returnQrCode'],
      createdAt: parseTimestamp(data['createdAt']) ?? DateTime.now(),
      handoverAt: parseTimestamp(data['handoverAt']),
      completedAt: parseTimestamp(data['completedAt']),
      completionType: data['completionType'],
      borrowDurationDays: data['borrowDurationDays'],
      dueDate: parseTimestamp(data['dueDate']),
    );
  }

  LendingTransaction copyWith({
    String? id,
    String? itemId,
    String? itemName,
    String? lenderId,
    String? borrowerId,
    double? depositAmount,
    TransactionStatus? status,
    String? qrCode,
    String? returnQrCode,
    DateTime? createdAt,
    DateTime? handoverAt,
    DateTime? completedAt,
    String? completionType,
    int? borrowDurationDays,
    DateTime? dueDate,
  }) {
    return LendingTransaction(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      itemName: itemName ?? this.itemName,
      lenderId: lenderId ?? this.lenderId,
      borrowerId: borrowerId ?? this.borrowerId,
      depositAmount: depositAmount ?? this.depositAmount,
      status: status ?? this.status,
      qrCode: qrCode ?? this.qrCode,
      returnQrCode: returnQrCode ?? this.returnQrCode,
      createdAt: createdAt ?? this.createdAt,
      handoverAt: handoverAt ?? this.handoverAt,
      completedAt: completedAt ?? this.completedAt,
      completionType: completionType ?? this.completionType,
      borrowDurationDays: borrowDurationDays ?? this.borrowDurationDays,
      dueDate: dueDate ?? this.dueDate,
    );
  }
}
