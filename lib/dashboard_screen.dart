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
import 'widgets/notification_dropdown.dart';
import 'services/auth_service.dart';
import 'services/item_service.dart';
import 'services/transaction_service.dart';
import 'services/profile_service.dart';
import 'app_theme.dart';

class DashboardScreen extends StatefulWidget {
  final String? highlightItemId;
  final String? highlightSection; // 'lent' or 'borrowed'
  
  const DashboardScreen({
    super.key,
    this.highlightItemId,
    this.highlightSection,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ExpansibleController _lentTileController = ExpansibleController();
  final ExpansibleController _borrowedTileController = ExpansibleController();
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = {};
  String? _highlightItemId;

  @override
  void initState() {
    super.initState();
    _highlightItemId = widget.highlightItemId;
    
    // Auto-expand the relevant section and scroll to item after build
    if (widget.highlightSection != null && widget.highlightItemId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.highlightSection == 'lent') {
          _lentTileController.expand();
        } else if (widget.highlightSection == 'borrowed') {
          _borrowedTileController.expand();
        }
        
        // Wait for expansion animation and data load, then scroll to item
        Future.delayed(const Duration(milliseconds: 800), () {
          _scrollToHighlightedItem();
        });
        
        // Clear highlight after 4 seconds (visual effect only, keeps scroll position)
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _highlightItemId = null;
            });
          }
        });
      });
    }
    
    // Sync wallet from completed transactions (delayed to not interfere with scroll)
    Future.delayed(const Duration(milliseconds: 1500), () {
      TransactionService.syncWalletFromTransactions().then((_) {
        if (mounted) setState(() {});
      });
    });
  }

  void _scrollToHighlightedItem() {
    if (_highlightItemId == null) return;
    
    final key = _itemKeys[_highlightItemId];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
        alignment: 0.3, // Position item 30% from top
      );
    } else {
      // Retry after a short delay if context not yet available
      Future.delayed(const Duration(milliseconds: 300), () {
        final retryKey = _itemKeys[_highlightItemId];
        if (retryKey?.currentContext != null && mounted) {
          Scrollable.ensureVisible(
            retryKey!.currentContext!,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeInOut,
            alignment: 0.3,
          );
        }
      });
    }
  }

  GlobalKey _getKeyForItem(String itemId) {
    _itemKeys.putIfAbsent(itemId, () => GlobalKey());
    return _itemKeys[itemId]!;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
  // ignore: unused_element
  List<Item> _getMyPostedItems() {
    final currentUserId = _getCurrentUserId();
    return MockData.allItems
        .where((item) => item.ownerId == currentUserId)
        .toList();
  }

  /// Get items borrowed by current user (BORROWER role)
  // ignore: unused_element
  List<Item> _getMyBorrowedItems() {
    final currentUserId = _getCurrentUserId();
    return MockData.allItems
        .where((item) => item.borrowerId == currentUserId)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // Full-width gradient header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primary,
                  AppTheme.primaryHover,
                ],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // App bar row
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spacing16,
                      vertical: AppTheme.spacing8,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.school, color: Colors.white, size: 24),
                        const SizedBox(width: AppTheme.spacing8),
                        const Text(
                          'Campus Share',
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: AppTheme.fontWeightBold,
                          ),
                        ),
                        const Spacer(),
                        // Notification dropdown
                        const NotificationDropdown(),
                        const SizedBox(width: AppTheme.spacing8),
                        _buildHeaderButton(
                          icon: Icons.person_outline,
                          label: 'Profile',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileScreen()),
                            );
                          },
                        ),
                        const SizedBox(width: AppTheme.spacing8),
                        _buildHeaderButton(
                          icon: Icons.logout,
                          label: 'Logout',
                          isDanger: true,
                          onTap: () async {
                            await AuthService().logout();
                          },
                        ),
                      ],
                    ),
                  ),
                  // Hero content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spacing24,
                      AppTheme.spacing16,
                      AppTheme.spacing24,
                      AppTheme.spacing24,
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Community Sharing Platform',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 22,
                            fontWeight: AppTheme.fontWeightBold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spacing8),
                        Text(
                          'Lend and borrow items securely with QR verification and deposit protection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Main content area
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.all(AppTheme.spacing24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Welcome row
                  Text(
                    'Welcome, ${_getUserDisplayName()}!',
                    style: AppTheme.pageHeader,
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  // Action buttons row
                  Wrap(
                    spacing: AppTheme.spacing12,
                    runSpacing: AppTheme.spacing12,
                    children: [
                      _buildActionButton(
                        icon: Icons.add_circle_outline,
                        label: 'Post Item',
                        filled: true,
                        onTap: () async {
                          final canProceed = await ProfileGuard.checkProfileComplete(
                            context,
                            actionType: 'lend',
                          );
                          if (!canProceed) return;
                          if (!context.mounted) return;
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const PostItemScreen()),
                          );
                          setState(() {});
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.search,
                        label: 'Browse',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const MarketplaceScreen()),
                          );
                          setState(() {});
                        },
                      ),
                      _buildActionButton(
                        icon: Icons.history,
                        label: 'Transactions',
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const TransactionsScreen()),
                          );
                          setState(() {});
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing24),
                  // Wallet Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppTheme.spacing24),
                    decoration: AppTheme.cardDecoration,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.account_balance_wallet, color: AppTheme.primary, size: 24),
                            const SizedBox(width: AppTheme.spacing12),
                            const Text('My Wallet', style: AppTheme.cardHeader),
                          ],
                        ),
                        const SizedBox(height: AppTheme.spacing16),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Balance',
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      color: AppTheme.textSecondary,
                                      fontSize: AppTheme.fontSizeHelper,
                                    ),
                                  ),
                                  const SizedBox(height: AppTheme.spacing4),
                                  Text(
                                    '₹${MockData.userWallet.balance.toStringAsFixed(0)}',
                                    style: const TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: 22,
                                      fontWeight: AppTheme.fontWeightBold,
                                      color: AppTheme.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 40,
                              color: AppTheme.border,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: AppTheme.spacing24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Locked',
                                      style: TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        color: AppTheme.textSecondary,
                                        fontSize: AppTheme.fontSizeHelper,
                                      ),
                                    ),
                                    const SizedBox(height: AppTheme.spacing4),
                                    Text(
                                      '₹${MockData.userWallet.lockedDeposit.toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 22,
                                        fontWeight: AppTheme.fontWeightBold,
                                        color: AppTheme.warning,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing24),
            // PENDING REQUESTS SECTION - Shows requests lender needs to approve
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
                        const Icon(Icons.notification_important, color: AppTheme.warning, size: 24),
                        const SizedBox(width: AppTheme.spacing8),
                        const Text('Pending Requests', style: AppTheme.cardHeader),
                        const SizedBox(width: AppTheme.spacing8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning,
                            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                          ),
                          child: Text(
                            '${pendingItems.length}',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: Colors.white,
                              fontWeight: AppTheme.fontWeightBold,
                              fontSize: AppTheme.fontSizeHelper,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    ...pendingItems.map((item) => _ActivityItemCard(item: item, isOwner: true, onUpdate: () {})),
                    const SizedBox(height: AppTheme.spacing32),
                  ],
                );
              },
            ),

            // Expandable Lent Items Section
            Container(
              decoration: AppTheme.cardDecoration,
              child: ExpansionTile(
                controller: _lentTileController,
                leading: const Icon(Icons.upload_outlined, color: AppTheme.primary),
                title: const Text(
                  'Lent Items',
                  style: AppTheme.sectionTitle,
                ),
                subtitle: Text(
                  'Items you have posted for lending',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontSizeHelper,
                    color: AppTheme.textSecondary,
                  ),
                ),
                initiallyExpanded: false,
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
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
                          padding: EdgeInsets.all(AppTheme.spacing24),
                          child: Text(
                            'No items lent yet',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fontSizeBody,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                            child: _ActivityItemCard(
                              item: item,
                              isOwner: true,
                              onUpdate: () {},
                              highlight: _highlightItemId == item.id,
                              scrollKey: _getKeyForItem(item.id),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing16),

            // Expandable Borrowed Items Section
            Container(
              decoration: AppTheme.cardDecoration,
              child: ExpansionTile(
                controller: _borrowedTileController,
                leading: const Icon(Icons.download_outlined, color: AppTheme.warning),
                title: const Text(
                  'Borrowed Items',
                  style: AppTheme.sectionTitle,
                ),
                subtitle: Text(
                  'Items you are currently borrowing',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: AppTheme.fontSizeHelper,
                    color: AppTheme.textSecondary,
                  ),
                ),
                initiallyExpanded: false,
                childrenPadding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                  vertical: AppTheme.spacing8,
                ),
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
                          padding: EdgeInsets.all(AppTheme.spacing24),
                          child: Text(
                            'No items borrowed yet',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fontSizeBody,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: items.map((item) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
                            child: _ActivityItemCard(
                              item: item,
                              isBorrowed: true,
                              onUpdate: () {},
                              highlight: _highlightItemId == item.id,
                              scrollKey: _getKeyForItem(item.id),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: AppTheme.spacing32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Keep _buildFeatureRow, _ActionCard, and _ActivityItemCard unchanged

  // ignore: unused_element
  Widget _buildFeatureRow(String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check, color: AppTheme.success, size: 20),
        const SizedBox(width: AppTheme.spacing8),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.left,
            style: AppTheme.bodyText,
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDanger = false,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing12,
            vertical: AppTheme.spacing8,
          ),
          decoration: BoxDecoration(
            color: isDanger
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white, size: 18),
              const SizedBox(width: AppTheme.spacing4),
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  color: Colors.white,
                  fontSize: AppTheme.fontSizeLabel,
                  fontWeight: AppTheme.fontWeightMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    if (filled) {
      return ElevatedButton.icon(
        onPressed: onTap,
        style: AppTheme.primaryButtonStyle,
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: onTap,
      style: AppTheme.primaryOutlinedButtonStyle,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _ActivityItemCard extends StatefulWidget {
  final Item item;
  final bool isBorrowed;
  final bool isOwner;
  final bool highlight;
  final GlobalKey? scrollKey;
  final VoidCallback onUpdate;
  const _ActivityItemCard({
    required this.item,
    required this.onUpdate,
    this.isBorrowed = false,
    this.isOwner = false,
    this.highlight = false,
    this.scrollKey,
  });

  @override
  State<_ActivityItemCard> createState() => _ActivityItemCardState();
}

class _ActivityItemCardState extends State<_ActivityItemCard> with SingleTickerProviderStateMixin {
  late AnimationController _highlightController;
  late Animation<double> _highlightAnimation;

  @override
  void initState() {
    super.initState();
    _highlightController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );
    _highlightAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _highlightController,
      curve: Curves.easeOut,
    ));
    
    if (widget.highlight) {
      _highlightController.forward();
    }
  }

  @override
  void didUpdateWidget(_ActivityItemCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlight && !oldWidget.highlight) {
      _highlightController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _highlightController.dispose();
    super.dispose();
  }

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
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );
      if (transaction != null) {
        await TransactionService.approveRequest(transaction.id);
      } else {
        await ItemService.approveRequest(widget.item.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request approved! You can now generate QR for handover.'),
          backgroundColor: AppTheme.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _rejectRequest() async {
    try {
      final transaction = await TransactionService.getTransactionForItem(
        widget.item.id,
      );
      if (transaction != null) {
        await TransactionService.rejectRequest(transaction.id);
      } else {
        await ItemService.rejectRequest(widget.item.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request rejected'),
          backgroundColor: AppTheme.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to reject: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Settlement for damaged/kept items - transfers deposit from borrower to lender
  // ignore: unused_element
  Future<void> _settleItem() async {
    try {
      final depositAmount = double.tryParse(widget.item.deposit) ?? 0;
      final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

      if (depositAmount > 0 && widget.item.borrowerId != null) {
        final borrowerWallet = MockData.getWalletForUser(widget.item.borrowerId!);
        final lenderWallet = MockData.getWalletForUser(currentUserId);

        if (borrowerWallet.transferLockedDeposit(depositAmount)) {
          lenderWallet.receiveTransferredDeposit(depositAmount);
        }
        await MockData.saveWallet();
      }

      await ItemService.settleItem(widget.item.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Item settled. Deposit of ₹$depositAmount transferred to your wallet.'),
          backgroundColor: AppTheme.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to settle: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  /// Delete an item (soft delete with confirmation)
  Future<void> _deleteItem() async {
    // First check if deletion is allowed
    final canDelete = await ItemService.canDeleteItem(widget.item.id);
    if (!canDelete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Item has active transactions or is not available'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    if (!mounted) return;
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.delete_forever, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            const Text('Delete Item?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete "${widget.item.name}"?',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppTheme.warning, size: 20),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'This item will be removed from the marketplace.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Re-check before deletion (handles race condition)
    final stillCanDelete = await ItemService.canDeleteItem(widget.item.id);
    if (!stillCanDelete) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete: Someone just requested this item!'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    try {
      await ItemService.softDeleteItem(widget.item.id);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Item deleted successfully'),
          backgroundColor: AppTheme.success,
        ),
      );
      widget.onUpdate();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _openChat() async {
    final otherUserId = widget.isOwner
        ? (widget.item.borrowerId ?? 'unknown')
        : widget.item.ownerId;

    if (otherUserId == 'unknown' || otherUserId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot open chat - no other user')),
      );
      return;
    }

    // Determine the other user's name based on role
    String otherUserName;
    if (widget.isOwner) {
      // When owner, other user is borrower - fetch their actual name
      try {
        final borrowerProfile = await ProfileService.getProfileForUser(otherUserId);
        otherUserName = borrowerProfile?.fullName ?? 'Borrower';
      } catch (e) {
        otherUserName = 'Borrower';
      }
    } else {
      // When borrower, other user is owner - use stored name
      otherUserName = widget.item.ownerName ?? 'Lender';
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          itemId: widget.item.id,
          otherUserId: otherUserId,
          otherUserName: otherUserName,
          itemName: widget.item.name,
        ),
      ),
    );
  }

  Future<void> _openHandover({required bool isLender}) async {
    try {
      final transaction = await TransactionService.getTransactionForItem(widget.item.id);

      if (transaction == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active transaction found for this item'),
            backgroundColor: AppTheme.danger,
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
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  Future<void> _openReturn({required bool isBorrower}) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in again to continue'),
          backgroundColor: AppTheme.danger,
        ),
      );
      return;
    }

    try {
      final transaction = await TransactionService.getTransactionForItem(widget.item.id);

      if (transaction == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No active transaction found for this item'),
            backgroundColor: AppTheme.danger,
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
            backgroundColor: AppTheme.success,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('Return error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.danger),
      );
    }
  }

  void _showReviewDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.cardRadius)),
        title: Column(
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: AppTheme.primary),
            const SizedBox(height: AppTheme.spacing16),
            const Text(
              'Review Request',
              textAlign: TextAlign.center,
              style: AppTheme.cardHeader,
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'A user wants to borrow this item.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: AppTheme.textSecondary,
                fontSize: AppTheme.fontSizeBody,
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Container(
              padding: const EdgeInsets.all(AppTheme.spacing12),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                    child: Icon(
                      _categoryIcon(widget.item.category),
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.item.name,
                          style: AppTheme.labelText.copyWith(fontWeight: AppTheme.fontWeightSemibold),
                        ),
                        Text(
                          'Deposit: ₹${widget.item.deposit}',
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            color: AppTheme.textSecondary,
                            fontSize: AppTheme.fontSizeHelper,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppTheme.spacing24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _rejectRequest();
                    },
                    style: AppTheme.dangerOutlinedButtonStyle,
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _approveRequest();
                    },
                    style: AppTheme.successButtonStyle,
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
    final bool showLenderHandover =
        widget.isOwner && widget.item.status == ItemStatus.approved;
    final bool showBorrowerHandover =
        widget.isBorrowed && widget.item.status == ItemStatus.approved;
    final bool showBorrowerReturn =
        widget.isBorrowed && widget.item.status == ItemStatus.active;
    final bool showLenderReturnConfirm =
        widget.isOwner && widget.item.status == ItemStatus.active;
    final bool isApproved = widget.item.status == ItemStatus.approved;
    final bool isActive = widget.item.status == ItemStatus.active;
    final bool canChat =
        (widget.item.status == ItemStatus.requested ||
        widget.item.status == ItemStatus.approved ||
        widget.item.status == ItemStatus.active);
    // Show delete button only for owner when item is available (no active transactions)
    final bool showDeleteButton =
        widget.isOwner && widget.item.status == ItemStatus.available;

    return Container(
      key: widget.scrollKey,
      child: AnimatedBuilder(
        animation: _highlightAnimation,
        builder: (context, child) {
          final glowIntensity = _highlightAnimation.value;
          final isGlowing = widget.highlight && glowIntensity > 0;
          
          return Container(
            margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              border: isGlowing
                  ? Border.all(
                      color: Colors.lightBlueAccent.withValues(alpha: 0.8 + (glowIntensity * 0.2)),
                      width: 2.5 + (glowIntensity * 1.5),
                    )
                  : isActive
                      ? Border.all(color: AppTheme.primary.withValues(alpha: 0.4), width: 2)
                      : isApproved
                          ? Border.all(color: AppTheme.success.withValues(alpha: 0.3), width: 1)
                          : Border.all(color: AppTheme.border),
              boxShadow: isGlowing
                  ? [
                      // Inner glow - bright blue
                      BoxShadow(
                        color: Colors.lightBlueAccent.withValues(alpha: glowIntensity * 0.7),
                        blurRadius: 12 + (glowIntensity * 16),
                        spreadRadius: glowIntensity * 3,
                      ),
                      // Outer lightning glow - electric blue
                      BoxShadow(
                        color: Colors.cyanAccent.withValues(alpha: glowIntensity * 0.5),
                        blurRadius: 20 + (glowIntensity * 12),
                        spreadRadius: glowIntensity * 6,
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
            ),
            child: child,
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing16),
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
                          ? AppTheme.success.withValues(alpha: 0.1)
                          : AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    ),
                    child: Icon(
                      _categoryIcon(widget.item.category),
                      color: isApproved ? AppTheme.success : AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spacing12),
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
                                style: AppTheme.sectionTitle,
                              ),
                            ),
                            if (canChat)
                            IconButton(
                              icon: const Icon(Icons.chat_bubble_outline),
                              color: AppTheme.primary,
                              onPressed: _openChat,
                              constraints: const BoxConstraints(),
                              padding: EdgeInsets.zero,
                              iconSize: 20,
                            ),
                            if (showDeleteButton) ...
                            [
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                color: AppTheme.danger,
                                onPressed: _deleteItem,
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                iconSize: 20,
                                tooltip: 'Delete item',
                              ),
                            ],
                        ],
                      ),
                      const SizedBox(height: AppTheme.spacing4),
                      Text(
                        'Deposit: ₹${widget.item.deposit}',
                        style: const TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          color: AppTheme.textSecondary,
                          fontSize: AppTheme.fontSizeLabel,
                        ),
                      ),
                      if (isApproved && widget.isBorrowed)
                        Padding(
                          padding: const EdgeInsets.only(top: AppTheme.spacing8),
                          child: Row(
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: AppTheme.success),
                              const SizedBox(width: AppTheme.spacing4),
                              const Text(
                                'Approved',
                                style: TextStyle(
                                  fontFamily: AppTheme.fontFamily,
                                  color: AppTheme.success,
                                  fontWeight: AppTheme.fontWeightSemibold,
                                  fontSize: AppTheme.fontSizeHelper,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (!isApproved) ...[
                        const SizedBox(height: AppTheme.spacing8),
                        StatusBadge(status: widget.item.status),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Actions for lender when request is pending
            if (showRequestActions) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: AppTheme.spacing12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _showReviewDialog,
                  style: AppTheme.primaryButtonStyle,
                  child: const Text('Review Request'),
                ),
              ),
            ],
            // Lender handover action - show QR code
            if (showLenderHandover) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: AppTheme.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: AppTheme.primary, size: 18),
                        const SizedBox(width: AppTheme.spacing8),
                        const Expanded(
                          child: Text(
                            'Credits will be locked from borrower only after QR verification',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fontSizeHelper,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ElevatedButton.icon(
                    onPressed: () => _openHandover(isLender: true),
                    style: AppTheme.primaryButtonStyle,
                    icon: const Icon(Icons.qr_code, size: 20),
                    label: const Text('Confirm Handover (Show QR)'),
                  ),
                ],
              ),
            ],
            // Borrower handover action - scan QR code
            if (showBorrowerHandover) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: AppTheme.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber, color: AppTheme.warning, size: 18),
                        const SizedBox(width: AppTheme.spacing8),
                        const Expanded(
                          child: Text(
                            'Scan the lender\'s QR code when you receive the item. Your credits will be locked.',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fontSizeHelper,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ElevatedButton.icon(
                    onPressed: () => _openHandover(isLender: false),
                    style: AppTheme.primaryButtonStyle,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Scan QR to Receive Item'),
                  ),
                ],
              ),
            ],
            // Borrower return action - generate Return QR
            if (showBorrowerReturn) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: AppTheme.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing8,
                          vertical: AppTheme.spacing4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock, size: 14, color: AppTheme.primary),
                            const SizedBox(width: AppTheme.spacing4),
                            Text(
                              '₹${widget.item.deposit} Locked',
                              style: const TextStyle(
                                fontFamily: AppTheme.fontFamily,
                                color: AppTheme.primary,
                                fontSize: 11,
                                fontWeight: AppTheme.fontWeightSemibold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ElevatedButton.icon(
                    onPressed: () => _openReturn(isBorrower: true),
                    style: AppTheme.primaryButtonStyle,
                    icon: const Icon(Icons.assignment_return, size: 20),
                    label: const Text('Return Item (Show QR)'),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  const Text(
                    'Show the Return QR to lender to get your deposit back',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
            // Lender return confirmation - scan Return QR
            if (showLenderReturnConfirm) ...[
              const SizedBox(height: AppTheme.spacing16),
              const Divider(height: 1, color: AppTheme.border),
              const SizedBox(height: AppTheme.spacing12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppTheme.spacing12),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppTheme.buttonRadius),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock, color: AppTheme.primary, size: 18),
                        const SizedBox(width: AppTheme.spacing8),
                        Expanded(
                          child: Text(
                            'Deposit ₹${widget.item.deposit} locked from borrower',
                            style: const TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                              fontSize: AppTheme.fontSizeHelper,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spacing12),
                  ElevatedButton.icon(
                    onPressed: () => _openReturn(isBorrower: false),
                    style: AppTheme.successButtonStyle,
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                    label: const Text('Confirm Return (Scan QR)'),
                  ),
                  const SizedBox(height: AppTheme.spacing8),
                  const Text(
                    'Scan borrower\'s Return QR to verify item condition',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 11,
                      color: AppTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    ),
    );
  }
}
