import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.unrestricted,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _handled = false;
  bool _torchEnabled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () async {
              await _controller.toggleTorch();
              if (!mounted) {
                return;
              }
              setState(() => _torchEnabled = !_torchEnabled);
            },
            icon: Icon(
              _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _handleDetect,
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white, width: 2),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x8C000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Text(
                    'Point camera at a VPN QR code (vless/vmess/trojan/ss).',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    final value = capture.barcodes.map(_extractBarcodeValue).firstWhere(
          (item) => item.isNotEmpty,
          orElse: () => '',
        );
    if (value.isEmpty) {
      return;
    }

    debugPrint('QR Code Result (${value.length} chars) ===> $value');

    _handled = true;
    Navigator.of(context).pop(value);
  }

  String _extractBarcodeValue(Barcode barcode) {
    final rawValue = barcode.rawValue;
    if (rawValue != null && rawValue.trim().isNotEmpty) {
      return _sanitize(rawValue);
    }

    final displayValue = barcode.displayValue;
    if (displayValue != null && displayValue.trim().isNotEmpty) {
      return _sanitize(displayValue);
    }

    final bytes = barcode.rawBytes;
    if (bytes != null && bytes.isNotEmpty) {
      return _sanitize(String.fromCharCodes(bytes));
    }

    return '';
  }

  /// Strip null bytes, BOM, and invisible control characters that
  /// some QR encoders / scanners inject.
  String _sanitize(String value) {
    return value
        .replaceAll('\u0000', '')
        .replaceAll('\uFEFF', '')
        .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
        .trim();
  }
}
