import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/transaction.dart';
import 'services/rating_service.dart';
import 'widgets/rating_dialog.dart';
import 'app_theme.dart';

// Filter options for transactions
enum TransactionFilter { pending, active, completed, cancelled, all }

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<_TransactionEntry> _allTransactions = [];
  TransactionFilter _selectedFilter = TransactionFilter.all;

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

  // Get filtered transactions based on selected tab
  List<_TransactionEntry> get _filteredTransactions {
    switch (_selectedFilter) {
      case TransactionFilter.pending:
        return _allTransactions.where((t) => 
          t.status == 'Requested' || t.status == 'Approved'
        ).toList();
      case TransactionFilter.active:
        return _allTransactions.where((t) => t.status == 'Active').toList();
      case TransactionFilter.completed:
        return _allTransactions.where((t) => 
          t.status == 'Completed' || t.status == 'Available' || t.status == 'Returned' || t.status == 'Settled'
        ).toList();
      case TransactionFilter.cancelled:
        return _allTransactions.where((t) => t.status == 'Cancelled').toList();
      case TransactionFilter.all:
        return _allTransactions;
    }
  }

  // Get count for each filter
  int _getFilterCount(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.pending:
        return _allTransactions.where((t) => 
          t.status == 'Requested' || t.status == 'Approved'
        ).length;
      case TransactionFilter.active:
        return _allTransactions.where((t) => t.status == 'Active').length;
      case TransactionFilter.completed:
        return _allTransactions.where((t) => 
          t.status == 'Completed' || t.status == 'Available' || t.status == 'Returned' || t.status == 'Settled'
        ).length;
      case TransactionFilter.cancelled:
        return _allTransactions.where((t) => t.status == 'Cancelled').length;
      case TransactionFilter.all:
        return _allTransactions.length;
    }
  }

  // Get filter label
  String _getFilterLabel(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.pending: return 'Pending';
      case TransactionFilter.active: return 'Active';
      case TransactionFilter.completed: return 'Completed';
      case TransactionFilter.cancelled: return 'Cancelled';
      case TransactionFilter.all: return 'All';
    }
  }

  // Get filter badge color
  Color _getFilterColor(TransactionFilter filter) {
    switch (filter) {
      case TransactionFilter.pending: return AppTheme.warning;
      case TransactionFilter.active: return AppTheme.primary;
      case TransactionFilter.completed: return AppTheme.success;
      case TransactionFilter.cancelled: return AppTheme.danger;
      case TransactionFilter.all: return const Color(0xFF6B7280);
    }
  }

  @override
  void initState() {
    super.initState();
    _loadAllTransactions();
  }

  Future<void> _loadAllTransactions() async {
    setState(() => _isLoading = true);

    try {
      final List<_TransactionEntry> entries = [];

      // 1. Load items I posted
      final postedItems = await _firestore
          .collection('items')
          .where('ownerId', isEqualTo: _currentUserId)
          .get();

      for (final doc in postedItems.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        entries.add(_TransactionEntry(
          type: TransactionType.posted,
          itemName: data['name'] ?? 'Unknown Item',
          category: data['category'] ?? 'Other',
          deposit: data['deposit'] ?? '0',
          timestamp: createdAt?.toDate() ?? DateTime.now(),
          status: _getItemStatusText(data['status'] ?? 0),
          statusColor: _getItemStatusColor(data['status'] ?? 0),
          details: 'Category: ${data['category'] ?? 'Other'}',
        ));
      }

      // 2. Load transactions where I am lender
      final lentTransactions = await _firestore
          .collection('transactions')
          .where('lenderId', isEqualTo: _currentUserId)
          .get();

      for (final doc in lentTransactions.docs) {
        final transaction = LendingTransaction.fromFirestore(doc);
        entries.add(_TransactionEntry(
          type: TransactionType.lent,
          itemName: transaction.itemName,
          deposit: '${transaction.depositAmount.toStringAsFixed(0)}',
          timestamp: transaction.handoverAt ?? transaction.createdAt,
          status: _getTransactionStatusText(transaction.status),
          statusColor: _getTransactionStatusColor(transaction.status),
          details: _buildLentDetails(transaction),
          completionType: transaction.completionType,
          isCompleted: transaction.status == TransactionStatus.completed,
          transactionId: transaction.id,
          otherUserId: transaction.borrowerId,
          otherUserName: 'Borrower',
        ));
      }

      // 3. Load transactions where I am borrower
      final borrowedTransactions = await _firestore
          .collection('transactions')
          .where('borrowerId', isEqualTo: _currentUserId)
          .get();

      for (final doc in borrowedTransactions.docs) {
        final transaction = LendingTransaction.fromFirestore(doc);
        entries.add(_TransactionEntry(
          type: TransactionType.borrowed,
          itemName: transaction.itemName,
          deposit: '${transaction.depositAmount.toStringAsFixed(0)}',
          timestamp: transaction.handoverAt ?? transaction.createdAt,
          status: _getTransactionStatusText(transaction.status),
          statusColor: _getTransactionStatusColor(transaction.status),
          details: _buildBorrowedDetails(transaction),
          completionType: transaction.completionType,
          isCompleted: transaction.status == TransactionStatus.completed,
          transactionId: transaction.id,
          otherUserId: transaction.lenderId,
          otherUserName: 'Lender',
        ));
      }

      // Sort all entries by timestamp (newest first)
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      setState(() {
        _allTransactions = entries;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading transactions: $e');
      setState(() => _isLoading = false);
    }
  }

  String _buildLentDetails(LendingTransaction t) {
    final parts = <String>[];
    parts.add('Requested: ${_formatDateTime(t.createdAt)}');
    if (t.handoverAt != null) {
      parts.add('Handed over: ${_formatDateTime(t.handoverAt!)}');
    }
    if (t.completedAt != null) {
      final action = t.completionType == 'returned' ? 'Returned' : 'Kept/Damaged';
      parts.add('$action: ${_formatDateTime(t.completedAt!)}');
    }
    return parts.join(' • ');
  }

  String _buildBorrowedDetails(LendingTransaction t) {
    final parts = <String>[];
    parts.add('Requested: ${_formatDateTime(t.createdAt)}');
    if (t.handoverAt != null) {
      parts.add('Received: ${_formatDateTime(t.handoverAt!)}');
    }
    if (t.completedAt != null) {
      final action = t.completionType == 'returned' ? 'Returned' : 'Kept';
      parts.add('$action: ${_formatDateTime(t.completedAt!)}');
    }
    return parts.join(' • ');
  }

  String _getItemStatusText(int index) {
    switch (index) {
      case 0: return 'Available';
      case 1: return 'Requested';
      case 2: return 'Approved';
      case 3: return 'Active';
      case 4: return 'Returned';
      case 5: return 'Settled';
      default: return 'Unknown';
    }
  }

  Color _getItemStatusColor(int index) {
    switch (index) {
      case 0: return AppTheme.success;
      case 1: return AppTheme.warning;
      case 2: return AppTheme.primary;
      case 3: return AppTheme.primaryPressed;
      case 4: return AppTheme.success;
      case 5: return AppTheme.textSecondary;
      default: return AppTheme.textSecondary;
    }
  }

  String _getTransactionStatusText(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.requested: return 'Requested';
      case TransactionStatus.approved: return 'Approved';
      case TransactionStatus.active: return 'Active';
      case TransactionStatus.completed: return 'Completed';
      case TransactionStatus.cancelled: return 'Cancelled';
    }
  }

  Color _getTransactionStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.requested: return AppTheme.warning;
      case TransactionStatus.approved: return AppTheme.primary;
      case TransactionStatus.active: return AppTheme.primaryPressed;
      case TransactionStatus.completed: return AppTheme.success;
      case TransactionStatus.cancelled: return AppTheme.danger;
    }
  }

  String _formatDateTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inDays == 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatFullDateTime(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
    final amPm = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '${months[date.month - 1]} ${date.day}, ${date.year} at $hour:$minute $amPm';
  }

  @override
  Widget build(BuildContext context) {
    final filteredList = _filteredTransactions;
    
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Transactions',
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
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadAllTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Header card with "All Transactions" title
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(AppTheme.spacing16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blue header bar
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF5C6BC0),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppTheme.cardRadius),
                      topRight: Radius.circular(AppTheme.cardRadius),
                    ),
                  ),
                  child: const Text(
                    'All Transactions',
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: AppTheme.fontSizeBody,
                      fontWeight: AppTheme.fontWeightSemibold,
                      color: Colors.white,
                    ),
                  ),
                ),
                // Filter tabs
                Padding(
                  padding: const EdgeInsets.all(AppTheme.spacing16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: TransactionFilter.values.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        final count = _getFilterCount(filter);
                        final color = _getFilterColor(filter);
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: AppTheme.spacing8),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedFilter = filter;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spacing12,
                                vertical: AppTheme.spacing8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected ? color : Colors.grey.shade300,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _getFilterLabel(filter),
                                    style: TextStyle(
                                      fontFamily: AppTheme.fontFamily,
                                      fontSize: AppTheme.fontSizeLabel,
                                      fontWeight: isSelected ? AppTheme.fontWeightSemibold : AppTheme.fontWeightMedium,
                                      color: isSelected ? color : AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  // Count badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '$count',
                                      style: const TextStyle(
                                        fontFamily: AppTheme.fontFamily,
                                        fontSize: 11,
                                        fontWeight: AppTheme.fontWeightBold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Transaction list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                : filteredList.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: _loadAllTransactions,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
                          itemCount: filteredList.length,
                          itemBuilder: (context, index) {
                            return _TransactionCard(
                              entry: filteredList[index],
                              formatFullDateTime: _formatFullDateTime,
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final filterLabel = _getFilterLabel(_selectedFilter).toLowerCase();
    final color = _getFilterColor(_selectedFilter);
    
    return Center(
      child: Container(
        margin: const EdgeInsets.all(AppTheme.spacing24),
        padding: const EdgeInsets.all(AppTheme.spacing24),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedFilter == TransactionFilter.all 
                  ? Icons.history 
                  : _selectedFilter == TransactionFilter.pending
                      ? Icons.pending_actions
                      : _selectedFilter == TransactionFilter.active
                          ? Icons.sync
                          : _selectedFilter == TransactionFilter.completed
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
              size: 56,
              color: color.withOpacity(0.6),
            ),
            const SizedBox(height: AppTheme.spacing16),
            Text(
              _selectedFilter == TransactionFilter.all
                  ? 'No transactions yet'
                  : 'No $filterLabel transactions',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontSizeSectionTitle,
                fontWeight: AppTheme.fontWeightBold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: AppTheme.spacing8),
            Text(
              _selectedFilter == TransactionFilter.all
                  ? 'Your posting, lending, and borrowing\nhistory will appear here'
                  : 'Transactions with $filterLabel status\nwill appear here',
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: AppTheme.fontSizeLabel,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum TransactionType { posted, lent, borrowed }

class _TransactionEntry {
  final TransactionType type;
  final String itemName;
  final String? category;
  final String deposit;
  final DateTime timestamp;
  final String status;
  final Color statusColor;
  final String details;
  final String? completionType;
  final bool isCompleted;
  // Rating-related fields
  final String? transactionId;
  final String? otherUserId;
  final String? otherUserName;

  _TransactionEntry({
    required this.type,
    required this.itemName,
    this.category,
    required this.deposit,
    required this.timestamp,
    required this.status,
    required this.statusColor,
    required this.details,
    this.completionType,
    this.isCompleted = false,
    this.transactionId,
    this.otherUserId,
    this.otherUserName,
  });

  String get typeLabel {
    switch (type) {
      case TransactionType.posted: return 'POSTED';
      case TransactionType.lent: return 'LENT';
      case TransactionType.borrowed: return 'BORROWED';
    }
  }

  Color get typeColor {
    switch (type) {
      case TransactionType.posted: return AppTheme.primary;
      case TransactionType.lent: return AppTheme.success;
      case TransactionType.borrowed: return AppTheme.warning;
    }
  }

  IconData get typeIcon {
    switch (type) {
      case TransactionType.posted: return Icons.post_add;
      case TransactionType.lent: return Icons.upload_outlined;
      case TransactionType.borrowed: return Icons.download_outlined;
    }
  }
}

class _TransactionCard extends StatefulWidget {
  final _TransactionEntry entry;
  final String Function(DateTime) formatFullDateTime;

  const _TransactionCard({
    required this.entry,
    required this.formatFullDateTime,
  });

  @override
  State<_TransactionCard> createState() => _TransactionCardState();
}

class _TransactionCardState extends State<_TransactionCard> {
  bool _hasRated = false;
  bool _checkingRating = false;

  @override
  void initState() {
    super.initState();
    _checkIfAlreadyRated();
  }

  Future<void> _checkIfAlreadyRated() async {
    if (widget.entry.transactionId == null || !widget.entry.isCompleted) return;
    if (widget.entry.type == TransactionType.posted) return;
    
    setState(() => _checkingRating = true);
    try {
      final hasRated = await RatingService.hasRatedTransaction(widget.entry.transactionId!);
      if (mounted) {
        setState(() {
          _hasRated = hasRated;
          _checkingRating = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingRating = false);
    }
  }

  Future<void> _showRatingDialog() async {
    if (widget.entry.transactionId == null || widget.entry.otherUserId == null) return;

    final isLender = widget.entry.type == TransactionType.lent;
    
    await showDialog(
      context: context,
      builder: (context) => RatingDialog(
        itemName: widget.entry.itemName,
        transactionId: widget.entry.transactionId,
        ratedUserId: widget.entry.otherUserId,
        ratedUserName: widget.entry.otherUserName,
        isRatingLender: !isLender, // If I'm lender, I'm rating borrower (not lender)
        onRatingSubmitted: (rating, comment) async {
          try {
            await RatingService.submitRating(
              transactionId: widget.entry.transactionId!,
              ratedUserId: widget.entry.otherUserId!,
              rating: rating.toDouble(),
              comment: comment,
              itemName: widget.entry.itemName,
              ratedAsLender: !isLender, // The rated user was lender if I'm borrower
            );
            if (mounted) {
              setState(() => _hasRated = true);
            }
          } catch (e) {
            debugPrint('Failed to submit rating: $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacing12),
      decoration: AppTheme.cardDecoration,
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with type badge and timestamp
            Row(
              children: [
                // Type badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: entry.typeColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(entry.typeIcon, size: 14, color: entry.typeColor),
                      const SizedBox(width: 4),
                      Text(
                        entry.typeLabel,
                        style: TextStyle(
                          color: entry.typeColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: entry.statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    entry.status,
                    style: TextStyle(
                      color: entry.statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Item name and deposit
            Row(
              children: [
                Expanded(
                  child: Text(
                    entry.itemName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Icon(Icons.currency_rupee, size: 16, color: Colors.green.shade700),
                    Text(
                      entry.deposit,
                      style: TextStyle(
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Timestamp
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  widget.formatFullDateTime(entry.timestamp),
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.details,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
            // Completion info for lent/borrowed
            if (entry.isCompleted && entry.completionType != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: entry.completionType == 'returned'
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: entry.completionType == 'returned'
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      entry.completionType == 'returned'
                          ? Icons.check_circle
                          : Icons.warning,
                      color: entry.completionType == 'returned'
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getCompletionMessage(),
                        style: TextStyle(
                          color: entry.completionType == 'returned'
                              ? Colors.green.shade700
                              : Colors.red.shade700,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // Rate button for completed lent/borrowed transactions
            if (entry.isCompleted && 
                entry.type != TransactionType.posted &&
                entry.transactionId != null &&
                entry.otherUserId != null) ...[
              const SizedBox(height: 12),
              if (_checkingRating)
                const SizedBox(
                  height: 36,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_hasRated)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade600, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'You rated this ${entry.otherUserName}',
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showRatingDialog,
                    icon: const Icon(Icons.star_outline, size: 18),
                    label: Text('Rate ${entry.otherUserName}'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.amber.shade700,
                      side: BorderSide(color: Colors.amber.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String _getCompletionMessage() {
    final entry = widget.entry;
    if (entry.type == TransactionType.lent) {
      return entry.completionType == 'returned'
          ? 'Item returned successfully'
          : 'Item kept/damaged - Deposit received';
    } else {
      return entry.completionType == 'returned'
          ? 'Item returned - Deposit refunded'
          : 'Item kept/damaged - Deposit transferred to lender';
    }
  }
}
