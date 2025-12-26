import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models/transaction.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = true;
  List<_TransactionEntry> _allTransactions = [];

  String get _currentUserId => FirebaseAuth.instance.currentUser?.uid ?? '';

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
      case 0: return Colors.green;
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      case 3: return Colors.purple;
      case 4: return Colors.teal;
      case 5: return Colors.grey;
      default: return Colors.grey;
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
      case TransactionStatus.requested: return Colors.orange;
      case TransactionStatus.approved: return Colors.blue;
      case TransactionStatus.active: return Colors.purple;
      case TransactionStatus.completed: return Colors.green;
      case TransactionStatus.cancelled: return Colors.red;
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllTransactions,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allTransactions.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadAllTransactions,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _allTransactions.length,
                    itemBuilder: (context, index) {
                      return _TransactionCard(
                        entry: _allTransactions[index],
                        formatFullDateTime: _formatFullDateTime,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your posting, lending, and borrowing\nhistory will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
      case TransactionType.posted: return Colors.blue;
      case TransactionType.lent: return Colors.teal;
      case TransactionType.borrowed: return Colors.orange;
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

class _TransactionCard extends StatelessWidget {
  final _TransactionEntry entry;
  final String Function(DateTime) formatFullDateTime;

  const _TransactionCard({
    required this.entry,
    required this.formatFullDateTime,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                  formatFullDateTime(entry.timestamp),
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
          ],
        ),
      ),
    );
  }

  String _getCompletionMessage() {
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
