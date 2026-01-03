import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../models/user_rating.dart';
import '../services/profile_service.dart';
import '../services/rating_service.dart';
import '../app_theme.dart';

/// Reusable dialog to show user profile information with ratings and reviews
/// Used in chat, transactions, and marketplace screens
class UserProfileInfoDialog extends StatefulWidget {
  final String userId;
  final String? title; // Optional title override (e.g., "Borrower Info", "Lender Info")

  const UserProfileInfoDialog({
    super.key,
    required this.userId,
    this.title,
  });

  @override
  State<UserProfileInfoDialog> createState() => _UserProfileInfoDialogState();

  /// Show the dialog conveniently
  static Future<void> show(BuildContext context, {
    required String userId,
    String? title,
  }) {
    return showDialog(
      context: context,
      builder: (context) => UserProfileInfoDialog(
        userId: userId,
        title: title,
      ),
    );
  }
}

class _UserProfileInfoDialogState extends State<UserProfileInfoDialog>
    with SingleTickerProviderStateMixin {
  UserProfile? _profile;
  UserTrustScore? _trustScore;
  List<UserRating>? _ratings;
  bool _isLoading = true;
  String? _error;

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      // Load profile first (most important)
      final profile = await ProfileService.getProfileForUser(widget.userId);
      
      // Try to load ratings separately so they don't block profile display
      UserTrustScore? trustScore;
      List<UserRating>? ratings;
      
      try {
        final ratingResults = await Future.wait([
          RatingService.getTrustScore(widget.userId),
          RatingService.getUserRatings(widget.userId),
        ]);
        trustScore = ratingResults[0] as UserTrustScore;
        ratings = ratingResults[1] as List<UserRating>;
      } catch (e) {
        // Ratings failed but we can still show profile
        debugPrint('Failed to load ratings: $e');
      }

      if (mounted) {
        setState(() {
          _profile = profile;
          _trustScore = trustScore;
          _ratings = ratings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primary, AppTheme.primaryPressed],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.title ?? 'User Profile',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppTheme.fontFamily,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            // Content
            Flexible(
              child: _isLoading
                  ? _buildShimmerLoader()
                  : _error != null
                      ? _buildError()
                      : _profile == null
                          ? _buildNotFound()
                          : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerLoader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar and name shimmer
              Row(
                children: [
                  _shimmerBox(60, 60, isCircle: true),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(150, 20),
                        const SizedBox(height: 8),
                        _shimmerBox(100, 14),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Info fields shimmer
              _shimmerBox(double.infinity, 16),
              const SizedBox(height: 12),
              _shimmerBox(double.infinity, 16),
              const SizedBox(height: 12),
              _shimmerBox(double.infinity, 16),
              const SizedBox(height: 12),
              _shimmerBox(200, 16),
              const SizedBox(height: 24),
              // Rating shimmer
              _shimmerBox(120, 24),
              const SizedBox(height: 12),
              _shimmerBox(double.infinity, 50),
            ],
          ),
        );
      },
    );
  }

  Widget _shimmerBox(double width, double height, {bool isCircle = false}) {
    final shimmerGradient = LinearGradient(
      colors: [
        Colors.grey.shade300,
        Colors.grey.shade100,
        Colors.grey.shade300,
      ],
      stops: const [0.0, 0.5, 1.0],
      begin: Alignment(-1.0 + _shimmerController.value * 2, 0),
      end: Alignment(1.0 + _shimmerController.value * 2, 0),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: shimmerGradient,
        borderRadius: isCircle ? null : BorderRadius.circular(8),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            'Failed to load profile',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Unknown error',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Profile not found',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This user has not completed their profile yet.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final profile = _profile!;
    final trustScore = _trustScore;
    final ratings = _ratings ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar and name
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  profile.fullName.isNotEmpty
                      ? profile.fullName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.fullName.isNotEmpty ? profile.fullName : 'Unknown User',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    if (trustScore != null && trustScore.totalRatings > 0) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getTrustBadgeColor(trustScore.trustBadge).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          trustScore.trustBadge,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _getTrustBadgeColor(trustScore.trustBadge),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          
          // Profile info card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildInfoRow(Icons.school, 'Department', profile.department),
                if (profile.year != null && profile.year!.isNotEmpty)
                  _buildInfoRow(Icons.calendar_today, 'Year', profile.year!),
                _buildInfoRow(Icons.phone, 'Contact', profile.contactNumber),
                _buildInfoRow(Icons.email, 'Email', profile.email),
                _buildInfoRow(Icons.location_on, 'Address', profile.address, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Trust score / ratings section
          const Text(
            'Ratings & Reviews',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          if (trustScore == null || trustScore.totalRatings == 0)
            _buildNoReviewsPlaceholder()
          else ...[
            // Rating summary
            _buildRatingSummary(trustScore),
            const SizedBox(height: 16),
            // Individual reviews
            if (ratings.isNotEmpty) ...[
              const Text(
                'Recent Reviews',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              ...ratings.take(5).map((rating) => _buildReviewCard(rating)),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isLast = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoReviewsPlaceholder() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.star_border_outlined,
            size: 40,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No reviews yet',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'This user hasn\'t received any ratings yet.',
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRatingSummary(UserTrustScore trustScore) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          // Overall rating
          Column(
            children: [
              Text(
                trustScore.overallRating.toStringAsFixed(1),
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade800,
                ),
              ),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < trustScore.overallRating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 16,
                    color: Colors.amber.shade600,
                  );
                }),
              ),
              const SizedBox(height: 4),
              Text(
                '${trustScore.totalRatings} reviews',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          // Breakdown
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (trustScore.lenderRatingCount > 0)
                  _buildRatingBar(
                    'As Lender',
                    trustScore.lenderRating,
                    trustScore.lenderRatingCount,
                    Colors.green,
                  ),
                if (trustScore.borrowerRatingCount > 0) ...[
                  const SizedBox(height: 8),
                  _buildRatingBar(
                    'As Borrower',
                    trustScore.borrowerRating,
                    trustScore.borrowerRatingCount,
                    Colors.blue,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.check_circle, size: 14, color: Colors.green.shade600),
                    const SizedBox(width: 4),
                    Text(
                      '${trustScore.completedTransactions} transactions',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        fontSize: 11,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(String label, double rating, int count, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 11,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: rating / 5,
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          rating.toStringAsFixed(1),
          style: TextStyle(
            fontFamily: AppTheme.fontFamily,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }

  Widget _buildReviewCard(UserRating rating) {
    final timeAgo = _formatTimeAgo(rating.createdAt);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Stars
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < rating.rating.round()
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    size: 14,
                    color: Colors.amber.shade600,
                  );
                }),
              ),
              const Spacer(),
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: rating.asLender
                      ? Colors.green.withValues(alpha: 0.1)
                      : Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  rating.asLender ? 'as Lender' : 'as Borrower',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: rating.asLender ? Colors.green : Colors.blue,
                  ),
                ),
              ),
            ],
          ),
          if (rating.comment != null && rating.comment!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              rating.comment!,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.inventory_2_outlined, size: 12, color: Colors.grey.shade400),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  rating.itemName,
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                timeAgo,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 10,
                  color: Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getTrustBadgeColor(String badge) {
    if (badge.contains('Trusted')) return Colors.green;
    if (badge == 'Reliable') return Colors.blue;
    if (badge == 'Average') return Colors.orange;
    if (badge == 'New User') return Colors.grey;
    return Colors.red;
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 30) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    } else if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    } else if (diff.inMinutes > 0) {
      return '${diff.inMinutes}m ago';
    }
    return 'Just now';
  }
}
