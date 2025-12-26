import 'package:cloud_firestore/cloud_firestore.dart';

/// Transaction status for the lending workflow
enum TransactionStatus {
  requested, // Borrower sent request, no credits deducted
  approved, // Lender approved, waiting for physical handover
  active, // QR verified, credits locked, item in use
  completed, // Item returned or kept, transaction finished
  cancelled, // Request was rejected or cancelled
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
    );
  }
}
