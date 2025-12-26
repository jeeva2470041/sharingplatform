import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_item_screen.dart';
import 'marketplace_screen.dart';
import 'chat_screen.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'widgets/status_badge.dart';
import 'services/auth_service.dart';
import 'services/item_service.dart';

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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        elevation: 0,
        actions: [
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
            const SizedBox(height: 32),
            // PENDING REQUESTS SECTION - Shows requests lender needs to approve
            StreamBuilder<List<Item>>(
              stream: ItemService.pendingRequestsStream,
              builder: (context, pendingSnapshot) {
                final pendingItems = pendingSnapshot.data ?? [];
                if (pendingItems.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notification_important, color: Colors.orange, size: 24),
                        const SizedBox(width: 8),
                        const Text(
                          'Pending Requests',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${pendingItems.length}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...pendingItems.map(
                      (item) => _ActivityItemCard(
                        item: item,
                        isOwner: true,
                        onUpdate: () {},
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
            const Text(
              'Items I Posted',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Item>>(
              stream: ItemService.myPostedItemsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No items posted yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.map(
                    (item) => _ActivityItemCard(
                      item: item,
                      isOwner: true,
                      onUpdate: () {}, // No longer needed with StreamBuilder
                    ),
                  ).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Items I Borrowed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<List<Item>>(
              stream: ItemService.myBorrowedItemsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No borrowed items yet',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  );
                }
                return Column(
                  children: items.map(
                    (item) => _ActivityItemCard(
                      item: item,
                      isBorrowed: true,
                      onUpdate: () {}, // No longer needed with StreamBuilder
                    ),
                  ).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
      await ItemService.approveRequest(widget.item.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request approved'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
    }
  }

  Future<void> _rejectRequest() async {
    try {
      // Unlock deposit and refund to BORROWER's wallet (not current user's)
      final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
      if (depositAmount > 0 && widget.item.borrowerId != null) {
        final borrowerWallet = MockData.getWalletForUser(widget.item.borrowerId!);
        borrowerWallet.releaseDeposit(depositAmount);
        await MockData.saveWallet();
      }

      await ItemService.rejectRequest(widget.item.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e')),
      );
    }
  }

  /// Settlement for damaged/kept items - transfers deposit from borrower to lender
  Future<void> _settleItem() async {
    try {
      final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      if (depositAmount > 0 && widget.item.borrowerId != null) {
        // Get borrower's and lender's wallets
        final borrowerWallet = MockData.getWalletForUser(widget.item.borrowerId!);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to settle: $e')),
      );
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
    final bool showSettlementActions =
        widget.isOwner && widget.item.status == ItemStatus.approved;
    final bool isApproved = widget.item.status == ItemStatus.approved;
    final bool canChat =
        (widget.item.status == ItemStatus.requested ||
        widget.item.status == ItemStatus.approved);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isApproved
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
            // Settlement action for lender when item is approved but damaged/kept
            if (showSettlementActions) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Item Actions',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _settleItem,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange,
                      side: const BorderSide(color: Colors.orange),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.gavel, size: 18),
                    label: const Text('Settle (Claim Deposit)'),
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
