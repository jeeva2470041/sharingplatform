import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';
import 'transaction_service.dart';

/// Service for managing items in Firestore
/// All items are stored in a shared 'items' collection
class ItemService {
  static final _firestore = FirebaseFirestore.instance;
  static final _itemsCollection = _firestore.collection('items');

  /// Get current user ID
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  /// Stream of ALL items (for admin/debugging) - excludes deleted
  static Stream<List<Item>> get allItemsStream {
    return _itemsCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs
              .map((doc) => Item.fromFirestore(doc))
              .where((item) => !item.isDeleted)
              .toList(),
    );
  }

  /// Stream of marketplace items (available items from OTHER users only) - excludes deleted
  static Stream<List<Item>> get marketplaceItemsStream {
    return _itemsCollection
        .where('status', isEqualTo: ItemStatus.available.index)
        .snapshots()
        .map((snapshot) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          return snapshot.docs
              .map((doc) => Item.fromFirestore(doc))
              .where(
                (item) =>
                    item.ownerId != currentUserId && 
                    item.ownerId.isNotEmpty &&
                    !item.isDeleted,
              )
              .toList();
        });
  }

  /// Stream of pending requests for current user's items (LENDER sees requests to approve)
  /// Filter at UI level to avoid auth timing issues - excludes deleted
  static Stream<List<Item>> get pendingRequestsStream {
    return _itemsCollection
        .where('status', isEqualTo: ItemStatus.requested.index)
        .snapshots()
        .map((snapshot) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          return snapshot.docs
              .map((doc) => Item.fromFirestore(doc))
              .where((item) => item.ownerId == currentUserId && !item.isDeleted)
              .toList();
        });
  }

  /// Stream of items posted by current user (LENDER role) - excludes deleted
  static Stream<List<Item>> get myPostedItemsStream {
    return _itemsCollection.snapshots().map((snapshot) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc))
          .where((item) => item.ownerId == currentUserId && !item.isDeleted)
          .toList();
    });
  }

  /// Stream of items borrowed by current user (BORROWER role) - excludes deleted
  static Stream<List<Item>> get myBorrowedItemsStream {
    return _itemsCollection.snapshots().map((snapshot) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc))
          .where((item) => item.borrowerId == currentUserId && !item.isDeleted)
          .toList();
    });
  }

  /// Add a new item to Firestore
  static Future<void> addItem(Item item) async {
    await _itemsCollection.doc(item.id).set(item.toFirestore());
  }

  /// Update an existing item in Firestore
  static Future<void> updateItem(Item item) async {
    await _itemsCollection.doc(item.id).update(item.toFirestore());
  }

  /// Update item status
  static Future<void> updateItemStatus(
    String itemId,
    ItemStatus status, {
    String? borrowerId,
  }) async {
    final updates = <String, dynamic>{'status': status.index};
    if (borrowerId != null) {
      updates['borrowerId'] = borrowerId;
    }
    await _itemsCollection.doc(itemId).update(updates);
  }

  /// Request an item (set borrower and status)
  static Future<void> requestItem(String itemId) async {
    await _itemsCollection.doc(itemId).update({
      'status': ItemStatus.requested.index,
      'borrowerId': _currentUserId,
    });
  }

  /// Approve a request
  static Future<void> approveRequest(String itemId) async {
    await _itemsCollection.doc(itemId).update({
      'status': ItemStatus.approved.index,
    });
  }

  /// Reject a request (clear borrower, set available)
  static Future<void> rejectRequest(String itemId) async {
    await _itemsCollection.doc(itemId).update({
      'status': ItemStatus.available.index,
      'borrowerId': null,
    });
  }

  /// Return an item
  static Future<void> returnItem(
    String itemId, {
    double? newRating,
    int? newRatingCount,
  }) async {
    final updates = <String, dynamic>{
      'status': ItemStatus.available.index,
      'borrowerId': null,
    };
    if (newRating != null) {
      updates['rating'] = newRating;
    }
    if (newRatingCount != null) {
      updates['ratingCount'] = newRatingCount;
    }
    await _itemsCollection.doc(itemId).update(updates);
  }

  /// Settle an item (for damaged/kept)
  static Future<void> settleItem(String itemId) async {
    await _itemsCollection.doc(itemId).update({
      'status': ItemStatus.settled.index,
      'borrowerId': null,
    });
  }

  /// Check if an item can be deleted (no active transactions)
  /// Returns true if item is available and has no pending/active transactions
  static Future<bool> canDeleteItem(String itemId) async {
    // First get the item to check its status
    final item = await getItem(itemId);
    if (item == null) return false;
    
    // Only allow deletion if item is available
    if (item.status != ItemStatus.available) return false;
    
    // Check for any active transactions
    final transaction = await TransactionService.getTransactionForItem(itemId);
    return transaction == null;
  }

  /// Soft delete an item (sets isDeleted flag)
  /// Throws exception if item has active transactions
  static Future<void> softDeleteItem(String itemId) async {
    // Re-check if deletion is allowed (handles race conditions)
    final canDelete = await canDeleteItem(itemId);
    if (!canDelete) {
      throw Exception('Cannot delete item: it has active transactions or is not available');
    }
    
    await _itemsCollection.doc(itemId).update({
      'isDeleted': true,
      'deletedAt': Timestamp.now(),
    });
  }

  /// Hard delete an item (permanently removes from Firestore)
  /// Use with caution - prefer softDeleteItem for most cases
  static Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
  }

  /// Restore a soft-deleted item
  static Future<void> restoreItem(String itemId) async {
    await _itemsCollection.doc(itemId).update({
      'isDeleted': false,
      'deletedAt': null,
    });
  }

  /// Get a single item by ID (one-time fetch)
  static Future<Item?> getItem(String itemId) async {
    final doc = await _itemsCollection.doc(itemId).get();
    if (doc.exists) {
      return Item.fromFirestore(doc);
    }
    return null;
  }
}
