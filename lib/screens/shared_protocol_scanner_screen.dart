import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/app_colors.dart';
import '../widgets/protocolflow_app_bar.dart';

class SharedProtocolScannerScreen extends StatefulWidget {
  const SharedProtocolScannerScreen({super.key});

  @override
  State<SharedProtocolScannerScreen> createState() =>
      _SharedProtocolScannerScreenState();
}

class _SharedProtocolScannerScreenState
    extends State<SharedProtocolScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        _handled = true;
        _controller.stop();
        Navigator.pop(context, value);
        return;
      }
    }
  }

  Future<void> _pasteLink() async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter sharing link'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(
            labelText: 'ProtocolFlow or Google Drive link',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted || value == null || value.isEmpty) return;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      appBar: ProtocolFlowAppBar(
        title: 'Scan Protocol',
        actions: [
          IconButton(
            tooltip: 'Enter sharing link',
            onPressed: _pasteLink,
            icon: const Icon(Icons.link),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _handleCapture,
                      ),
                      IgnorePointer(
                        child: Center(
                          child: Container(
                            width: 240,
                            height: 240,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 3,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 4, 24, 20),
              child: Text(
                'Center a ProtocolFlow sharing QR code in the frame.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
