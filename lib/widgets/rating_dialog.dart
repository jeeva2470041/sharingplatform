import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String itemName;
  final String? transactionId;
  final String? ratedUserId;
  final String? ratedUserName;
  final bool isRatingLender; // true if borrower is rating lender
  final Function(int rating, String? comment)? onRatingSubmitted;
  // Legacy callback for backward compatibility
  final Function(int rating)? onLegacyRatingSubmitted;

  const RatingDialog({
    super.key,
    required this.itemName,
    this.transactionId,
    this.ratedUserId,
    this.ratedUserName,
    this.isRatingLender = true,
    this.onRatingSubmitted,
    this.onLegacyRatingSubmitted,
  });

  // Legacy constructor for backward compatibility
  factory RatingDialog.legacy({
    Key? key,
    required String itemName,
    required Function(int rating) onRatingSubmitted,
  }) {
    return RatingDialog(
      key: key,
      itemName: itemName,
      onLegacyRatingSubmitted: onRatingSubmitted,
    );
  }

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedRating = 0;
  final TextEditingController _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submitRating() {
    if (widget.onRatingSubmitted != null) {
      widget.onRatingSubmitted!(
        _selectedRating,
        _commentController.text.trim().isNotEmpty
            ? _commentController.text.trim()
            : null,
      );
    } else if (widget.onLegacyRatingSubmitted != null) {
      widget.onLegacyRatingSubmitted!(_selectedRating);
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Thank you for your rating!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userRole = widget.isRatingLender ? 'lender' : 'borrower';
    final ratingTarget = widget.ratedUserName ?? 'this $userRole';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Rate this transaction',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How was your experience with "$ratingTarget"?',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              widget.itemName,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNumber = index + 1;
                return IconButton(
                  iconSize: 36,
                  icon: Icon(
                    starNumber <= _selectedRating
                        ? Icons.star
                        : Icons.star_border,
                    color: Colors.amber.shade700,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRating = starNumber;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            if (_selectedRating > 0)
              Text(
                _getRatingLabel(_selectedRating),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber.shade900,
                ),
              ),
            const SizedBox(height: 20),
            // Optional comment field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                hintText: 'Add a comment (optional)',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.amber.shade700),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: 3,
              maxLength: 200,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedRating > 0 ? _submitRating : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
