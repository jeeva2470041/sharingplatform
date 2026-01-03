import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'data/mock_data.dart';
import 'models/item.dart';
import 'models/item_request.dart';
import 'models/transaction.dart';
import 'widgets/status_badge.dart';
import 'widgets/rating_dialog.dart';
import 'widgets/profile_guard.dart';
import 'widgets/user_profile_info_dialog.dart';
import 'chat_screen.dart';
import 'services/item_service.dart';
import 'services/item_request_service.dart';
import 'services/transaction_service.dart';
import 'app_theme.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _searchQuery = '';

  List<Item> _filterItems(List<Item> items) {
    if (_searchQuery.isEmpty) {
      return items;
    }
    return items
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Find Items',
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontWeight: AppTheme.fontWeightBold,
            color: Colors.white,
          ),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.primaryPressed],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            color: AppTheme.cardBackground,
            padding: const EdgeInsets.fromLTRB(AppTheme.spacing16, 0, AppTheme.spacing16, AppTheme.spacing16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: AppTheme.inputDecoration(
                label: '',
                hint: 'Search items...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Item>>(
              stream: ItemService.marketplaceItemsStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final items = _filterItems(snapshot.data ?? []);

                if (items.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No items found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try searching for something else\nor post a request',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ItemCard(
                      item: item,
                      onUpdate: () {}, // No longer needed with StreamBuilder
                    );
                  },
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

  Widget _buildItemImage() {
    if (widget.item.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Image.network(
          widget.item.imageUrls.first,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return _buildFallbackIcon();
          },
        ),
      );
    }
    return _buildFallbackIcon();
  }

  Widget _buildFallbackIcon() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        _categoryIcon(widget.item.category),
        color: AppTheme.primary,
        size: 28,
      ),
    );
  }

  Future<void> _requestItem() async {
    // Check profile completion before allowing borrowing
    final canProceed = await ProfileGuard.checkProfileComplete(
      context,
      actionType: 'borrow',
    );
    if (!canProceed) return;

    // Check if user is trying to borrow their own item
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

    if (widget.item.ownerId == currentUserId) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You cannot borrow your own items'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show request dialog with duration selection
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BorrowRequestSheet(
        item: widget.item,
        onConfirm: (duration) => _processRequest(duration),
      ),
    );
  }

  Future<void> _processRequest(int borrowDurationDays) async {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final depositAmount = double.tryParse(widget.item.deposit) ?? 0;

    // Check if borrower has enough balance (for later, after QR verification)
    final borrowerWallet = MockData.getWalletForUser(currentUserId);
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

    try {
      // Create request using TransactionService - NO CREDITS DEDUCTED
      // Now uses ItemRequestService with Firestore transactions
      await TransactionService.createRequest(
        itemId: widget.item.id,
        itemName: widget.item.name,
        lenderId: widget.item.ownerId,
        depositAmount: depositAmount,
        borrowDurationDays: borrowDurationDays,
      );

      if (!mounted) return;

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 56),
              const SizedBox(height: 16),
              const Text(
                'Request Sent Successfully',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Your request has been added to the queue.\n'
                'The lender will review all requests and choose one.\n'
                'Request expires in ${ItemRequest.expiryDays} days.',
                style: const TextStyle(color: Colors.black54),
                textAlign: TextAlign.center,
              ),
              if (depositAmount > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Deposit: ₹$depositAmount (not yet deducted)',
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
    } on RequestConflictException catch (e) {
      if (!mounted) return;
      
      // Handle specific conflict errors with appropriate messages
      String message;
      Color backgroundColor;
      
      switch (e.code) {
        case 'limit_reached':
          message = 'This item has reached the maximum number of requests. Please try again later.';
          backgroundColor = Colors.orange;
          break;
        case 'item_unavailable':
          message = 'This item was just approved for another borrower.';
          backgroundColor = Colors.red;
          break;
        case 'duplicate_request':
          message = 'You already have a pending request for this item.';
          backgroundColor = Colors.orange;
          break;
        case 'item_deleted':
          message = 'This item has been removed by the owner.';
          backgroundColor = Colors.red;
          break;
        default:
          message = e.message;
          backgroundColor = Colors.red;
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to request item: $e')));
    }
  }

  void _returnItem() {
    // Note: This is a simplified return flow without QR verification.
    // The proper flow uses ReturnQrScreen which includes user rating.
    showDialog(
      context: context,
      builder: (context) => RatingDialog(
        itemName: widget.item.name,
        ratedUserName: widget.item.ownerName ?? 'the lender',
        isRatingLender: true, // Borrower rating lender
        onRatingSubmitted: (rating, comment) async {
          final currentUserId =
              FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
          final depositAmount = double.tryParse(widget.item.deposit) ?? 0;

          try {
            // Calculate new rating for item
            final newRating =
                ((widget.item.rating ?? 0) * (widget.item.ratingCount ?? 0) +
                    rating) /
                ((widget.item.ratingCount ?? 0) + 1);
            final newRatingCount = (widget.item.ratingCount ?? 0) + 1;

            // Update item in Firestore
            await ItemService.returnItem(
              widget.item.id,
              newRating: newRating,
              newRatingCount: newRatingCount,
            );

            // Release deposit back to borrower (current user)
            if (depositAmount > 0) {
              final borrowerWallet = MockData.getWalletForUser(currentUserId);
              borrowerWallet.releaseDeposit(depositAmount);
              await MockData.saveWallet();
            }
          } catch (e) {
            debugPrint('Failed to return item: $e');
          }
        },
      ),
    );
  }

  void _openChat() {
    // In marketplace, current user is borrower, other user is the owner/lender
    // Chat is ITEM-SPECIFIC - each item has its own chat
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          itemId: widget.item.id, // CRITICAL: Item-specific chat
          otherUserId: widget.item.ownerId,
          otherUserName: widget.item.ownerName ?? 'Lender',
          itemName: widget.item.name,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Check if item can accept requests
    final bool canAcceptRequests = widget.item.canAcceptRequests;
    // Check if current user can request (item available/requestable and not own item)
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final bool canRequest = canAcceptRequests && widget.item.ownerId != currentUserId;
    final bool canReturn =
        widget.item.status == ItemStatus.approved &&
        widget.item.borrowerId == currentUserId;
    final bool canChat =
        widget.item.borrowerId == currentUserId &&
        (widget.item.status == ItemStatus.requested ||
            widget.item.status == ItemStatus.approved);
    
    // Check if user already has a pending request
    final bool hasExistingRequest = widget.item.status == ItemStatus.requested &&
        widget.item.borrowerId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
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
                // Item image or category icon with request count badge
                Stack(
                  children: [
                    _buildItemImage(),
                    // Show request count badge if there are pending requests
                    if (widget.item.requestCount > 0)
                      Positioned(
                        right: -4,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: widget.item.requestCount >= Item.maxRequests 
                                ? Colors.red 
                                : Colors.orange,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                          child: Text(
                            '${widget.item.requestCount}/${Item.maxRequests}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
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
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusBadge(status: widget.item.status),
                        ],
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () {
                          UserProfileInfoDialog.show(
                            context,
                            userId: widget.item.ownerId,
                            title: 'Lender Info',
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey.shade500,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  'Lender: ${widget.item.ownerName ?? 'Unknown'}',
                                  style: TextStyle(
                                    color: AppTheme.primary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.info_outline,
                                  size: 12,
                                  color: AppTheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.item.category,
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shield_outlined,
                                  size: 14,
                                  color: Colors.orange.shade800,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Deposit: ₹${widget.item.deposit}',
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (widget.item.rating != null &&
                              widget.item.rating! > 0) ...[
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.star_rounded,
                                  size: 16,
                                  color: Colors.amber.shade700,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  widget.item.rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (canRequest ||
                canReturn ||
                canChat ||
                hasExistingRequest ||
                widget.item.status == ItemStatus.requested ||
                widget.item.status == ItemStatus.approved) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (canChat)
                    TextButton.icon(
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      label: const Text('Chat'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey.shade600,
                      ),
                      onPressed: _openChat,
                    )
                  else
                    const Spacer(),

                  if (canReturn)
                    ElevatedButton(
                      onPressed: _returnItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Return Item',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (canRequest)
                    ElevatedButton(
                      onPressed: _requestItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.item.requestCount > 0 
                            ? 'Join Queue (${widget.item.requestCount}/${Item.maxRequests})'
                            : 'Request Item',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    )
                  else if (hasExistingRequest)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Request Submitted',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.item.requestCount >= Item.maxRequests)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.block,
                            size: 16,
                            color: Colors.red.shade700,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Queue Full',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.item.status == ItemStatus.requested)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.access_time_filled,
                            size: 16,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${widget.item.requestCount} Pending',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (widget.item.status == ItemStatus.approved)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppTheme.success,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Approved',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppTheme.success,
                            ),
                          ),
                        ],
                      ),
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

/// Bottom sheet for selecting borrow duration and confirming request
class _BorrowRequestSheet extends StatefulWidget {
  final Item item;
  final Function(int) onConfirm;

  const _BorrowRequestSheet({
    required this.item,
    required this.onConfirm,
  });

  @override
  State<_BorrowRequestSheet> createState() => _BorrowRequestSheetState();
}

class _BorrowRequestSheetState extends State<_BorrowRequestSheet> {
  BorrowDuration _selectedDuration = BorrowDuration.oneWeek;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirm Borrow Request',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Item info card
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
                      'Deposit Required: ₹${widget.item.deposit}',
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
          const SizedBox(height: 20),
          
          // Duration selection
          const Text(
            'Select Borrow Duration',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BorrowDuration.values
                .where((d) => d != BorrowDuration.custom)
                .map((duration) => _buildDurationChip(duration))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Due date: ${_calculateDueDate()}',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 24),
          
          // Confirm button
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              widget.onConfirm(_selectedDuration.days);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Confirm Request (${_selectedDuration.label})',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationChip(BorrowDuration duration) {
    final isSelected = _selectedDuration == duration;
    return ChoiceChip(
      label: Text(duration.label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedDuration = duration);
        }
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  String _calculateDueDate() {
    final dueDate = DateTime.now().add(Duration(days: _selectedDuration.days));
    return '${dueDate.day}/${dueDate.month}/${dueDate.year}';
  }
}
