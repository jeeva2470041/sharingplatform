import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../dashboard_screen.dart';

/// Storage key for dismissed notifications
const String _dismissedNotificationsKey = 'dismissed_notifications';

/// Notification item model
class NotificationItem {
  final String id;
  final String type; // 'transaction_lender' or 'transaction_borrower'
  final String title;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic> data;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.data,
    this.isRead = false,
  });
}

/// Notification bell with dropdown
class NotificationDropdown extends StatefulWidget {
  const NotificationDropdown({super.key});

  @override
  State<NotificationDropdown> createState() => _NotificationDropdownState();
}

class _NotificationDropdownState extends State<NotificationDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  DateTime? _openedAt;

  String get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _openedAt = DateTime.now();
    setState(() {
      _isOpen = true;
    });
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) {
      setState(() {
        _isOpen = false;
      });
    } else {
      _isOpen = false;
    }
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);

    return OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Backdrop to close dropdown
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                // Prevent immediate close caused by the same tap that opened it
                final now = DateTime.now();
                if (_openedAt != null &&
                    now.difference(_openedAt!).inMilliseconds < 180) {
                  return;
                }
                _closeDropdown();
              },
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Dropdown content
          Positioned(
            left: offset.dx - 280 + size.width,
            top: offset.dy + size.height + 8,
            width: 340,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
              child: _NotificationList(
                onClose: _closeDropdown,
                currentUserId: _currentUserId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: StreamBuilder<int>(
        stream: _getUnreadCountStream(),
        builder: (context, snapshot) {
          final unreadCount = snapshot.data ?? 0;

          return InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _isOpen ? Colors.white24 : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      const Icon(Icons.notifications_outlined,
                          color: Colors.white, size: 20),
                      if (unreadCount > 0)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: AppTheme.danger,
                              shape: BoxShape.circle,
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : '$unreadCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Stream<int> _getUnreadCountStream() {
    final transactionsStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('lenderId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 0)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    return transactionsStream;
  }
}

/// The actual notification list content
class _NotificationList extends StatefulWidget {
  final VoidCallback onClose;
  final String currentUserId;

  const _NotificationList({
    required this.onClose,
    required this.currentUserId,
  });

  @override
  State<_NotificationList> createState() => _NotificationListState();
}

class _NotificationListState extends State<_NotificationList> {
  Set<String> _dismissedIds = {};

  @override
  void initState() {
    super.initState();
    _loadDismissedNotifications();
  }

  Future<void> _loadDismissedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedNotificationsKey) ?? [];
    setState(() {
      _dismissedIds = dismissed.toSet();
    });
  }

  List<String> _currentNotificationIds = [];

  Future<void> _clearAllNotifications(List<String> currentIds) async {
    final prefs = await SharedPreferences.getInstance();
    final allDismissed = {..._dismissedIds, ...currentIds};
    await prefs.setStringList(_dismissedNotificationsKey, allDismissed.toList());
    setState(() {
      _dismissedIds = allDismissed;
    });
  }

  void _handleClearAll() async {
    await _clearAllNotifications(_currentNotificationIds);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.notifications, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () => _handleClearAll(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
          // Notifications list
          Flexible(
            child: _buildNotificationsList(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(BuildContext context) {
    // Transactions where current user is lender
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('transactions')
          .where('lenderId', isEqualTo: widget.currentUserId)
          .limit(10)
          .snapshots(),
      builder: (context, lenderSnapshot) {
        // Transactions where current user is borrower
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('transactions')
              .where('borrowerId', isEqualTo: widget.currentUserId)
              .limit(10)
              .snapshots(),
          builder: (context, borrowerSnapshot) {
            final waiting =
                lenderSnapshot.connectionState == ConnectionState.waiting &&
                    borrowerSnapshot.connectionState == ConnectionState.waiting;

            if (waiting) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                ),
              );
            }

            if (lenderSnapshot.hasError || borrowerSnapshot.hasError) {
              final error = lenderSnapshot.error ?? borrowerSnapshot.error;
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Notifications unavailable: $error',
                  style: const TextStyle(color: AppTheme.danger),
                ),
              );
            }

            final List<NotificationItem> notifications = [];

            // Process lender transactions
            if (lenderSnapshot.hasData) {
              for (final doc in lenderSnapshot.data!.docs) {
                // Skip dismissed notifications
                if (_dismissedIds.contains(doc.id)) continue;
                
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as int? ?? 0;
                final itemName = data['itemName'] as String? ?? 'Item';
                final itemId = data['itemId'] as String? ?? '';
                final borrowerName = data['borrowerName'] as String? ?? 'Someone';
                final timestamp = (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();

                String title;
                String message;
                IconData icon;
                Color color;

                if (status == 0) {
                  title = '🔔 Borrow Request';
                  message = '$borrowerName wants to borrow "$itemName"';
                  icon = Icons.pending_actions;
                  color = AppTheme.warning;
                } else if (status == 1) {
                  title = '✅ Request Approved';
                  message = '"$itemName" was approved for $borrowerName';
                  icon = Icons.check_circle;
                  color = AppTheme.success;
                } else if (status == 2) {
                  title = '🚚 Item Handover';
                  message = '"$itemName" is out with $borrowerName';
                  icon = Icons.task_alt;
                  color = AppTheme.primary;
                } else if (status == 3) {
                  title = '🎉 Return Confirmed';
                  message = '"$itemName" has been returned';
                  icon = Icons.task_alt;
                  color = AppTheme.primary;
                } else {
                  title = '❌ Request Cancelled';
                  message = 'Borrow request for "$itemName" was cancelled';
                  icon = Icons.cancel;
                  color = AppTheme.danger;
                }

                notifications.add(NotificationItem(
                  id: doc.id,
                  type: 'transaction_lender',
                  title: title,
                  message: message,
                  timestamp: timestamp,
                  data: {
                    ...data,
                    'docId': doc.id,
                    'itemId': itemId,
                    'icon': icon,
                    'color': color,
                  },
                ));
              }
            }

            // Process borrower transactions
            if (borrowerSnapshot.hasData) {
              for (final doc in borrowerSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                final status = data['status'] as int? ?? 0;
                final itemName = data['itemName'] as String? ?? 'Item';
                final itemId = data['itemId'] as String? ?? '';
                final timestamp = (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();

                String title;
                String message;
                IconData icon;
                Color color;

                if (status == 0) {
                  title = '⏳ Request Pending';
                  message = 'Waiting for approval to borrow "$itemName"';
                  icon = Icons.hourglass_empty;
                  color = AppTheme.warning;
                } else if (status == 1) {
                  title = '🎉 Request Approved!';
                  message = 'You can now pick up "$itemName"';
                  icon = Icons.thumb_up;
                  color = AppTheme.success;
                } else if (status == 2) {
                  title = '🚚 Item In Use';
                  message = 'You are currently using "$itemName"';
                  icon = Icons.play_circle;
                  color = AppTheme.primary;
                } else if (status == 3) {
                  title = '✅ Item Returned';
                  message = 'You returned "$itemName" successfully';
                  icon = Icons.task_alt;
                  color = AppTheme.primary;
                } else {
                  title = '❌ Request Declined';
                  message = 'Request for "$itemName" was declined';
                  icon = Icons.block;
                  color = AppTheme.danger;
                }

                notifications.add(NotificationItem(
                  id: doc.id,
                  type: 'transaction_borrower',
                  title: title,
                  message: message,
                  timestamp: timestamp,
                  data: {
                    ...data,
                    'docId': doc.id,
                    'itemId': itemId,
                    'icon': icon,
                    'color': color,
                  },
                ));
              }
            }

            // Sort by timestamp
            notifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));

            // Filter out dismissed notifications
            notifications.removeWhere((n) => _dismissedIds.contains(n.id));

            // Store current notification IDs for Clear All functionality
            _currentNotificationIds = notifications.map((n) => n.id).toList();

            if (notifications.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_outlined,
                        size: 48, color: Colors.grey.shade400),
                    const SizedBox(height: 12),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: notifications.length > 10 ? 10 : notifications.length,
              separatorBuilder: (_, index) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return _NotificationTile(
                  notification: notification,
                  onTap: () {
                    widget.onClose();
                    // Navigate to dashboard with highlight
                    final itemId = notification.data['itemId'] as String?;
                    final section = notification.type == 'transaction_lender'
                        ? 'lent'
                        : 'borrowed';
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(
                          highlightItemId: itemId,
                          highlightSection: section,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Individual notification tile
class _NotificationTile extends StatelessWidget {
  final NotificationItem notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = notification.data['icon'] as IconData? ?? Icons.notifications;
    final color = notification.data['color'] as Color? ?? AppTheme.primary;
    final status = notification.data['status'] as int? ?? 0;
    final isPending = status == 0;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: isPending ? AppTheme.warning.withValues(alpha: 0.05) : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight:
                                isPending ? FontWeight.bold : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isPending)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.warning,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(notification.timestamp),
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 10,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}
