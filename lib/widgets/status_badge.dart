import 'package:flutter/material.dart';
import '../models/item.dart';
import '../app_theme.dart';

class StatusBadge extends StatelessWidget {
  final ItemStatus status;

  const StatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status) {
      case ItemStatus.available:
        return AppTheme.success;
      case ItemStatus.requested:
        return AppTheme.warning;
      case ItemStatus.approved:
        return AppTheme.primary;
      case ItemStatus.active:
        return AppTheme.primaryPressed;
      case ItemStatus.returned:
        return AppTheme.textSecondary;
      case ItemStatus.settled:
        return AppTheme.primaryHover;
    }
  }

  Color _getBackgroundColor() {
    switch (status) {
      case ItemStatus.available:
        return AppTheme.success.withOpacity(0.1);
      case ItemStatus.requested:
        return AppTheme.warning.withOpacity(0.1);
      case ItemStatus.approved:
        return AppTheme.primary.withOpacity(0.1);
      case ItemStatus.active:
        return AppTheme.primaryPressed.withOpacity(0.1);
      case ItemStatus.returned:
        return AppTheme.textSecondary.withOpacity(0.1);
      case ItemStatus.settled:
        return AppTheme.primaryHover.withOpacity(0.1);
    }
  }

  String _getText() {
    switch (status) {
      case ItemStatus.available:
        return 'Available';
      case ItemStatus.requested:
        return 'Requested';
      case ItemStatus.approved:
        return 'Approved';
      case ItemStatus.active:
        return 'Active';
      case ItemStatus.returned:
        return 'Returned';
      case ItemStatus.settled:
        return 'Settled';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor().withOpacity(0.5)),
      ),
      child: Text(
        _getText(),
        style: TextStyle(
          fontFamily: AppTheme.fontFamily,
          color: _getColor(),
          fontWeight: AppTheme.fontWeightSemibold,
          fontSize: AppTheme.fontSizeHelper,
        ),
      ),
    );
  }
}
