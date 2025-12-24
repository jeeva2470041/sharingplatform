import 'package:flutter/material.dart';

class RatingDialog extends StatefulWidget {
  final String itemName;
  final Function(int rating) onRatingSubmitted;

  const RatingDialog({
    super.key,
    required this.itemName,
    required this.onRatingSubmitted,
  });

  @override
  State<RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<RatingDialog> {
  int _selectedRating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Rate this transaction',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How was your experience with "${widget.itemName}"?',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final starNumber = index + 1;
              return IconButton(
                iconSize: 40,
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
          const SizedBox(height: 16),
          if (_selectedRating > 0)
            Text(
              '$_selectedRating star${_selectedRating > 1 ? 's' : ''}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.amber.shade900,
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedRating > 0
              ? () {
                  widget.onRatingSubmitted(_selectedRating);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Thank you for your rating!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              : null,
          child: const Text('Submit'),
        ),
      ],
    );
  }
}
