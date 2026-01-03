import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/transaction.dart';
import '../models/item.dart';
import '../data/mock_data.dart';
import 'item_service.dart';

/// Service for managing the lending workflow with QR verification
/// Ensures credits are only deducted after physical handover confirmation
class TransactionService {
  static final _firestore = FirebaseFirestore.instance;
  static final _transactionsCollection = _firestore.collection('transactions');

  static String get _currentUserId {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Not authenticated');
    }
    return user.uid;
  }

  /// Sync wallet based on transactions from Firestore
  /// This is needed because wallets are stored locally in each browser.
  /// Recalculates locked deposits from ACTIVE transactions only.
  /// Sync wallet based on transactions from Firestore
  /// Properly handles Refund vs Transfer scenarios using tracking IDs and fallbacks.
  static Future<void> syncWalletFromTransactions() async {
    try {
      await MockData.loadWallet();
      final wallet = MockData.userWallet;
      bool walletChanged = false;

      // --- STRATEGY 1: Use Robust ID Tracking (For new transactions) ---
      if (wallet.activeTransactionIds.isNotEmpty) {
        // Create a copy to iterate
        final List<String> idsToCheck = List.from(wallet.activeTransactionIds);

        for (final tid in idsToCheck) {
          final doc = await _transactionsCollection.doc(tid).get();

          if (!doc.exists) {
            // Transaction gone? Likely deleted database. Remove tracking.
            // We won't refund automatically as it might be 'kept'.
            // Let legacy audit fix the locked amounts if needed.
            continue; // Don't remove yet, maybe connection error?
            // Actually doc.exists is false means it's definitely not there.
          }

          final transaction = LendingTransaction.fromFirestore(doc);

          if (transaction.status == TransactionStatus.completed) {
            if (transaction.completionType == 'returned') {
              // Explicitly refund to balance
              wallet.releaseDeposit(
                transaction.depositAmount,
                tid,
              ); // Removes ID
              debugPrint(
                '✅ Synced (ID): Refunded ₹${transaction.depositAmount} (Item Returned)',
              );
            } else {
              // Item Kept/Damaged: JUST Unlock (burn deposit)
              wallet.transferLockedDeposit(
                transaction.depositAmount,
                tid,
              ); // Removes ID
              debugPrint(
                '✅ Synced (ID): Cleared Locked ₹${transaction.depositAmount} (Item Kept/Damaged)',
              );
            }
            walletChanged = true;
          }
          // If Active, leave it alone.
        }
      }

      // --- STRATEGY 2: Legacy Fallback / Audit ---
      // This calculates what SHOULD be locked vs what IS locked.
      // Crucial for existing stuck transactions or legacy data.

      final activeTransactions = await _transactionsCollection
          .where('borrowerId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: TransactionStatus.active.index)
          .get();

      double targetLocked = 0;
      for (final doc in activeTransactions.docs) {
        targetLocked += LendingTransaction.fromFirestore(doc).depositAmount;
      }

      // If we differ significantly (e.g. Locked=30, Target=0)
      if ((wallet.lockedDeposit - targetLocked).abs() > 0.01) {
        debugPrint(
          '⚠️ Wallet Audit: Mismatch detected. Locked: ₹${wallet.lockedDeposit}, Target: ₹$targetLocked',
        );

        double difference =
            wallet.lockedDeposit - targetLocked; // e.g. 30 - 0 = +30 (Surplus)

        if (difference > 0) {
          // We have EXTRA locked money. Where should it go?
          // Only REFUND if we find PROOF of return.

          final recentReturns = await _transactionsCollection
              .where('borrowerId', isEqualTo: _currentUserId)
              .where('status', isEqualTo: TransactionStatus.completed.index)
              .where('completionType', isEqualTo: 'returned')
              //.orderBy('completedAt', descending: true) // Indexing issues likely
              .get();

          bool foundJustification = false;
          // Simple heuristic: just check if ANY recent return matches the amount roughly
          // This isn't perfect but better than blindly refunding everything
          for (final doc in recentReturns.docs) {
            final t = LendingTransaction.fromFirestore(doc);
            // Use a loose match or just assume the most recent return explains it?
            // If we check timestamps it's better but we don't have lastSyncTime.
            // So we assume if we have a mismatch, and we have a return, maybe it misses?

            // Safer Approach:
            // If we find a return of the EXACT amount.
            if ((t.depositAmount - difference).abs() < 0.01) {
              foundJustification = true;
              // Ideally we check if this ID is already processed? We can't know in Legacy mode.
              break;
            }
          }

          if (foundJustification) {
            // We found a return that likely explains the difference -> Refund
            wallet.balance += difference;
            debugPrint(
              '✅ Audit: Refunded ₹$difference to balance (Matched recent return)',
            );
          } else {
            // We found NO return explaining this. Assume it was 'Kept/Damaged'.
            // DO NOT REFUND. Just fix the locked amount.
            // This fixes the bug where "Damaged" caused an incorrect refund.
            debugPrint(
              '✅ Audit: Burned ₹$difference from locked (Assumed Kept/Damaged due to no Return record)',
            );
          }
        } else {
          // Locked < Target. We are missing locked funds.
          // Deduct from balance to cover it.
          wallet.balance += difference; // difference is negative
          debugPrint(
            '⚠️ Audit: Deducted ₹${difference.abs()} from balance to fix locked deposit',
          );
        }

        wallet.lockedDeposit = targetLocked;
        walletChanged = true;
      }

      if (walletChanged) {
        await MockData.saveWallet();
        debugPrint('💰 Wallet synced successfully');
      }
    } catch (e) {
      debugPrint('Wallet sync error: $e');
    }
  }

  /// Create a new lending request
  /// Status: REQUESTED - No credits are deducted at this stage
  static Future<LendingTransaction?> createRequest({
    required String itemId,
    required String itemName,
    required String lenderId,
    required double depositAmount,
    int? borrowDurationDays,
  }) async {
    // Safety: Prevent borrowing own items
    if (lenderId == _currentUserId) {
      throw Exception('Cannot request your own items');
    }

    final transactionId = _transactionsCollection.doc().id;

    final transaction = LendingTransaction(
      id: transactionId,
      itemId: itemId,
      itemName: itemName,
      lenderId: lenderId,
      borrowerId: _currentUserId,
      depositAmount: depositAmount,
      status: TransactionStatus.requested,
      createdAt: DateTime.now(),
      borrowDurationDays: borrowDurationDays,
    );

    await _transactionsCollection
        .doc(transactionId)
        .set(transaction.toFirestore());

    // Update item status to requested
    await ItemService.updateItemStatus(
      itemId,
      ItemStatus.requested,
      borrowerId: _currentUserId,
    );

    // Initialize chat document with both lender and borrower as participants
    // This ensures chat notifications work even before either user opens the chat
    try {
      // Fetch user names from profiles collection
      String borrowerName = 'User';
      String lenderName = 'User';
      
      try {
        final borrowerDoc = await _firestore.collection('profiles').doc(_currentUserId).get();
        if (borrowerDoc.exists) {
          borrowerName = borrowerDoc.data()?['fullName'] as String? ?? 'User';
        }
      } catch (e) {
        debugPrint('Failed to fetch borrower name: $e');
      }
      
      try {
        final lenderDoc = await _firestore.collection('profiles').doc(lenderId).get();
        if (lenderDoc.exists) {
          lenderName = lenderDoc.data()?['fullName'] as String? ?? 'User';
        }
      } catch (e) {
        debugPrint('Failed to fetch lender name: $e');
      }

      await _firestore.collection('chats').doc(itemId).set({
        'participantIds': [_currentUserId, lenderId], // For efficient querying
        'participants': {
          _currentUserId: {
            'userId': _currentUserId,
            'name': borrowerName,
            'joinedAt': FieldValue.serverTimestamp(),
          },
          lenderId: {
            'userId': lenderId,
            'name': lenderName,
            'joinedAt': FieldValue.serverTimestamp(),
          },
        },
        'itemId': itemId,
        'itemName': itemName,
      }, SetOptions(merge: true));
      debugPrint('✅ Chat initialized for item $itemId with names: $borrowerName, $lenderName');
    } catch (e) {
      debugPrint('Failed to initialize chat: $e');
    }

    return transaction;
  }

  // ========== PHASE 2: APPROVAL (Still no credit deduction) ==========

  /// Lender approves the request
  /// Status: APPROVED - Credits still not deducted, waiting for handover
  static Future<void> approveRequest(String transactionId) async {
    final doc = await _transactionsCollection.doc(transactionId).get();
    if (!doc.exists) throw Exception('Transaction not found');

    final transaction = LendingTransaction.fromFirestore(doc);

    // Only lender can approve
    if (transaction.lenderId != _currentUserId) {
      throw Exception('Only the lender can approve this request');
    }

    await _transactionsCollection.doc(transactionId).update({
      'status': TransactionStatus.approved.index,
    });

    // Update item status
    await ItemService.updateItemStatus(transaction.itemId, ItemStatus.approved);
  }

  /// Lender rejects the request
  static Future<void> rejectRequest(String transactionId) async {
    final doc = await _transactionsCollection.doc(transactionId).get();
    if (!doc.exists) throw Exception('Transaction not found');

    final transaction = LendingTransaction.fromFirestore(doc);

    await _transactionsCollection.doc(transactionId).update({
      'status': TransactionStatus.cancelled.index,
    });

    // Reset item to available
    await ItemService.rejectRequest(transaction.itemId);
  }

  // ========== PHASE 3: QR HANDOVER (Credits deducted here) ==========

  /// Lender initiates handover - generates QR code
  /// Called when lender clicks "Confirm Handover"
  static Future<String> initiateHandover(String transactionId) async {
    final doc = await _transactionsCollection.doc(transactionId).get();
    if (!doc.exists) throw Exception('Transaction not found');

    final transaction = LendingTransaction.fromFirestore(doc);

    // Only lender can initiate handover
    if (transaction.lenderId != _currentUserId) {
      throw Exception('Only the lender can initiate handover');
    }

    // Must be in approved state
    if (transaction.status != TransactionStatus.approved) {
      throw Exception('Transaction must be approved before handover');
    }

    // Generate QR code
    final qrCode = LendingTransaction.generateQrCode(transactionId);

    await _transactionsCollection.doc(transactionId).update({'qrCode': qrCode});

    return qrCode;
  }

  /// Borrower scans QR code to confirm handover
  /// THIS IS WHERE CREDITS ARE DEDUCTED - Only after QR confirmation
  static Future<void> confirmHandoverWithQR(String qrCode) async {
    // Find transaction by QR code
    final querySnapshot = await _transactionsCollection
        .where('qrCode', isEqualTo: qrCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid QR code. Please check and try again.');
    }

    final doc = querySnapshot.docs.first;
    final transaction = LendingTransaction.fromFirestore(doc);

    // Safety Check 1: Verify borrower is the one scanning
    if (transaction.borrowerId != _currentUserId) {
      throw Exception(
        'This QR code is not for you. It belongs to a different borrower.',
      );
    }

    // Safety Check 2: Prevent duplicate scans - must be in APPROVED state
    if (transaction.status == TransactionStatus.active) {
      throw Exception(
        'This handover was already confirmed. Credits are already locked.',
      );
    }

    if (transaction.status != TransactionStatus.approved) {
      throw Exception(
        'Transaction is not in the correct state. Current status: ${transaction.status.name}',
      );
    }

    // Load wallet from storage to ensure we have latest data
    await MockData.loadWallet();

    // Get borrower's wallet
    final borrowerWallet = MockData.getWalletForUser(transaction.borrowerId);

    // Safety Check 3: Verify sufficient balance
    if (borrowerWallet.balance < transaction.depositAmount) {
      throw Exception(
        'Insufficient balance. You need ₹${transaction.depositAmount.toStringAsFixed(0)} '
        'but only have ₹${borrowerWallet.balance.toStringAsFixed(0)} available.',
      );
    }

    // ========== ATOMIC UPDATE SECTION ==========
    // All updates happen together - if any fails, the operation fails

    try {
      // Step 1: Lock credits in borrower's wallet
      // This deducts from balance and adds to lockedDeposit
      borrowerWallet.lockDeposit(transaction.depositAmount, transaction.id);

      // Step 2: Persist wallet changes immediately
      await MockData.saveWallet();

      // Step 3: Calculate due date based on borrow duration
      DateTime? dueDate;
      if (transaction.borrowDurationDays != null && transaction.borrowDurationDays! > 0) {
        dueDate = DateTime.now().add(Duration(days: transaction.borrowDurationDays!));
      }

      // Step 4: Update transaction status to ACTIVE with handover timestamp
      await _transactionsCollection.doc(transaction.id).update({
        'status': TransactionStatus.active.index,
        'handoverAt': Timestamp.now(),
        'handoverConfirmed': true,
        'dueDate': dueDate != null ? Timestamp.fromDate(dueDate) : null,
      });

      // Step 5: Update item status to show it's actively borrowed
      await ItemService.updateItemStatus(transaction.itemId, ItemStatus.active);

      // Log for debugging
      debugPrint('✅ Handover confirmed for transaction ${transaction.id}');
      debugPrint('   Borrower: ${transaction.borrowerId}');
      debugPrint('   Deposit locked: ₹${transaction.depositAmount}');
      debugPrint('   New balance: ₹${borrowerWallet.balance}');
      debugPrint('   Locked deposit: ₹${borrowerWallet.lockedDeposit}');
      if (dueDate != null) {
        debugPrint('   Due date: $dueDate');
      }
    } catch (e) {
      // If transaction update fails after wallet update, we need to rollback
      // Release the locked deposit back to balance
      borrowerWallet.releaseDeposit(transaction.depositAmount, transaction.id);
      await MockData.saveWallet();

      throw Exception('Failed to complete handover: $e');
    }
  }

  // ========== PHASE 4: RETURN (QR-Based) ==========

  /// Borrower initiates return - generates Return QR code
  /// Called when borrower clicks "Return Item"
  /// NO wallet or transaction updates yet - only generates QR
  static Future<String> initiateReturn(String transactionId) async {
    final doc = await _transactionsCollection.doc(transactionId).get();
    if (!doc.exists) throw Exception('Transaction not found');

    final transaction = LendingTransaction.fromFirestore(doc);

    // Safety Check 1: Only borrower can initiate return
    if (transaction.borrowerId != _currentUserId) {
      throw Exception('Only the borrower can initiate return');
    }

    // Safety Check 2: Must be in ACTIVE state
    if (transaction.status != TransactionStatus.active) {
      throw Exception('Item is not currently borrowed');
    }

    // Safety Check 3: Prevent duplicate return QR generation
    if (transaction.returnQrCode != null &&
        transaction.returnQrCode!.isNotEmpty) {
      // Return existing QR if already generated
      return transaction.returnQrCode!;
    }

    // Generate Return QR code (different from handover QR)
    final returnQrCode = LendingTransaction.generateReturnQrCode(transactionId);

    // Save return QR to transaction (no status change yet)
    await _transactionsCollection.doc(transactionId).update({
      'returnQrCode': returnQrCode,
    });

    debugPrint('📋 Return QR generated for transaction $transactionId');
    return returnQrCode;
  }

  /// Lender scans Return QR and confirms item condition
  /// THIS IS WHERE DEPOSIT IS SETTLED
  /// returnSafely: true = refund to borrower, false = transfer to lender
  static Future<void> confirmReturnWithQR(
    String qrCode, {
    required bool returnedSafely,
  }) async {
    // Find transaction by Return QR code
    final querySnapshot = await _transactionsCollection
        .where('returnQrCode', isEqualTo: qrCode)
        .limit(1)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Invalid Return QR code. Please check and try again.');
    }

    final doc = querySnapshot.docs.first;
    final transaction = LendingTransaction.fromFirestore(doc);

    // Safety Check 1: Only LENDER can confirm return
    if (transaction.lenderId != _currentUserId) {
      throw Exception('Only the lender can confirm item return.');
    }

    // Safety Check 2: Prevent duplicate confirmations
    if (transaction.status == TransactionStatus.completed) {
      throw Exception(
        'This return was already confirmed. Deposit has been settled.',
      );
    }

    // Safety Check 3: Must be in ACTIVE state
    if (transaction.status != TransactionStatus.active) {
      throw Exception('Transaction is not in the correct state for return.');
    }

    // NOTE: Wallets are stored in SharedPreferences (local to each browser).
    // The lender's browser doesn't have access to the borrower's wallet data.
    // For production, wallets should be stored in Firestore.
    // For now, we trust the transaction status as the source of truth.

    await MockData.loadWallet();
    final lenderWallet = MockData.getWalletForUser(transaction.lenderId);

    try {
      String completionType;

      if (returnedSafely) {
        // REFUND: Borrower gets deposit back
        // The borrower's wallet will be updated when they refresh their browser
        completionType = 'returned';
        debugPrint('✅ Item returned safely - deposit will be refunded to borrower');
      } else {
        // CLAIM: Lender receives the deposit
        // Add deposit to lender's wallet (lender is on this browser)
        lenderWallet.receiveTransferredDeposit(transaction.depositAmount);
        await MockData.saveWallet();
        completionType = 'kept_or_damaged';
        debugPrint('✅ Deposit transferred to lender: ₹${transaction.depositAmount}');
      }

      // Update transaction to COMPLETED - this is the source of truth
      await _transactionsCollection.doc(transaction.id).update({
        'status': TransactionStatus.completed.index,
        'completedAt': Timestamp.now(),
        'completionType': completionType,
      });

      // Update item status
      if (returnedSafely) {
        await ItemService.returnItem(transaction.itemId);
      } else {
        await ItemService.settleItem(transaction.itemId);
      }

      debugPrint('✅ Return confirmed for transaction ${transaction.id}');
      debugPrint('   Completion type: $completionType');
      debugPrint('   Lender balance: ₹${lenderWallet.balance}');
    } catch (e) {
      throw Exception('Failed to complete return: $e');
    }
  }

  // Legacy methods kept for backward compatibility
  /// @deprecated Use initiateReturn and confirmReturnWithQR instead
  static Future<void> returnItem(String transactionId, {double? rating}) async {
    // This method is deprecated - use QR-based return instead
    throw Exception('Please use the QR-based return flow');
  }

  /// @deprecated Use confirmReturnWithQR with returnedSafely=false instead
  static Future<void> keepItem(String transactionId) async {
    // This method is deprecated - use QR-based return instead
    throw Exception('Please use the QR-based return flow');
  }

  // ========== STREAMS & QUERIES ==========

  /// Get transaction for an item (simplified query to avoid composite index)
  static Future<LendingTransaction?> getTransactionForItem(
    String itemId,
  ) async {
    // Simple query - just filter by itemId, then filter in code
    final querySnapshot = await _transactionsCollection
        .where('itemId', isEqualTo: itemId)
        .get();

    if (querySnapshot.docs.isEmpty) return null;

    // Find the most recent non-completed transaction
    final transactions = querySnapshot.docs
        .map((doc) => LendingTransaction.fromFirestore(doc))
        .where(
          (t) =>
              t.status != TransactionStatus.completed &&
              t.status != TransactionStatus.cancelled,
        )
        .toList();

    if (transactions.isEmpty) return null;

    // Sort by createdAt descending and return the first
    transactions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return transactions.first;
  }

  /// Stream of active transactions for current user (as borrower)
  static Stream<List<LendingTransaction>> get myBorrowingTransactionsStream {
    return _transactionsCollection
        .where('borrowerId', isEqualTo: _currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LendingTransaction.fromFirestore(doc))
              .where(
                (t) =>
                    t.status != TransactionStatus.completed &&
                    t.status != TransactionStatus.cancelled,
              )
              .toList(),
        );
  }

  /// Stream of active transactions for current user (as lender)
  static Stream<List<LendingTransaction>> get myLendingTransactionsStream {
    return _transactionsCollection
        .where('lenderId', isEqualTo: _currentUserId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LendingTransaction.fromFirestore(doc))
              .where(
                (t) =>
                    t.status != TransactionStatus.completed &&
                    t.status != TransactionStatus.cancelled,
              )
              .toList(),
        );
  }

  /// Get a single transaction by ID
  static Future<LendingTransaction?> getTransaction(
    String transactionId,
  ) async {
    final doc = await _transactionsCollection.doc(transactionId).get();
    if (!doc.exists) return null;
    return LendingTransaction.fromFirestore(doc);
  }
}
