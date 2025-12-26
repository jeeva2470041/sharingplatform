import 'package:cloud_firestore/cloud_firestore.dart';

enum ItemStatus { available, requested, approved, active, returned, settled }

class Item {
  final String id;
  final String name;
  final String category;
  final String deposit;
  final String ownerId; // User who posted the item (LENDER)
  final String? ownerName; // Display name of the lender
  ItemStatus status;
  String? borrowerId; // User who borrowed/requested the item (BORROWER)
  double? rating;
  int? ratingCount;
  final DateTime? createdAt;
  final bool isDeleted; // Soft delete flag
  final DateTime? deletedAt; // When the item was deleted

  Item({
    required this.id,
    required this.name,
    required this.category,
    required this.deposit,
    required this.ownerId,
    this.ownerName,
    this.status = ItemStatus.available,
    this.borrowerId,
    this.rating,
    this.ratingCount,
    this.createdAt,
    this.isDeleted = false,
    this.deletedAt,
  });

  String get statusText {
    switch (status) {
      case ItemStatus.available:
        return 'Available';
      case ItemStatus.requested:
        return 'Requested';
      case ItemStatus.approved:
        return 'Approved';
      case ItemStatus.active:
        return 'Active';
      case ItemStatus.returned:
        return 'Returned';
      case ItemStatus.settled:
        return 'Settled';
    }
  }

  /// Convert to JSON for local storage (legacy support)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'deposit': deposit,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'status': status.index,
      'borrowerId': borrowerId,
      'rating': rating,
      'ratingCount': ratingCount,
      'createdAt': createdAt?.toIso8601String(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  /// Convert to Firestore document
  /// Uses local DateTime for instant UI updates (no serverTimestamp delay)
  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'deposit': deposit,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'status': status.index,
      'borrowerId': borrowerId,
      'rating': rating,
      'ratingCount': ratingCount,
      // Use Timestamp.fromDate for consistent Firestore storage
      // Local DateTime ensures instant UI updates without serverTimestamp delay
      'createdAt': createdAt != null
          ? Timestamp.fromDate(createdAt!)
          : Timestamp.now(),
      'isDeleted': isDeleted,
      'deletedAt': deletedAt != null ? Timestamp.fromDate(deletedAt!) : null,
    };
  }

  /// Create from JSON (legacy support)
  factory Item.fromJson(Map<String, dynamic> json) {
    return Item(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      deposit: json['deposit'],
      ownerId: json['ownerId'],
      ownerName: json['ownerName'],
      status: ItemStatus.values[json['status'] ?? 0],
      borrowerId: json['borrowerId'],
      rating: json['rating']?.toDouble(),
      ratingCount: json['ratingCount'],
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : null,
      isDeleted: json['isDeleted'] ?? false,
      deletedAt: json['deletedAt'] != null
          ? DateTime.parse(json['deletedAt'])
          : null,
    );
  }

  /// Create from Firestore document
  /// Handles pending writes where timestamp may be null
  factory Item.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // Handle createdAt - may be null for pending writes
    DateTime? createdAt;
    if (data['createdAt'] != null) {
      final timestamp = data['createdAt'];
      if (timestamp is Timestamp) {
        createdAt = timestamp.toDate();
      }
    }
    // Fallback to current time for documents with pending writes
    createdAt ??= DateTime.now();

    // Handle deletedAt timestamp
    DateTime? deletedAt;
    if (data['deletedAt'] != null) {
      final delTimestamp = data['deletedAt'];
      if (delTimestamp is Timestamp) {
        deletedAt = delTimestamp.toDate();
      }
    }

    return Item(
      id: doc.id,
      name: data['name'] ?? '',
      category: data['category'] ?? '',
      deposit: data['deposit'] ?? '0',
      ownerId: data['ownerId'] ?? '',
      ownerName: data['ownerName'],
      status: ItemStatus.values[data['status'] ?? 0],
      borrowerId: data['borrowerId'],
      rating: data['rating']?.toDouble(),
      ratingCount: data['ratingCount'],
      createdAt: createdAt,
      isDeleted: data['isDeleted'] ?? false,
      deletedAt: deletedAt,
    );
  }

  /// Create a copy with updated fields
  Item copyWith({
    String? id,
    String? name,
    String? category,
    String? deposit,
    String? ownerId,
    String? ownerName,
    ItemStatus? status,
    String? borrowerId,
    double? rating,
    int? ratingCount,
    DateTime? createdAt,
    bool? isDeleted,
    DateTime? deletedAt,
  }) {
    return Item(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      deposit: deposit ?? this.deposit,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      status: status ?? this.status,
      borrowerId: borrowerId ?? this.borrowerId,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      createdAt: createdAt ?? this.createdAt,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }
}
