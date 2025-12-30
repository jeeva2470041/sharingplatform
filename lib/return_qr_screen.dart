import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'data/mock_data.dart';
import 'services/transaction_service.dart';
import 'services/rating_service.dart';
import 'models/transaction.dart';
import 'app_theme.dart';
import 'widgets/qr_scanner_dialog.dart';
import 'widgets/rating_dialog.dart';

/// Screen for QR-based return verification
/// Borrower generates Return QR, Lender scans to confirm item return
class ReturnQrScreen extends StatefulWidget {
  final String transactionId;
  final bool
  isBorrower; // true = borrower (generate QR), false = lender (scan QR)

  const ReturnQrScreen({
    super.key,
    required this.transactionId,
    required this.isBorrower,
  });

  @override
  State<ReturnQrScreen> createState() => _ReturnQrScreenState();
}

class _ReturnQrScreenState extends State<ReturnQrScreen> {
  String? _returnQrCode;
  bool _isLoading = true;
  String? _error;
  LendingTransaction? _transaction;
  bool _qrGenerated = false;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  Future<void> _loadTransaction() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final transaction = await TransactionService.getTransaction(
        widget.transactionId,
      );

      if (transaction == null) {
        setState(() {
          _error = 'Transaction not found';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _transaction = transaction;
        _returnQrCode = transaction.returnQrCode;
        _qrGenerated =
            transaction.returnQrCode != null &&
            transaction.returnQrCode!.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Check if transaction is active and ready for return
  bool get _isActive => _transaction?.status == TransactionStatus.active;

  /// Check if QR can be generated (borrower + active + not yet generated)
  bool get _canGenerateReturnQr =>
      widget.isBorrower && _isActive && !_qrGenerated;

  Future<void> _generateReturnQrCode() async {
    if (!_canGenerateReturnQr && !_qrGenerated) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final qrCode = await TransactionService.initiateReturn(
        widget.transactionId,
      );

      setState(() {
        _returnQrCode = qrCode;
        _qrGenerated = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Return QR generated! Show it to the lender.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _scanReturnQr() async {
    final result = await showQrScannerDialog(
      context,
      title: 'Scan Return QR',
      subtitle: 'Point your camera at the borrower\'s QR code',
      accentColor: AppTheme.success,
    );

    if (result != null && result.isNotEmpty) {
      await _showConditionDialog(result);
    }
  }

  Future<void> _showConditionDialog(String qrCode) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green),
            SizedBox(width: 12),
            Expanded(child: Text('Confirm Item Condition')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Please verify the item condition:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Deposit: ₹${_transaction?.depositAmount.toStringAsFixed(0) ?? '0'}',
                      style: TextStyle(color: Colors.blue.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Returned Safely - Refund to borrower
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check_circle),
              label: const Text('Returned Safely - Refund Deposit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Kept/Damaged - Transfer to lender
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.pop(context, false),
              icon: const Icon(Icons.warning),
              label: const Text('Damaged/Kept - Claim Deposit'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (result != null) {
      await _confirmReturn(qrCode, result);
    }
  }

  Future<void> _confirmReturn(String qrCode, bool returnedSafely) async {
    setState(() => _isLoading = true);

    try {
      await TransactionService.confirmReturnWithQR(
        qrCode,
        returnedSafely: returnedSafely,
      );

      await MockData.loadWallet();

      if (!mounted) return;

      final message = returnedSafely
          ? 'Item returned! Deposit refunded to borrower.'
          : 'Item kept/damaged. Deposit transferred to your wallet.';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      // Show rating dialog after successful return (lender rates borrower)
      if (_transaction != null) {
        await _showRatingDialog();
      }

      if (!mounted) return;
      Navigator.pop(context, true); // Return success
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Return failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _showRatingDialog() async {
    if (_transaction == null) return;
    
    // Lender rates borrower
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => RatingDialog(
        itemName: _transaction!.itemName,
        transactionId: _transaction!.id,
        ratedUserId: _transaction!.borrowerId,
        ratedUserName: 'the borrower',
        isRatingLender: false, // Lender is rating borrower
        onRatingSubmitted: (rating, comment) async {
          try {
            await RatingService.submitRating(
              transactionId: _transaction!.id,
              ratedUserId: _transaction!.borrowerId,
              rating: rating.toDouble(),
              comment: comment,
              itemName: _transaction!.itemName,
              ratedAsLender: false, // The rated user (borrower) was NOT the lender
            );
          } catch (e) {
            debugPrint('Failed to submit rating: $e');
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.isBorrower ? 'Return Item' : 'Confirm Return',
          style: const TextStyle(
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Transaction Info
                  if (_transaction != null) _buildTransactionInfo(),

                  const SizedBox(height: 24),

                  // Main Content
                  if (widget.isBorrower)
                    _buildBorrowerSection()
                  else
                    _buildLenderSection(),

                  // Error display
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildErrorBox(),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildTransactionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.assignment_return, color: Colors.indigo.shade700),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _transaction!.itemName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.lock, size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      'Locked: ₹${_transaction!.depositAmount.toStringAsFixed(0)}',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildStatusChip(),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_horiz, size: 14, color: Colors.teal.shade700),
          const SizedBox(width: 4),
          Text(
            'Active',
            style: TextStyle(
              color: Colors.teal.shade700,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Borrower section: Generate Return QR
  Widget _buildBorrowerSection() {
    if (!_isActive) {
      return _buildNotActiveWarning();
    }

    if (_qrGenerated && _returnQrCode != null) {
      return _buildReturnQrDisplay();
    }

    return _buildGenerateReturnQrSection();
  }

  Widget _buildNotActiveWarning() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.warning_amber, size: 48, color: Colors.orange.shade700),
          const SizedBox(height: 16),
          Text(
            'Cannot Return Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The item must be in Active status to initiate return.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade800),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateReturnQrSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment_return,
              size: 48,
              color: Colors.indigo.shade700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready to Return',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a Return QR code and show it to the lender to confirm item return.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateReturnQrCode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate Return QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.green.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your deposit of ₹${_transaction?.depositAmount.toStringAsFixed(0) ?? '0'} will be refunded after lender confirms.',
                    style: TextStyle(
                      color: Colors.green.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnQrDisplay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.indigo.shade200, width: 2),
      ),
      child: Column(
        children: [
          // Success header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green.shade700,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  'Return QR Ready',
                  style: TextStyle(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // QR Code visual
          Container(
            width: 220,
            height: 220,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: QrImageView(
              data: _returnQrCode!,
              version: QrVersions.auto,
              size: 200,
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
            ),
          ),
          const SizedBox(height: 16),

          // Instruction
          const Text(
            'Show this QR to lender to confirm return',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // QR Code text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _returnQrCode!,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.grey.shade800,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 20),

          // Info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Lender will verify condition and confirm. Your deposit will be refunded if returned safely.',
                    style: TextStyle(color: Colors.blue.shade900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Lender section: Scan Return QR
  Widget _buildLenderSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner,
              size: 48,
              color: Colors.green.shade700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Confirm Item Return',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan the borrower\'s Return QR code to confirm they returned the item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanReturnQr,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Return QR'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  color: Colors.amber.shade700,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You\'ll verify item condition after scanning. Deposit will be refunded or transferred based on your choice.',
                    style: TextStyle(
                      color: Colors.amber.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            color: Colors.red.shade700,
            onPressed: _loadTransaction,
            tooltip: 'Retry',
          ),
        ],
      ),
    );
  }
}
