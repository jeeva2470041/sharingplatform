import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import 'transaction_service.dart';

/// Service for managing items in Firestore
/// All items are stored in a shared 'items' collection
class ItemService {
  static final _firestore = FirebaseFirestore.instance;
  static final _itemsCollection = _firestore.collection('items');
  static final _storage = FirebaseStorage.instance;

  /// Get current user ID
  static String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  /// Upload image to Firebase Storage and return download URL
  static Future<String> uploadItemImage(
    Uint8List imageBytes,
    String itemId,
    int imageIndex,
  ) async {
    final ref = _storage.ref().child('items/$itemId/image_$imageIndex.jpg');
    
    final metadata = SettableMetadata(
      contentType: 'image/jpeg',
      customMetadata: {'uploadedBy': _currentUserId},
    );
    
    await ref.putData(imageBytes, metadata);
    return await ref.getDownloadURL();
  }

  /// Upload multiple images and return list of URLs
  static Future<List<String>> uploadItemImages(
    List<Uint8List> images,
    String itemId,
  ) async {
    final urls = <String>[];
    for (int i = 0; i < images.length; i++) {
      final url = await uploadItemImage(images[i], itemId, i);
      urls.add(url);
    }
    return urls;
  }

  /// Delete all images for an item
  static Future<void> deleteItemImages(String itemId) async {
    try {
      final ref = _storage.ref().child('items/$itemId');
      final result = await ref.listAll();
      for (final item in result.items) {
        await item.delete();
      }
    } catch (e) {
      // Ignore errors if folder doesn't exist
      debugPrint('Error deleting item images: $e');
    }
  }

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

  /// Stream of marketplace items (available items OR items with pending requests that can accept more)
  /// Excludes own items and deleted items
  static Stream<List<Item>> get marketplaceItemsStream {
    // Query items that are either available or have pending requests (requestCount < 5)
    // We need to get both available and requested items, then filter
    return _itemsCollection
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
          return snapshot.docs
              .map((doc) => Item.fromFirestore(doc))
              .where((item) {
                // Exclude own items
                if (item.ownerId == currentUserId || item.ownerId.isEmpty) {
                  return false;
                }
                // Exclude deleted items
                if (item.isDeleted) {
                  return false;
                }
                // Include available items
                if (item.status == ItemStatus.available) {
                  return true;
                }
                // Include requested items that can still accept requests
                if (item.status == ItemStatus.requested && 
                    item.requestCount < Item.maxRequests) {
                  return true;
                }
                return false;
              })
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
