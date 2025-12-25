import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'widgets/status_badge.dart';
import 'widgets/rating_dialog.dart';
import 'chat_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _searchQuery = '';

  List<Item> get _filteredItems {
    if (_searchQuery.isEmpty) {
      return MockData.marketplaceItems;
    }
    return MockData.marketplaceItems
        .where(
          (item) =>
              item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              item.category.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Marketplace')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search items by name or category...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ),
          Expanded(
            child: _filteredItems.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text(
                        'No items available',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: _filteredItems.length,
                    itemBuilder: (context, index) {
                      final item = _filteredItems[index];
                      return ItemCard(
                        item: item,
                        onUpdate: () => setState(() {}),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class ItemCard extends StatefulWidget {
  final Item item;
  final VoidCallback onUpdate;
  const ItemCard({super.key, required this.item, required this.onUpdate});

  @override
  State<ItemCard> createState() => _ItemCardState();
}

class _ItemCardState extends State<ItemCard> {
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

  void _requestItem() {
    // Check if user is trying to borrow their own item
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    
    if (widget.item.ownerId == currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot borrow your own items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Confirm Request',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.item.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.item.category,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Deposit Required: \$${widget.item.deposit}',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet
                _processRequest();
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Confirm Request',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processRequest() async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    
    // Get borrower's wallet (current user)
    final borrowerWallet = MockData.getWalletForUser(currentUserId);
    final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
    
    // Check if borrower has enough balance
    if (depositAmount > 0 && borrowerWallet.balance < depositAmount) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Insufficient balance for deposit'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      widget.item.status = ItemStatus.requested;
      widget.item.borrowerId = currentUserId; // Set borrower to current user
    });

    // Lock deposit in borrower's wallet (deduct from balance, add to lockedDeposit)
    if (depositAmount > 0) {
      borrowerWallet.lockDeposit(depositAmount);
      await MockData.saveWallet();
    }

    await MockData.saveItems();

    // Update parent widget
    widget.onUpdate();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.teal, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Request Sent Successfully',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              'Lender will review your request',
              style: TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            if (depositAmount > 0) ...[
              const SizedBox(height: 8),
              Text(
                'Deposit of \$$depositAmount locked',
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _returnItem() {
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        itemName: widget.item.name,
        onRatingSubmitted: (rating) async {
          final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
          final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
          
          setState(() {
            widget.item.status = ItemStatus.returned;
            widget.item.rating =
                ((widget.item.rating ?? 0) * (widget.item.ratingCount ?? 0) +
                    rating) /
                ((widget.item.ratingCount ?? 0) + 1);
            widget.item.ratingCount = (widget.item.ratingCount ?? 0) + 1;
          });

          // Release deposit back to borrower (current user)
          if (depositAmount > 0) {
            final borrowerWallet = MockData.getWalletForUser(currentUserId);
            borrowerWallet.releaseDeposit(depositAmount);
            await MockData.saveWallet();
          }
          
          // Reset item for next borrower
          widget.item.borrowerId = null;
          widget.item.status = ItemStatus.available;
          await MockData.saveItems();

          // Update parent widget
          widget.onUpdate();
        },
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
    final bool canRequest = widget.item.status == ItemStatus.available;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final bool canReturn =
        widget.item.status == ItemStatus.approved &&
        widget.item.borrowerId == currentUserId;
    final bool canChat =
        widget.item.borrowerId == currentUserId &&
        (widget.item.status == ItemStatus.requested ||
            widget.item.status == ItemStatus.approved);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: Colors.teal.shade50,
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.item.category,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Deposit: \$${widget.item.deposit}',
                        style: const TextStyle(color: Colors.black87),
                      ),
                      if (widget.item.rating != null &&
                          widget.item.rating! > 0) ...[
                        const SizedBox(width: 12),
                        Icon(
                          Icons.star,
                          size: 16,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.item.rating!.toStringAsFixed(1),
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canChat)
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline),
                        color: Colors.blue,
                        onPressed: _openChat,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    const SizedBox(width: 8),
                    StatusBadge(status: widget.item.status),
                  ],
                ),
                if (canRequest || canReturn) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: canRequest ? _requestItem : _returnItem,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      canRequest
                          ? Icons.add_shopping_cart
                          : Icons.assignment_return,
                      size: 18,
                    ),
                    label: Text(canRequest ? 'Request' : 'Return'),
                  ),
                ] else if (widget.item.status == ItemStatus.requested ||
                    widget.item.status == ItemStatus.approved) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: null,
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(100, 36),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      disabledBackgroundColor: Colors.grey.shade200,
                      disabledForegroundColor: Colors.grey.shade500,
                    ),
                    icon: const Icon(Icons.lock_clock, size: 18),
                    label: Text(
                      widget.item.status == ItemStatus.requested
                          ? 'Requested'
                          : 'Approved',
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
