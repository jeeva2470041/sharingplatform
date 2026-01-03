import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/item.dart';
import '../models/item_request.dart';

/// Exception thrown when a request operation fails due to race condition
class RequestConflictException implements Exception {
  final String message;
  final String code;

  RequestConflictException(this.message, {this.code = 'conflict'});

  @override
  String toString() => message;
}

/// Service for managing item requests with Firestore transactions
/// Handles multiple concurrent requests per item with conflict prevention
class ItemRequestService {
  static final _firestore = FirebaseFirestore.instance;
  static final _requestsCollection = _firestore.collection('item_requests');
  static final _itemsCollection = _firestore.collection('items');

  static String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    return user.uid;
  }

  /// Create a new request for an item using Firestore transaction
  /// Ensures atomic check of request count and version
  /// 
  /// Throws [RequestConflictException] if:
  /// - Item is no longer available (approved/active/deleted)
  /// - Request limit (5) has been reached
  /// - User already has a pending request for this item
  static Future<ItemRequest> createRequest({
    required String itemId,
    required int borrowDurationDays,
    required double depositAmount,
    String? requesterName,
    String? requesterEmail,
  }) async {
    final requestId = _requestsCollection.doc().id;
    
    // Check for existing request BEFORE the transaction (can't query inside transaction)
    final existingRequests = await _requestsCollection
        .where('itemId', isEqualTo: itemId)
        .where('requesterId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: ItemRequestStatus.pending.index)
        .get();
    
    if (existingRequests.docs.isNotEmpty) {
      throw RequestConflictException(
        'You already have a pending request for this item',
        code: 'duplicate_request',
      );
    }
    
    return await _firestore.runTransaction<ItemRequest>((transaction) async {
      // Step 1: Read item document
      final itemDoc = await transaction.get(_itemsCollection.doc(itemId));
      
      if (!itemDoc.exists) {
        throw RequestConflictException(
          'Item no longer exists',
          code: 'item_not_found',
        );
      }
      
      final itemData = itemDoc.data()!;
      final currentStatus = ItemStatus.values[itemData['status'] ?? 0];
      final currentRequestCount = itemData['requestCount'] ?? 0;
      final currentVersion = itemData['version'] ?? 0;
      final isDeleted = itemData['isDeleted'] ?? false;
      final ownerId = itemData['ownerId'] ?? '';
      
      // Step 2: Validate item state
      if (isDeleted) {
        throw RequestConflictException(
          'This item has been removed',
          code: 'item_deleted',
        );
      }
      
      if (ownerId == _currentUserId) {
        throw RequestConflictException(
          'You cannot request your own item',
          code: 'own_item',
        );
      }
      
      if (currentStatus != ItemStatus.available && 
          currentStatus != ItemStatus.requested) {
        throw RequestConflictException(
          'This item is no longer available for requests',
          code: 'item_unavailable',
        );
      }
      
      if (currentRequestCount >= Item.maxRequests) {
        throw RequestConflictException(
          'This item has reached the maximum number of requests (${Item.maxRequests}). Please try again later.',
          code: 'limit_reached',
        );
      }
      
      // Step 3: Create the request document
      final request = ItemRequest.create(
        id: requestId,
        itemId: itemId,
        requesterId: _currentUserId,
        requesterName: requesterName,
        requesterEmail: requesterEmail,
        borrowDurationDays: borrowDurationDays,
        depositAmount: depositAmount,
      );
      
      transaction.set(_requestsCollection.doc(requestId), request.toFirestore());
      
      // Step 4: Update item - increment request count, set status, increment version
      transaction.update(_itemsCollection.doc(itemId), {
        'status': ItemStatus.requested.index,
        'requestCount': currentRequestCount + 1,
        'version': currentVersion + 1,
      });
      
      debugPrint('✅ Request created: $requestId for item $itemId');
      debugPrint('   Request count: ${currentRequestCount + 1}/${Item.maxRequests}');
      
      return request;
    });
  }

  /// Approve a specific request using Firestore transaction
  /// Atomically: approves selected request, rejects all others, updates item
  /// 
  /// Returns the approved request
  /// Throws [RequestConflictException] if item state has changed
  static Future<ItemRequest> approveRequest({
    required String requestId,
    required String itemId,
  }) async {
    // Get all other pending requests BEFORE the transaction (can't query inside transaction)
    final otherRequests = await _requestsCollection
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: ItemRequestStatus.pending.index)
        .get();
    
    return await _firestore.runTransaction<ItemRequest>((transaction) async {
      // Step 1: Read item document
      final itemDoc = await transaction.get(_itemsCollection.doc(itemId));
      
      if (!itemDoc.exists) {
        throw RequestConflictException(
          'Item no longer exists',
          code: 'item_not_found',
        );
      }
      
      final itemData = itemDoc.data()!;
      final currentStatus = ItemStatus.values[itemData['status'] ?? 0];
      final currentVersion = itemData['version'] ?? 0;
      
      // Step 2: Validate item is still in requested state
      if (currentStatus != ItemStatus.requested) {
        throw RequestConflictException(
          'Item state has changed. Please refresh and try again.',
          code: 'state_changed',
        );
      }
      
      // Step 3: Read the request to approve
      final requestDoc = await transaction.get(_requestsCollection.doc(requestId));
      
      if (!requestDoc.exists) {
        throw RequestConflictException(
          'Request no longer exists',
          code: 'request_not_found',
        );
      }
      
      final request = ItemRequest.fromFirestore(requestDoc);
      
      if (request.status != ItemRequestStatus.pending) {
        throw RequestConflictException(
          'This request has already been processed',
          code: 'request_processed',
        );
      }
      
      if (request.isExpired) {
        throw RequestConflictException(
          'This request has expired',
          code: 'request_expired',
        );
      }
      
      // Step 4: Approve the selected request
      transaction.update(_requestsCollection.doc(requestId), {
        'status': ItemRequestStatus.approved.index,
      });
      
      // Step 5: Reject all other pending requests
      for (final doc in otherRequests.docs) {
        if (doc.id != requestId) {
          transaction.update(_requestsCollection.doc(doc.id), {
            'status': ItemRequestStatus.rejected.index,
            'rejectionReason': 'Another request was approved',
          });
        }
      }
      
      // Step 6: Update item - set approved status, set borrower, reset count, increment version
      transaction.update(_itemsCollection.doc(itemId), {
        'status': ItemStatus.approved.index,
        'borrowerId': request.requesterId,
        'requestCount': 0,
        'version': currentVersion + 1,
      });
      
      debugPrint('✅ Request $requestId approved for item $itemId');
      debugPrint('   ${otherRequests.docs.length - 1} other requests rejected');
      
      return request.copyWith(status: ItemRequestStatus.approved);
    });
  }

  /// Reject a specific request
  /// Decrements request count; if no more pending requests, resets item to available
  static Future<void> rejectRequest({
    required String requestId,
    required String itemId,
    String? reason,
  }) async {
    await _firestore.runTransaction((transaction) async {
      // Step 1: Read item document
      final itemDoc = await transaction.get(_itemsCollection.doc(itemId));
      
      if (!itemDoc.exists) return;
      
      final itemData = itemDoc.data()!;
      final currentRequestCount = itemData['requestCount'] ?? 0;
      final currentVersion = itemData['version'] ?? 0;
      
      // Step 2: Update the request status
      transaction.update(_requestsCollection.doc(requestId), {
        'status': ItemRequestStatus.rejected.index,
        'rejectionReason': reason ?? 'Request rejected by lender',
      });
      
      // Step 3: Decrement request count
      final newRequestCount = (currentRequestCount - 1).clamp(0, Item.maxRequests);
      
      // Step 4: If no more pending requests, reset item to available
      final updates = <String, dynamic>{
        'requestCount': newRequestCount,
        'version': currentVersion + 1,
      };
      
      if (newRequestCount == 0) {
        updates['status'] = ItemStatus.available.index;
        updates['borrowerId'] = null;
      }
      
      transaction.update(_itemsCollection.doc(itemId), updates);
      
      debugPrint('✅ Request $requestId rejected');
      debugPrint('   Remaining requests: $newRequestCount');
    });
  }

  /// Cancel own request (by requester)
  static Future<void> cancelRequest({
    required String requestId,
    required String itemId,
  }) async {
    // Verify the request belongs to current user
    final requestDoc = await _requestsCollection.doc(requestId).get();
    if (!requestDoc.exists) return;
    
    final request = ItemRequest.fromFirestore(requestDoc);
    if (request.requesterId != _currentUserId) {
      throw Exception('You can only cancel your own requests');
    }
    
    if (request.status != ItemRequestStatus.pending) {
      throw Exception('Only pending requests can be cancelled');
    }
    
    await _firestore.runTransaction((transaction) async {
      final itemDoc = await transaction.get(_itemsCollection.doc(itemId));
      
      if (!itemDoc.exists) return;
      
      final itemData = itemDoc.data()!;
      final currentRequestCount = itemData['requestCount'] ?? 0;
      final currentVersion = itemData['version'] ?? 0;
      
      // Update request status
      transaction.update(_requestsCollection.doc(requestId), {
        'status': ItemRequestStatus.cancelled.index,
      });
      
      // Decrement request count
      final newRequestCount = (currentRequestCount - 1).clamp(0, Item.maxRequests);
      
      final updates = <String, dynamic>{
        'requestCount': newRequestCount,
        'version': currentVersion + 1,
      };
      
      if (newRequestCount == 0) {
        updates['status'] = ItemStatus.available.index;
      }
      
      transaction.update(_itemsCollection.doc(itemId), updates);
    });
  }

  /// Clean up expired requests for an item
  /// Called when viewing item or periodically via Cloud Function
  static Future<int> cleanupExpiredRequests(String itemId) async {
    // Query OUTSIDE transaction (Firestore limitation)
    final pendingRequests = await _requestsCollection
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: ItemRequestStatus.pending.index)
        .get();
    
    final expiredRequestDocs = <DocumentSnapshot>[];
    
    for (final doc in pendingRequests.docs) {
      final request = ItemRequest.fromFirestore(doc);
      if (request.isExpired) {
        expiredRequestDocs.add(doc);
      }
    }
    
    if (expiredRequestDocs.isEmpty) return 0;
    
    int expiredCount = expiredRequestDocs.length;
    
    await _firestore.runTransaction((transaction) async {
      // Read item
      final itemDoc = await transaction.get(_itemsCollection.doc(itemId));
      if (!itemDoc.exists) return;
      
      final itemData = itemDoc.data()!;
      final currentRequestCount = itemData['requestCount'] ?? 0;
      final currentVersion = itemData['version'] ?? 0;
      
      // Mark expired requests
      for (final doc in expiredRequestDocs) {
        transaction.update(_requestsCollection.doc(doc.id), {
          'status': ItemRequestStatus.expired.index,
        });
      }
      
      // Update item request count
      final newRequestCount = (currentRequestCount - expiredCount).clamp(0, Item.maxRequests);
      
      final updates = <String, dynamic>{
        'requestCount': newRequestCount,
        'version': currentVersion + 1,
      };
      
      if (newRequestCount == 0) {
        final currentStatus = ItemStatus.values[itemData['status'] ?? 0];
        if (currentStatus == ItemStatus.requested) {
          updates['status'] = ItemStatus.available.index;
        }
      }
      
      transaction.update(_itemsCollection.doc(itemId), updates);
      
      debugPrint('✅ Cleaned up $expiredCount expired requests for item $itemId');
    });
    
    return expiredCount;
  }

  /// Stream of pending requests for a specific item (for lender's view)
  static Stream<List<ItemRequest>> getRequestsForItem(String itemId) {
    return _requestsCollection
        .where('itemId', isEqualTo: itemId)
        .where('status', isEqualTo: ItemRequestStatus.pending.index)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map((doc) => ItemRequest.fromFirestore(doc))
              .where((r) => !r.isExpired) // Filter out expired (not yet cleaned up)
              .toList();
          return requests;
        });
  }

  /// Get all pending requests for items owned by current user
  static Stream<List<ItemRequest>> get myItemRequestsStream {
    // First get all items owned by current user
    return _itemsCollection
        .where('ownerId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: ItemStatus.requested.index)
        .snapshots()
        .asyncMap((itemSnapshot) async {
          if (itemSnapshot.docs.isEmpty) return <ItemRequest>[];
          
          final itemIds = itemSnapshot.docs.map((doc) => doc.id).toList();
          
          // Get all pending requests for these items
          final requestSnapshot = await _requestsCollection
              .where('itemId', whereIn: itemIds)
              .where('status', isEqualTo: ItemRequestStatus.pending.index)
              .get();
          
          return requestSnapshot.docs
              .map((doc) => ItemRequest.fromFirestore(doc))
              .where((r) => !r.isExpired)
              .toList();
        });
  }

  /// Get requests made by current user
  static Stream<List<ItemRequest>> get myRequestsStream {
    return _requestsCollection
        .where('requesterId', isEqualTo: _currentUserId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => ItemRequest.fromFirestore(doc)).toList());
  }

  /// Get a single request by ID
  static Future<ItemRequest?> getRequest(String requestId) async {
    final doc = await _requestsCollection.doc(requestId).get();
    if (!doc.exists) return null;
    return ItemRequest.fromFirestore(doc);
  }

  /// Check if current user has a pending request for an item
  static Future<bool> hasExistingRequest(String itemId) async {
    final requests = await _requestsCollection
        .where('itemId', isEqualTo: itemId)
        .where('requesterId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: ItemRequestStatus.pending.index)
        .limit(1)
        .get();
    
    return requests.docs.isNotEmpty;
  }
}
