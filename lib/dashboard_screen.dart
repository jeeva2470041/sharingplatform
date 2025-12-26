import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_item_screen.dart';
import 'marketplace_screen.dart';
import 'chat_screen.dart';
import 'qr_handover_screen.dart';
import 'return_qr_screen.dart';
import 'profile_screen.dart';
import 'transactions_screen.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'widgets/status_badge.dart';
import 'widgets/profile_guard.dart';
import 'services/auth_service.dart';
import 'services/item_service.dart';
import 'services/transaction_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  /// Get the current authenticated user's display name
  String _getUserDisplayName() {
    final user = FirebaseAuth.instance.currentUser;
    return user?.displayName ?? user?.email?.split('@').first ?? 'User';
  }

  /// Get the current authenticated user's ID
  String _getCurrentUserId() {
    return FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
  }

  /// Get items posted by current user (LENDER role)
  List<Item> _getMyPostedItems() {
    final currentUserId = _getCurrentUserId();
    return MockData.allItems
        .where((item) => item.ownerId == currentUserId)
        .toList();
  }

  /// Get items borrowed by current user (BORROWER role)
  List<Item> _getMyBorrowedItems() {
    final currentUserId = _getCurrentUserId();
    return MockData.allItems
        .where((item) => item.borrowerId == currentUserId)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    // Sync wallet from completed transactions
    // This handles the case where lender confirmed return on their browser
    TransactionService.syncWalletFromTransactions().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'My Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().logout();
              // StreamBuilder in main.dart handles redirect to login
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Welcome, ${_getUserDisplayName()}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.indigo.withOpacity(0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Lend & Borrow Made Simple',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFeatureRow('List items you want to share'),
                              const SizedBox(height: 12),
                              _buildFeatureRow(
                                'Request items by locking a small refundable deposit',
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureRow(
                                'Get your deposit back when the item is returned safely',
                              ),
                              const SizedBox(height: 12),
                              _buildFeatureRow(
                                'If the item is damaged or kept, the deposit is paid to the lender',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Wallet Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.teal.shade50,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.account_balance_wallet,
                          color: Colors.teal.shade700,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'My Wallet',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Balance',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${MockData.userWallet.balance.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Locked Deposit',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '₹${MockData.userWallet.lockedDeposit.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _ActionCard(
                    title: 'Post Item',
                    icon: Icons.add_circle_outline,
                    color: Colors.blue,
                    onTap: () async {
                      // Check profile completion before allowing lending
                      final canProceed =
                          await ProfileGuard.checkProfileComplete(
                            context,
                            actionType: 'lend',
                          );
                      if (!canProceed) return;

                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PostItemScreen(),
                        ),
                      );
                      setState(() {}); // Refresh dashboard after returning
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _ActionCard(
                    title: 'Browse Items',
                    icon: Icons.search,
                    color: Colors.green,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MarketplaceScreen(),
                        ),
                      );
                      setState(() {}); // Refresh dashboard after returning
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Transactions Card
            SizedBox(
              width: double.infinity,
              child: _ActionCard(
                title: 'Transactions',
                icon: Icons.history,
                color: Colors.purple,
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionsScreen(),
                    ),
                  );
                  setState(() {}); // Refresh dashboard after returning
                },
              ),
            ),
            const SizedBox(height: 32),
            // PENDING REQUESTS SECTION - Shows requests lender needs to approve
                        // Pending Requests Section (unchanged - keep as is)
            StreamBuilder<List<Item>>(
              stream: ItemService.pendingRequestsStream,
              builder: (context, pendingSnapshot) {
                final pendingItems = pendingSnapshot.data ?? [];
                if (pendingItems.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notification_important, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        const Text('Pending Requests', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.orange, borderRadius: BorderRadius.circular(12)),
                          child: Text('${pendingItems.length}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingItems.map((item) => _ActivityItemCard(item: item, isOwner: true, onUpdate: () {})),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),

            // NEW: Expandable Lent Items Section
            ExpansionTile(
              leading: const Icon(Icons.upload_outlined, color: Colors.teal),
              title: const Text(
                'Lent Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Items you have posted for lending'),
              initiallyExpanded: false, // Collapsed by default
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<List<Item>>(
                  stream: ItemService.myPostedItemsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No items lent yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }
                    return Column(
                      children: items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityItemCard(
                            item: item,
                            isOwner: true,
                            onUpdate: () {},
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 16),

            // NEW: Expandable Borrowed Items Section
            ExpansionTile(
              leading: const Icon(Icons.download_outlined, color: Colors.orange),
              title: const Text(
                'Borrowed Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Items you are currently borrowing'),
              initiallyExpanded: false, // Collapsed by default
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StreamBuilder<List<Item>>(
                  stream: ItemService.myBorrowedItemsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Text(
                          'No items borrowed yet',
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      );
                    }
                    return Column(
                      children: items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ActivityItemCard(
                            item: item,
                            isBorrowed: true,
                            onUpdate: () {},
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // Keep _buildFeatureRow, _ActionCard, and _ActivityItemCard unchanged

  Widget _buildFeatureRow(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, color: Colors.green, size: 20),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            textAlign:
                TextAlign.left, // Keep text valid, but the block is centered
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityItemCard extends StatefulWidget {
  final Item item;
  final bool isBorrowed;
  final bool isOwner;
  final VoidCallback onUpdate;
  const _ActivityItemCard({
    required this.item,
    required this.onUpdate,
    this.isBorrowed = false,
    this.isOwner = false,
  });

  @override
  State<_ActivityItemCard> createState() => _ActivityItemCardState();
}

class _ActivityItemCardState extends State<_ActivityItemCard> {
  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Calculator':
        return Icons.calculate_outlined;
      case 'Notes':
        return Icons.notes_outlined;
      case 'Book':
      default:
        return Icons.menu_book_outlined;
    }
  }

  Future<void> _approveRequest() async {
    try {
      // First, find the transaction for this item and approve it
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );
      if (transaction != null) {
        // Use TransactionService which updates both transaction and item status
        await TransactionService.approveRequest(transaction.id);
      } else {
        // Fallback to just updating item status
        await ItemService.approveRequest(widget.item.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Request approved! You can now generate QR for handover.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to approve: $e')));
    }
  }

  Future<void> _rejectRequest() async {
    try {
      // Find the transaction for this item and reject it
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );
      if (transaction != null) {
        await TransactionService.rejectRequest(transaction.id);
      } else {
        // Fallback to just updating item status
        await ItemService.rejectRequest(widget.item.id);
      }
      // Note: No deposit release needed - credits aren't locked until QR handover

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to reject: $e')));
    }
  }

  /// Settlement for damaged/kept items - transfers deposit from borrower to lender
  Future<void> _settleItem() async {
    try {
      final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      if (depositAmount > 0 && widget.item.borrowerId != null) {
        // Get borrower's and lender's wallets
        final borrowerWallet = MockData.getWalletForUser(
          widget.item.borrowerId!,
        );
        final lenderWallet = MockData.getWalletForUser(
          currentUserId,
        ); // Owner is the lender

        // Transfer locked deposit from borrower to lender
        if (borrowerWallet.transferLockedDeposit(depositAmount)) {
          lenderWallet.receiveTransferredDeposit(depositAmount);
        }
        await MockData.saveWallet();
      }

      await ItemService.settleItem(widget.item.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Item settled. Deposit of ₹$depositAmount transferred to your wallet.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to settle: $e')));
    }
  }

  void _openChat() {
    // Determine the other user based on context
    // If owner viewing, chat with borrower. If borrower viewing, chat with owner.
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final otherUserId = widget.isOwner
        ? (widget.item.borrowerId ?? 'unknown')
        : widget.item.ownerId;

    if (otherUserId == 'unknown' || otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open chat - no other user')),
      );
      return;
    }

    // Chat is ITEM-SPECIFIC - each item has its own chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          itemId: widget.item.id, // CRITICAL: Item-specific chat
          otherUserId: otherUserId,
          itemName: widget.item.name,
        ),
      ),
    );
  }

  /// Open QR handover screen for physical item verification
  Future<void> _openHandover({required bool isLender}) async {
    // Find transaction for this item
    try {
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );

      if (transaction == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active transaction found for this item'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => QrHandoverScreen(
            transactionId: transaction.id,
            isLender: isLender,
          ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Handover completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  /// Open QR return screen for secure item return
  Future<void> _openReturn({required bool isBorrower}) async {
    // Verify user is authenticated first
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to continue'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );

      if (transaction == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active transaction found for this item'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (context) => ReturnQrScreen(
            transactionId: transaction.id,
            isBorrower: isBorrower,
          ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      print('Return error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'Review Request',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A user wants to borrow this item.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _categoryIcon(widget.item.category),
                      color: Colors.teal,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Deposit: ₹${widget.item.deposit}',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _rejectRequest();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _approveRequest();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showRequestActions =
        widget.isOwner && widget.item.status == ItemStatus.requested;
    // Lender can initiate handover when approved
    final bool showLenderHandover =
        widget.isOwner && widget.item.status == ItemStatus.approved;
    // Borrower can scan QR when approved
    final bool showBorrowerHandover =
        widget.isBorrowed && widget.item.status == ItemStatus.approved;
    // Borrower can initiate return when active
    final bool showBorrowerReturn =
        widget.isBorrowed && widget.item.status == ItemStatus.active;
    // Lender can confirm return (scan borrower's return QR) when active
    final bool showLenderReturnConfirm =
        widget.isOwner && widget.item.status == ItemStatus.active;
    final bool isApproved = widget.item.status == ItemStatus.approved;
    final bool isActive = widget.item.status == ItemStatus.active;
    final bool canChat =
        (widget.item.status == ItemStatus.requested ||
        widget.item.status == ItemStatus.approved ||
        widget.item.status == ItemStatus.active);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isActive
            ? Border.all(color: Colors.teal.withOpacity(0.4), width: 2)
            : isApproved
            ? Border.all(color: Colors.green.withOpacity(0.3), width: 1)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.shade50
                        : Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _categoryIcon(widget.item.category),
                    color: isApproved ? Colors.green : Colors.teal,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              widget.item.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (canChat)
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              color: Colors.blue,
                              onPressed: _openChat,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Deposit: ₹${widget.item.deposit}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      if (isApproved && widget.isBorrowed)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 14,
                                color: Colors.green,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Approved',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!isApproved) ...[
                        const SizedBox(height: 8),
                        StatusBadge(status: widget.item.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Actions for lender when request is pending
            if (showRequestActions) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showReviewDialog,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Review Request'),
                ),
              ),
            ],
            // Lender handover action - show QR code
            if (showLenderHandover) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Credits will be locked from borrower only after QR verification',
                            style: TextStyle(
                              color: Colors.blue.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openHandover(isLender: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code, size: 20),
                    label: const Text('Confirm Handover (Show QR)'),
                  ),
                ],
              ),
            ],
            // Borrower handover action - scan QR code
            if (showBorrowerHandover) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scan the lender\'s QR code when you receive the item. Your credits will be locked.',
                            style: TextStyle(
                              color: Colors.orange.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openHandover(isLender: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan QR to Receive Item'),
                  ),
                ],
              ),
            ],
            // Borrower return action - generate Return QR
            if (showBorrowerReturn) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.teal.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 14,
                              color: Colors.teal.shade700,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '₹${widget.item.deposit} Locked',
                              style: TextStyle(
                                color: Colors.teal.shade700,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openReturn(isBorrower: true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.assignment_return, size: 20),
                    label: const Text('Return Item (Show QR)'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Show the Return QR to lender to get your deposit back',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
            // Lender return confirmation - scan Return QR
            if (showLenderReturnConfirm) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock, color: Colors.teal.shade700, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Deposit ₹${widget.item.deposit} locked from borrower',
                            style: TextStyle(
                              color: Colors.teal.shade800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => _openReturn(isBorrower: false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Confirm Return (Scan QR)'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Scan borrower\'s Return QR to verify item condition',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
