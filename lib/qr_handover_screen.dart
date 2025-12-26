import 'dart:math';
import 'package:flutter/material.dart';
import 'data/mock_data.dart';
import 'services/transaction_service.dart';
import 'models/transaction.dart';

/// Screen for QR code handover verification
/// Lender generates and displays QR, Borrower scans to confirm physical handover
class QrHandoverScreen extends StatefulWidget {
  final String transactionId;
  final bool isLender;

  const QrHandoverScreen({
    super.key,
    required this.transactionId,
    required this.isLender,
  });

  @override
  State<QrHandoverScreen> createState() => _QrHandoverScreenState();
}

class _QrHandoverScreenState extends State<QrHandoverScreen> {
  String? _qrCode;
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
        // Check if QR was already generated
        _qrCode = transaction.qrCode;
        _qrGenerated =
            transaction.qrCode != null && transaction.qrCode!.isNotEmpty;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Check if transaction is approved and ready for QR generation
  bool get _isApproved => _transaction?.status == TransactionStatus.approved;

  /// Check if QR can be generated (lender + approved + not yet generated)
  bool get _canGenerateQr => widget.isLender && _isApproved && !_qrGenerated;

  Future<void> _generateQrCode() async {
    if (!_canGenerateQr) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final qrCode = await TransactionService.initiateHandover(
        widget.transactionId,
      );

      setState(() {
        _qrCode = qrCode;
        _qrGenerated = true;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR Code generated! Show it to the borrower.'),
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

  Future<void> _scanQrCode() async {
    final codeController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.teal),
            SizedBox(width: 12),
            Text('Enter QR Code'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ask the lender to show you their QR code and enter the code below:',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'QR Code',
                hintText: 'TXN_...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.qr_code),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, codeController.text),
            icon: const Icon(Icons.check),
            label: const Text('Confirm Receipt'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _confirmHandover(result);
    }
  }

  Future<void> _confirmHandover(String qrCode) async {
    setState(() => _isLoading = true);

    try {
      await TransactionService.confirmHandoverWithQR(qrCode);

      // Reload wallet to show updated balance
      await MockData.loadWallet();

      if (!mounted) return;

      final lockedAmount =
          _transaction?.depositAmount.toStringAsFixed(0) ?? '0';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Handover confirmed! ₹$lockedAmount has been locked from your balance.',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true); // Return success
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Handover failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(widget.isLender ? 'Handover Item' : 'Receive Item'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
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

                  // Main Content based on role and state
                  if (widget.isLender)
                    _buildLenderSection()
                  else
                    _buildBorrowerSection(),

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.teal.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: Colors.teal.shade700,
                ),
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
                        Icon(
                          Icons.monetization_on,
                          size: 16,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Deposit: ₹${_transaction!.depositAmount.toStringAsFixed(0)}',
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
              // Status indicator
              _buildStatusChip(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip() {
    Color bgColor;
    Color textColor;
    String text;
    IconData icon;

    switch (_transaction?.status) {
      case TransactionStatus.approved:
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        text = 'Approved';
        icon = Icons.check_circle;
        break;
      case TransactionStatus.active:
        bgColor = Colors.teal.shade50;
        textColor = Colors.teal.shade700;
        text = 'Active';
        icon = Icons.swap_horiz;
        break;
      case TransactionStatus.requested:
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        text = 'Pending';
        icon = Icons.hourglass_empty;
        break;
      default:
        bgColor = Colors.grey.shade100;
        textColor = Colors.grey.shade700;
        text = 'Unknown';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  /// Lender section: Generate QR or show generated QR
  Widget _buildLenderSection() {
    // Case 1: QR already generated - show it
    if (_qrGenerated && _qrCode != null) {
      return _buildQrDisplay();
    }

    // Case 2: Not approved yet - show warning
    if (!_isApproved) {
      return _buildNotApprovedWarning();
    }

    // Case 3: Approved but QR not generated - show generate button
    return _buildGenerateQrSection();
  }

  /// Approve the request directly from this screen
  Future<void> _approveRequest() async {
    if (_transaction == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await TransactionService.approveRequest(_transaction!.id);

      // Reload transaction to get updated status
      await _loadTransaction();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Request approved! You can now generate QR.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to approve: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildNotApprovedWarning() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.pending_actions, size: 48, color: Colors.orange.shade700),
          const SizedBox(height: 16),
          Text(
            'Approval Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'The borrower\'s request needs to be approved before you can generate a QR code for handover.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.orange.shade800),
          ),
          const SizedBox(height: 24),
          // Approve Now button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _approveRequest,
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve Request Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Go Back'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildGenerateQrSection() {
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
              color: Colors.teal.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.qr_code_2, size: 48, color: Colors.teal.shade700),
          ),
          const SizedBox(height: 20),
          const Text(
            'Ready for Handover',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Generate a QR code when you\'re ready to hand over the item to the borrower.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _generateQrCode,
              icon: const Icon(Icons.qr_code),
              label: const Text('Generate QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
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
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Credits will be locked from borrower only after they scan the QR.',
                    style: TextStyle(color: Colors.blue.shade800, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrDisplay() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.teal.shade200, width: 2),
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
                  'QR Code Ready',
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
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: CustomPaint(
              painter: _QrCodePainter(_qrCode!),
              size: const Size(200, 200),
            ),
          ),
          const SizedBox(height: 16),

          // Instruction
          const Text(
            'Show this QR to borrower to confirm handover',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // QR Code text (copyable)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(
                  'Code:',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _qrCode!,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Warning
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
                  color: Colors.amber.shade800,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Borrower\'s credits will be locked when they scan this QR.',
                    style: TextStyle(
                      color: Colors.amber.shade900,
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

  /// Borrower section: Scan QR
  Widget _buildBorrowerSection() {
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
              color: Colors.purple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner,
              size: 48,
              color: Colors.purple.shade700,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Receive Item',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the lender to show you their QR code, then enter it below to confirm you received the item.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _scanQrCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Enter QR Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
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
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, color: Colors.orange.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Your deposit of ₹${_transaction?.depositAmount.toStringAsFixed(0) ?? '0'} will be locked after confirmation.',
                    style: TextStyle(
                      color: Colors.orange.shade800,
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

/// Custom painter for a simple QR-like visualization
class _QrCodePainter extends CustomPainter {
  final String code;

  _QrCodePainter(this.code);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;

    final random = Random(code.hashCode);
    final cellSize = size.width / 21;

    // Draw corner patterns (QR code markers)
    _drawCornerPattern(canvas, paint, 0, 0, cellSize);
    _drawCornerPattern(canvas, paint, size.width - 7 * cellSize, 0, cellSize);
    _drawCornerPattern(canvas, paint, 0, size.height - 7 * cellSize, cellSize);

    // Draw random data pattern
    for (int i = 8; i < 13; i++) {
      for (int j = 0; j < 21; j++) {
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
    for (int i = 0; i < 21; i++) {
      for (int j = 8; j < 13; j++) {
        if (j < 13 && i < 13) continue;
        if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(i * cellSize, j * cellSize, cellSize, cellSize),
            paint,
          );
        }
      }
    }
  }

  void _drawCornerPattern(
    Canvas canvas,
    Paint paint,
    double x,
    double y,
    double cellSize,
  ) {
    // Outer square
    canvas.drawRect(Rect.fromLTWH(x, y, 7 * cellSize, 7 * cellSize), paint);

    // Inner white square
    final whitePaint = Paint()..color = Colors.white;
    canvas.drawRect(
      Rect.fromLTWH(x + cellSize, y + cellSize, 5 * cellSize, 5 * cellSize),
      whitePaint,
    );

    // Center black square
    canvas.drawRect(
      Rect.fromLTWH(
        x + 2 * cellSize,
        y + 2 * cellSize,
        3 * cellSize,
        3 * cellSize,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
