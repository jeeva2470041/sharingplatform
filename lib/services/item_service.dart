import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/item.dart';

/// Service for managing items in Firestore
/// All items are stored in a shared 'items' collection
class ItemService {
  static final _firestore = FirebaseFirestore.instance;
  static final _itemsCollection = _firestore.collection('items');

  /// Get current user ID
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  /// Stream of ALL items (for admin/debugging)
  static Stream<List<Item>> get allItemsStream {
    return _itemsCollection.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => Item.fromFirestore(doc)).toList(),
    );
  }

  /// Stream of marketplace items (available items from OTHER users only)
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
                    item.ownerId != currentUserId && item.ownerId.isNotEmpty,
              )
              .toList();
        });
  }

  /// Stream of pending requests for current user's items (LENDER sees requests to approve)
  /// Filter at UI level to avoid auth timing issues
  static Stream<List<Item>> get pendingRequestsStream {
    return _itemsCollection
        .where('status', isEqualTo: ItemStatus.requested.index)
        .snapshots()
        .map((snapshot) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          return snapshot.docs
              .map((doc) => Item.fromFirestore(doc))
              .where((item) => item.ownerId == currentUserId)
              .toList();
        });
  }

  /// Stream of items posted by current user (LENDER role)
  static Stream<List<Item>> get myPostedItemsStream {
    return _itemsCollection.snapshots().map((snapshot) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc))
          .where((item) => item.ownerId == currentUserId)
          .toList();
    });
  }

  /// Stream of items borrowed by current user (BORROWER role)
  static Stream<List<Item>> get myBorrowedItemsStream {
    return _itemsCollection.snapshots().map((snapshot) {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
      return snapshot.docs
          .map((doc) => Item.fromFirestore(doc))
          .where((item) => item.borrowerId == currentUserId)
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

  /// Delete an item
  static Future<void> deleteItem(String itemId) async {
    await _itemsCollection.doc(itemId).delete();
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
