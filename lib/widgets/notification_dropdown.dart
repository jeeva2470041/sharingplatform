import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../dashboard_screen.dart';
import '../chat_screen.dart';

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

/// Chat notification item model
class ChatNotificationItem {
  final String chatId;
  final String itemId;
  final String itemName;
  final String otherUserId;
  final String otherUserName;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;

  ChatNotificationItem({
    required this.chatId,
    required this.itemId,
    required this.itemName,
    required this.otherUserId,
    required this.otherUserName,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
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
    // Stream for lender: new borrow requests (status = 0)
    final lenderRequestsStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('lenderId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 0)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    // Stream for borrower: approved requests waiting pickup (status = 1)
    final borrowerApprovedStream = FirebaseFirestore.instance
        .collection('transactions')
        .where('borrowerId', isEqualTo: _currentUserId)
        .where('status', isEqualTo: 1)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);

    // Stream for unread chat messages
    final unreadChatsStream = _getUnreadChatCountStream();

    // Combine all streams
    return lenderRequestsStream.asyncExpand((lenderCount) {
      return borrowerApprovedStream.asyncExpand((borrowerCount) {
        return unreadChatsStream.map((chatCount) {
          return lenderCount + borrowerCount + chatCount;
        });
      });
    });
  }

  Stream<int> _getUnreadChatCountStream() {
    // Get all chats where the user is a participant
    return FirebaseFirestore.instance
        .collection('chats')
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      int totalUnread = 0;

      for (final chatDoc in chatsSnapshot.docs) {
        final chatId = chatDoc.id;
        final chatData = chatDoc.data();
        
        // Get participant info for this user
        final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
        final userParticipantData = participants[_currentUserId] as Map<String, dynamic>?;
        
        if (userParticipantData == null) continue;
        
        final lastReadTimestamp = userParticipantData['lastReadTimestamp'] as Timestamp?;
        
        // Count messages after lastReadTimestamp
        Query messagesQuery = FirebaseFirestore.instance
            .collection('chats')
            .doc(chatId)
            .collection('messages')
            .where('senderId', isNotEqualTo: _currentUserId);
        
        if (lastReadTimestamp != null) {
          messagesQuery = messagesQuery.where('timestamp', isGreaterThan: lastReadTimestamp);
        }
        
        final unreadMessages = await messagesQuery.get();
        totalUnread += unreadMessages.docs.length;
      }

      return totalUnread;
    });
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
            // Chat notifications stream
            return StreamBuilder<List<ChatNotificationItem>>(
              stream: _getChatNotificationsStream(),
              builder: (context, chatSnapshot) {
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

                // Get chat notifications
                final chatNotifications = chatSnapshot.data ?? [];

                final hasTransactions = notifications.isNotEmpty;
                final hasChats = chatNotifications.isNotEmpty;

                // Always show the UI with sections (even if empty)

                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Chat Section - Always show
                      _buildSectionHeader(
                        icon: Icons.chat_bubble_outline,
                        title: 'Chat',
                        count: hasChats ? chatNotifications.fold<int>(0, (total, c) => total + c.unreadCount) : 0,
                        color: Colors.teal,
                      ),
                      if (hasChats)
                        ...chatNotifications.take(5).map((chat) => _ChatNotificationTile(
                          chat: chat,
                          onTap: () {
                            widget.onClose();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ChatScreen(
                                  itemId: chat.itemId,
                                  otherUserId: chat.otherUserId,
                                  otherUserName: chat.otherUserName,
                                  itemName: chat.itemName,
                                ),
                              ),
                            );
                          },
                        ))
                      else
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.chat_bubble_outline, size: 20, color: Colors.grey.shade400),
                              const SizedBox(width: 12),
                              Text(
                                'No new messages',
                                style: TextStyle(
                                  color: Colors.grey.shade500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Divider(height: 1, color: Colors.grey.shade300, thickness: 1),
                      // Transaction Section - Always show if has transactions
                      if (hasTransactions) ...[
                        _buildSectionHeader(
                          icon: Icons.swap_horiz,
                          title: 'Transactions',
                          count: notifications.length,
                          color: AppTheme.primary,
                        ),
                        ...notifications.take(10).map((notification) => _NotificationTile(
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
                        )),
                      ],
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required int count,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const Spacer(),
          if (count > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
  // Cache for user names to avoid redundant queries
  final Map<String, String> _userNameCache = {};
  bool _hasMigratedChats = false;

  Stream<List<ChatNotificationItem>> _getChatNotificationsStream() {
    // Query ONLY chats where current user is a participant (much faster!)
    return FirebaseFirestore.instance
        .collection('chats')
        .where('participantIds', arrayContains: widget.currentUserId)
        .snapshots()
        .asyncMap((chatsSnapshot) async {
      final List<ChatNotificationItem> chatNotifications = [];
      
      // If no chats found with new query, try fallback for old chats
      if (chatsSnapshot.docs.isEmpty && !_hasMigratedChats) {
        _hasMigratedChats = true;
        await _migrateOldChats();
        // Return empty for now, next snapshot will have migrated data
        return chatNotifications;
      }
      
      // Process in parallel for speed
      final futures = <Future<ChatNotificationItem?>>[];
      
      for (final chatDoc in chatsSnapshot.docs) {
        futures.add(_processChatForNotification(chatDoc));
      }
      
      final results = await Future.wait(futures);
      
      for (final result in results) {
        if (result != null) {
          chatNotifications.add(result);
        }
      }
      
      chatNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return chatNotifications;
    });
  }

  /// Migrate old chats to add participantIds field for efficient querying
  Future<void> _migrateOldChats() async {
    try {
      final allChats = await FirebaseFirestore.instance.collection('chats').get();
      
      for (final chatDoc in allChats.docs) {
        final data = chatDoc.data();
        // Skip if already has participantIds
        if (data.containsKey('participantIds')) continue;
        
        final participants = data['participants'] as Map<String, dynamic>? ?? {};
        final participantIds = participants.keys.toList();
        
        // Check if current user is a participant
        if (participantIds.contains(widget.currentUserId)) {
          // Add participantIds field
          await FirebaseFirestore.instance
              .collection('chats')
              .doc(chatDoc.id)
              .update({'participantIds': participantIds});
        }
      }
    } catch (e) {
      debugPrint('Chat migration error: $e');
    }
  }

  Future<ChatNotificationItem?> _processChatForNotification(DocumentSnapshot chatDoc) async {
    try {
      final chatId = chatDoc.id;
      final chatData = chatDoc.data() as Map<String, dynamic>?;
      if (chatData == null) return null;
      
      final participants = chatData['participants'] as Map<String, dynamic>? ?? {};
      final itemId = chatData['itemId'] as String? ?? chatId;
      final itemName = chatData['itemName'] as String? ?? 'Item';
      
      // Find the other user
      String otherUserId = '';
      for (final entry in participants.entries) {
        if (entry.key != widget.currentUserId) {
          otherUserId = entry.key;
          break;
        }
      }
      
      if (otherUserId.isEmpty) return null;
      
      // Get last read timestamp
      final userParticipantData = participants[widget.currentUserId] as Map<String, dynamic>?;
      final lastReadTimestamp = userParticipantData?['lastReadTimestamp'] as Timestamp?;
      
      // Get only the 5 most recent messages for speed
      final messagesSnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();
      
      if (messagesSnapshot.docs.isEmpty) return null;
      
      int unreadCount = 0;
      String lastMessageText = '';
      DateTime lastMessageTime = DateTime.now();
      
      for (final msgDoc in messagesSnapshot.docs) {
        final msgData = msgDoc.data();
        final senderId = msgData['senderId'] as String? ?? '';
        final msgTimestamp = msgData['timestamp'] as Timestamp?;
        
        if (senderId == widget.currentUserId) continue;
        
        bool isUnread = lastReadTimestamp == null || 
            (msgTimestamp != null && msgTimestamp.compareTo(lastReadTimestamp) > 0);
        
        if (isUnread) {
          unreadCount++;
          if (lastMessageText.isEmpty) {
            lastMessageText = msgData['text'] as String? ?? 'New message';
            lastMessageTime = msgTimestamp?.toDate() ?? DateTime.now();
          }
        }
      }
      
      if (unreadCount == 0) return null;
      
      // ALWAYS fetch user name from profiles collection (use cache)
      String otherUserName = 'User';
      if (_userNameCache.containsKey(otherUserId)) {
        otherUserName = _userNameCache[otherUserId]!;
      } else {
        try {
          // Query 'profiles' collection - this is where user data is stored!
          final userDoc = await FirebaseFirestore.instance
              .collection('profiles')
              .doc(otherUserId)
              .get();
          if (userDoc.exists) {
            final userData = userDoc.data();
            // Try fullName first, then displayName, then name
            otherUserName = userData?['fullName'] as String? ??
                userData?['displayName'] as String? ??
                userData?['name'] as String? ??
                'User';
            if (otherUserName.isNotEmpty && otherUserName != 'User') {
              _userNameCache[otherUserId] = otherUserName;
            }
          }
        } catch (e) {
          debugPrint('Failed to fetch user $otherUserId: $e');
        }
      }
      
      // If still "User", try participant data as last resort
      if (otherUserName == 'User' || otherUserName.isEmpty) {
        final otherData = participants[otherUserId] as Map<String, dynamic>?;
        final participantName = otherData?['name'] as String?;
        if (participantName != null && participantName.isNotEmpty && participantName != 'User') {
          otherUserName = participantName;
        }
      }
      
      return ChatNotificationItem(
        chatId: chatId,
        itemId: itemId,
        itemName: itemName,
        otherUserId: otherUserId,
        otherUserName: otherUserName,
        lastMessage: lastMessageText.isNotEmpty ? lastMessageText : 'New message',
        timestamp: lastMessageTime,
        unreadCount: unreadCount,
      );
    } catch (e) {
      return null;
    }
  }
}

/// Chat notification tile widget
class _ChatNotificationTile extends StatelessWidget {
  final ChatNotificationItem chat;
  final VoidCallback onTap;

  const _ChatNotificationTile({
    required this.chat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.teal.withValues(alpha: 0.03),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: Colors.teal.withValues(alpha: 0.2),
              radius: 20,
              child: Text(
                chat.otherUserName.isNotEmpty 
                    ? chat.otherUserName[0].toUpperCase() 
                    : 'U',
                style: const TextStyle(
                  color: Colors.teal,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
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
                          chat.otherUserName,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      // Unread count badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.teal,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${chat.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Item name
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined, size: 10, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          chat.itemName,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 11,
                            color: Colors.grey.shade600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Last message
                  Text(
                    chat.lastMessage,
                    style: TextStyle(
                      fontFamily: AppTheme.fontFamily,
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Timestamp
                  Text(
                    _formatTimestamp(chat.timestamp),
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
