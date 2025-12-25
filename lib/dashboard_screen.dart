import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'post_item_screen.dart';
import 'marketplace_screen.dart';
import 'chat_screen.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'widgets/status_badge.dart';
import 'services/auth_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  void _switchUser() {
    setState(() {
      if (MockData.currentUserId == MockData.borrowerId) {
        MockData.currentUserId = MockData.lenderId;
      } else {
        MockData.currentUserId = MockData.borrowerId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isBorrower = MockData.currentUserId == MockData.borrowerId;
    return Scaffold(
      appBar: AppBar(
        title: Text('Dashboard (${isBorrower ? "Borrower" : "Lender"})'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Tooltip(
              message: 'Switch between borrower and lender',
              child: ElevatedButton.icon(
                onPressed: _switchUser,
                icon: const Icon(Icons.switch_account, size: 18),
                label: const Text('Switch User'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orangeAccent,
                  foregroundColor: Colors.black87,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
            onPressed: () async {
              await AuthService().logout();
              // No manual navigation needed - StreamBuilder in main.dart handles redirect
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
              'Welcome, ${FirebaseAuth.instance.currentUser?.displayName ?? FirebaseAuth.instance.currentUser?.email?.split('@').first ?? (isBorrower ? "Borrower" : "Lender")}!',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                              '\$${MockData.userWallet.balance.toStringAsFixed(2)}',
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
                              '\$${MockData.userWallet.lockedDeposit.toStringAsFixed(2)}',
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
            const Text(
              'Items I Posted',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (MockData.myPostedItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No items posted yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ...MockData.myPostedItems.map(
                (item) => _ActivityItemCard(
                  item: item,
                  isOwner: true,
                  onUpdate: () => setState(() {}),
                ),
              ),
            const SizedBox(height: 24),
            const Text(
              'Items I Requested',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (MockData.myRequestedItems.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text(
                    'No requested items yet',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              )
            else
              ...MockData.myRequestedItems.map(
                (item) => _ActivityItemCard(
                  item: item,
                  isRequested: true,
                  onUpdate: () => setState(() {}),
                ),
              ),
          ],
        ),
      ),
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
  final bool isRequested;
  final bool isOwner;
  final VoidCallback onUpdate;
  const _ActivityItemCard({
    required this.item,
    required this.onUpdate,
    this.isRequested = false,
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
    setState(() {
      widget.item.status = ItemStatus.approved;
    });
    await MockData.saveItems();
    widget.onUpdate();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request approved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  Future<void> _rejectRequest() async {
    // Unlock deposit if any
    final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
    if (depositAmount > 0) {
      MockData.userWallet.releaseDeposit(depositAmount);
      await MockData.saveWallet();
    }

    setState(() {
      widget.item.status = ItemStatus.available;
      widget.item.requestedBy = null;
    });
    await MockData.saveItems();
    widget.onUpdate();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Request rejected'),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          itemId: widget.item.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showActions =
        widget.isOwner && widget.item.status == ItemStatus.requested;
    final bool isApproved = widget.item.status == ItemStatus.approved;
    final bool canChat =
        (widget.item.status == ItemStatus.requested ||
            widget.item.status == ItemStatus.approved);

    return Card(
      color: widget.isRequested
          ? Colors.orange.shade50
          : (isApproved ? Colors.green.shade50 : null),
      shape: isApproved
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.green, width: 1.5),
            )
          : null,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: Colors.teal.shade50,
                child: Icon(
                  _categoryIcon(widget.item.category),
                  color: Colors.teal,
                ),
              ),
              title: Text(widget.item.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Deposit: \$${widget.item.deposit}'),
                  if (isApproved && widget.isRequested)
                    const Padding(
                      padding: EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: Colors.green,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Approved by lender',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (canChat)
                    IconButton(
                      icon: const Icon(Icons.chat_bubble_outline),
                      color: Colors.blue,
                      onPressed: _openChat,
                    ),
                  StatusBadge(status: widget.item.status),
                ],
              ),
            ),
            if (showActions) ...[
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _rejectRequest,
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Reject'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _approveRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                    ),
                    child: const Text('Approve'),
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
