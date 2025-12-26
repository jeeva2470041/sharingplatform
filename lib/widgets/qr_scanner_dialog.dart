import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../app_theme.dart';

/// A dialog widget that opens a camera to scan QR codes
class QrScannerDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const QrScannerDialog({
    super.key,
    this.title = 'Scan QR Code',
    this.subtitle = 'Point your camera at the QR code',
    this.accentColor = AppTheme.primary,
  });

  @override
  State<QrScannerDialog> createState() => _QrScannerDialogState();
}

class _QrScannerDialogState extends State<QrScannerDialog> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  bool _hasScanned = false;
  String? _scannedCode;
  bool _isFlashOn = false;
  bool _showManualEntry = false;
  final TextEditingController _manualController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null && barcode.rawValue!.isNotEmpty) {
        setState(() {
          _hasScanned = true;
          _scannedCode = barcode.rawValue;
        });
        
        // Show success feedback briefly then close
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pop(context, _scannedCode);
          }
        });
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [widget.accentColor, widget.accentColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code_scanner, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 18,
                            fontWeight: AppTheme.fontWeightBold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontFamily: AppTheme.fontFamily,
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Camera or Manual Entry
            Flexible(
              child: _showManualEntry ? _buildManualEntry() : _buildCameraView(),
            ),
            
            // Bottom actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  // Toggle manual entry
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showManualEntry = !_showManualEntry;
                      });
                    },
                    icon: Icon(
                      _showManualEntry ? Icons.camera_alt : Icons.keyboard,
                      size: 18,
                    ),
                    label: Text(_showManualEntry ? 'Use Camera' : 'Enter Manually'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  if (!_showManualEntry) ...[
                    // Flash toggle
                    IconButton(
                      onPressed: () async {
                        try {
                          await _controller.toggleTorch();
                          setState(() {
                            _isFlashOn = !_isFlashOn;
                          });
                        } catch (e) {
                          // Flash not available or controller not ready
                          debugPrint('Flash toggle error: $e');
                        }
                      },
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: _isFlashOn ? AppTheme.warning : AppTheme.textSecondary,
                      ),
                      tooltip: 'Toggle Flash',
                    ),
                    // Switch camera
                    IconButton(
                      onPressed: () {
                        try {
                          _controller.switchCamera();
                        } catch (e) {
                          debugPrint('Switch camera error: $e');
                        }
                      },
                      icon: const Icon(Icons.cameraswitch, color: AppTheme.textSecondary),
                      tooltip: 'Switch Camera',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraView() {
    return Container(
      height: 350,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 2),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          children: [
            // Camera
            MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (context, error) {
                return _buildCameraError(error.errorCode.name);
              },
            ),
            
            // Scanning overlay
            if (!_hasScanned)
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    border: Border.all(color: widget.accentColor, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Corner decorations
                      ..._buildCorners(),
                      // Scanning line animation
                      _buildScanningLine(),
                    ],
                  ),
                ),
              ),
            
            // Success overlay
            if (_hasScanned)
              Container(
                color: Colors.black54,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.success,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 48),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'QR Code Scanned!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraError(String error) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'Camera not available',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 16,
                fontWeight: AppTheme.fontWeightSemibold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please use manual entry or\ngrant camera permission',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _showManualEntry = true;
                });
              },
              icon: const Icon(Icons.keyboard, size: 18),
              label: const Text('Enter Manually'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCorners() {
    const cornerSize = 24.0;
    const cornerThickness = 4.0;
    final color = widget.accentColor;

    return [
      // Top left
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      // Top right
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      // Bottom left
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
      // Bottom right
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerSize,
          height: cornerThickness,
          color: color,
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Container(
          width: cornerThickness,
          height: cornerSize,
          color: color,
        ),
      ),
    ];
  }

  Widget _buildScanningLine() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Positioned(
          top: value * 240,
          left: 8,
          right: 8,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  widget.accentColor,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
      onEnd: () {
        if (mounted && !_hasScanned) {
          setState(() {}); // Restart animation
        }
      },
    );
  }

  Widget _buildManualEntry() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.keyboard_alt_outlined,
            size: 48,
            color: widget.accentColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter the QR code manually',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 16,
              fontWeight: AppTheme.fontWeightSemibold,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ask the other person to read out the code displayed below their QR',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: 13,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _manualController,
            decoration: InputDecoration(
              labelText: 'QR Code',
              hintText: 'TXN_... or RETURN_...',
              prefixIcon: Icon(Icons.qr_code, color: widget.accentColor),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accentColor, width: 2),
              ),
            ),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              if (_manualController.text.isNotEmpty) {
                Navigator.pop(context, _manualController.text.trim());
              }
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirm Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.accentColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the QR scanner dialog
Future<String?> showQrScannerDialog(
  BuildContext context, {
  String title = 'Scan QR Code',
  String subtitle = 'Point your camera at the QR code',
  Color accentColor = AppTheme.primary,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) => QrScannerDialog(
      title: title,
      subtitle: subtitle,
      accentColor: accentColor,
    ),
  );
}
