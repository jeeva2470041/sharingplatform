import 'package:flutter/material.dart';
import '../models/item.dart';

class StatusBadge extends StatelessWidget {
  final ItemStatus status;

  const StatusBadge({super.key, required this.status});

  Color _getColor() {
    switch (status) {
      case ItemStatus.available:
        return Colors.green;
      case ItemStatus.requested:
        return Colors.orange;
      case ItemStatus.approved:
        return Colors.blue;
      case ItemStatus.active:
        return Colors.teal;
      case ItemStatus.returned:
        return Colors.grey;
      case ItemStatus.settled:
        return Colors.purple;
    }
  }

  Color _getBackgroundColor() {
    switch (status) {
      case ItemStatus.available:
        return Colors.green.shade50;
      case ItemStatus.requested:
        return Colors.orange.shade50;
      case ItemStatus.approved:
        return Colors.blue.shade50;
      case ItemStatus.active:
        return Colors.teal.shade50;
      case ItemStatus.returned:
        return Colors.grey.shade200;
      case ItemStatus.settled:
        return Colors.purple.shade50;
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _getColor().withValues(alpha: 0.5)),
      ),
      child: Text(
        _getText(),
        style: TextStyle(
          color: _getColor(),
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
