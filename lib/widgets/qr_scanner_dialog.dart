import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _QrScannerDialogState extends State<QrScannerDialog>
    with WidgetsBindingObserver {
  MobileScannerController? _controller;
  bool _hasScanned = false;
  String? _scannedCode;
  bool _isFlashOn = false;
  bool _showManualEntry = false;
  bool _isCameraReady = false;
  bool _hasError = false;
  String _errorMessage = '';
  final TextEditingController _manualController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeController();
  }

  void _initializeController() {
    try {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
        facing: CameraFacing.back,
        torchEnabled: false,
      );
      
      // Listen to controller state changes
      _controller!.addListener(_onControllerStateChanged);
      
      debugPrint('MobileScannerController created');
    } catch (e) {
      debugPrint('Error creating controller: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Failed to initialize camera controller';
        _showManualEntry = true;
      });
    }
  }
  
  void _onControllerStateChanged() {
    final state = _controller?.value;
    if (state == null) return;
    
    debugPrint('Controller state: isInitialized=${state.isInitialized}, isRunning=${state.isRunning}, hasCameraPermission=${state.hasCameraPermission}');
    
    if (state.isRunning && !_isCameraReady && mounted) {
      setState(() {
        _isCameraReady = true;
      });
      debugPrint('Camera is now ready!');
    }
    
    // Handle permission denied
    if (state.error != null && mounted && !_hasError) {
      setState(() {
        _hasError = true;
        _errorMessage = _getErrorMessage(state.error!);
        _showManualEntry = true;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_controller == null) return;

    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasScanned && !_showManualEntry && _controller != null) {
          _controller!.start();
        }
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _controller?.stop();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    _manualController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;

    final List<Barcode> barcodes = capture.barcodes;
    debugPrint('Detected ${barcodes.length} barcodes');

    for (final barcode in barcodes) {
      final value = barcode.rawValue;
      debugPrint('Barcode value: $value, format: ${barcode.format}');
      
      if (value != null && value.isNotEmpty) {
        if (!mounted) return;
        
        setState(() {
          _hasScanned = true;
          _scannedCode = value;
        });

        // Haptic feedback
        HapticFeedback.mediumImpact();

        // Stop scanning
        _controller?.stop();

        // Close dialog with result after brief feedback
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            Navigator.pop(context, _scannedCode);
          }
        });
        break;
      }
    }
  }

  void _submitManualCode() {
    final code = _manualController.text.trim();
    if (code.isNotEmpty) {
      Navigator.pop(context, code);
    }
  }

  void _retryCamera() {
    setState(() {
      _hasError = false;
      _showManualEntry = false;
      _isCameraReady = false;
    });
    
    // Dispose old controller
    _controller?.removeListener(_onControllerStateChanged);
    _controller?.dispose();
    _controller = null;
    
    // Create new controller
    _initializeController();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 620),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),

            // Camera or Manual Entry
            Flexible(
              child: _showManualEntry ? _buildManualEntry() : _buildCameraView(),
            ),

            // Bottom actions
            _buildBottomActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
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
    );
  }

  Widget _buildCameraView() {
    // Show error state
    if (_hasError) {
      return _buildErrorView();
    }

    // Show camera
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
            // Camera preview using simple onDetect approach
            if (_controller != null)
              MobileScanner(
                controller: _controller!,
                fit: BoxFit.cover,
                onDetect: (capture) {
                  // Mark camera as ready on first detection attempt
                  if (!_isCameraReady && mounted) {
                    setState(() {
                      _isCameraReady = true;
                    });
                  }
                  _onDetect(capture);
                },
                errorBuilder: (context, error) {
                  debugPrint('MobileScanner error: ${error.errorCode}');
                  // Show error in UI
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_hasError) {
                      setState(() {
                        _hasError = true;
                        _errorMessage = _getErrorMessage(error);
                        _showManualEntry = true;
                      });
                    }
                  });
                  return _buildCameraErrorWidget(error.errorCode.name);
                },
                placeholderBuilder: (context) {
                  // Once placeholder is no longer shown, camera is ready
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_isCameraReady) {
                      setState(() {
                        _isCameraReady = true;
                      });
                    }
                  });
                  return Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: AppTheme.primary),
                          SizedBox(height: 16),
                          Text(
                            'Starting camera...',
                            style: TextStyle(
                              fontFamily: AppTheme.fontFamily,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            // Scanning overlay
            if (!_hasScanned && _isCameraReady) _buildScanOverlay(),

            // Success overlay
            if (_hasScanned) _buildSuccessOverlay(),
          ],
        ),
      ),
    );
  }

  String _getErrorMessage(MobileScannerException error) {
    switch (error.errorCode) {
      case MobileScannerErrorCode.permissionDenied:
        return 'Camera permission denied. Please allow camera access in your browser settings.';
      case MobileScannerErrorCode.unsupported:
        return 'Camera not supported on this device or browser.';
      default:
        return 'Could not access camera. ${error.errorDetails?.message ?? ''}';
    }
  }

  Widget _buildScanOverlay() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner markers
                Positioned(top: -1, left: -1, child: _buildCorner(true, true)),
                Positioned(top: -1, right: -1, child: _buildCorner(true, false)),
                Positioned(bottom: -1, left: -1, child: _buildCorner(false, true)),
                Positioned(bottom: -1, right: -1, child: _buildCorner(false, false)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Position QR code inside the frame',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(bool isTop, bool isLeft) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        border: Border(
          top: isTop
              ? BorderSide(color: widget.accentColor, width: 4)
              : BorderSide.none,
          bottom: !isTop
              ? BorderSide(color: widget.accentColor, width: 4)
              : BorderSide.none,
          left: isLeft
              ? BorderSide(color: widget.accentColor, width: 4)
              : BorderSide.none,
          right: !isLeft
              ? BorderSide(color: widget.accentColor, width: 4)
              : BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildSuccessOverlay() {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
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
    );
  }

  Widget _buildErrorView() {
    return Container(
      height: 350,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border, width: 2),
        color: Colors.grey.shade100,
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.camera_alt_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'Camera Unavailable',
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 18,
                  fontWeight: AppTheme.fontWeightBold,
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _retryCamera,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Retry'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showManualEntry = true;
                      });
                    },
                    icon: const Icon(Icons.keyboard, size: 18),
                    label: const Text('Enter Code'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraErrorWidget(String errorCode) {
    return Container(
      color: Colors.grey.shade100,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              'Camera Error',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorCode,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _showManualEntry = true;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Enter code manually'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntry() {
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.keyboard_alt_outlined,
              size: 64,
              color: widget.accentColor.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter Code Manually',
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 18,
                fontWeight: AppTheme.fontWeightBold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask the other person to share their handover code',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppTheme.fontFamily,
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _manualController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                fontSize: 18,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter handover code',
                prefixIcon: const Icon(Icons.qr_code),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.accentColor, width: 2),
                ),
              ),
              onSubmitted: (_) => _submitManualCode(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitManualCode,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.accentColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Submit Code',
                  style: TextStyle(
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: AppTheme.fontWeightSemibold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
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
          // Toggle manual entry / camera
          TextButton.icon(
            onPressed: () {
              setState(() {
                _showManualEntry = !_showManualEntry;
                if (!_showManualEntry && _hasError) {
                  _retryCamera();
                }
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
          if (!_showManualEntry && !_hasError && _isCameraReady) ...[
            // Flash toggle
            IconButton(
              onPressed: () async {
                try {
                  await _controller?.toggleTorch();
                  setState(() {
                    _isFlashOn = !_isFlashOn;
                  });
                } catch (e) {
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
              onPressed: () async {
                try {
                  await _controller?.switchCamera();
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
