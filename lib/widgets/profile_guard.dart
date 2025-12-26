import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../profile_screen.dart';

/// Helper class for profile-related guards and dialogs
class ProfileGuard {
  /// Check if profile is complete and show dialog if not
  /// Returns true if profile is complete, false if blocked
  /// If blocked, shows dialog and optionally redirects to profile screen
  static Future<bool> checkProfileComplete(
    BuildContext context, {
    required String actionType, // 'lend' or 'borrow'
  }) async {
    try {
      final isComplete = await ProfileService.isProfileComplete();

      if (isComplete) {
        return true;
      }

      // Show profile required dialog
      if (context.mounted) {
        await _showProfileRequiredDialog(context, actionType);
      }

      return false;
    } catch (e) {
      // If there's an error checking profile, allow the action
      // This prevents blocking users due to temporary issues
      print('Profile check error: $e');
      return true;
    }
  }

  /// Show dialog explaining profile is required
  static Future<void> _showProfileRequiredDialog(
    BuildContext context,
    String actionType,
  ) async {
    final message = actionType == 'lend'
        ? 'Please complete your profile to lend items.\n\nThis helps borrowers know who they are dealing with.'
        : 'Please complete your profile to borrow items.\n\nThis helps lenders know who they are lending to.';

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.person_add, color: Colors.orange.shade700),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Complete Your Profile')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
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
                      'It only takes a minute!',
                      style: TextStyle(
                        color: Colors.blue.shade800,
                        fontSize: 13,
                      ),
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
            child: Text('Later', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.arrow_forward),
            label: const Text('Complete Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );

    // Redirect to profile screen if user chose to complete
    if (result == true && context.mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(pendingAction: actionType),
        ),
      );
    }
  }
}
