import 'dart:io';

import 'package:flutter/material.dart';
import 'package:qr_code_scanner_plus/qr_code_scanner_plus.dart';

class QrScanPage extends StatefulWidget {
  const QrScanPage({super.key});

  @override
  State<QrScanPage> createState() => _QrScanPageState();
}

class _QrScanPageState extends State<QrScanPage> {
  final GlobalKey _qrKey = GlobalKey(debugLabel: 'lunex_qr_scanner');
  QRViewController? _controller;

  bool _handled = false;
  bool _torchEnabled = false;

  @override
  void reassemble() {
    super.reassemble();
    final controller = _controller;
    if (controller == null) {
      return;
    }
    if (Platform.isAndroid) {
      controller.pauseCamera();
    }
    controller.resumeCamera();
  }

  @override
  void dispose() {
    _controller = null;
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
              final controller = _controller;
              if (controller == null) {
                return;
              }
              await controller.toggleFlash();
              final enabled = await controller.getFlashStatus() ?? false;
              if (!mounted) {
                return;
              }
              setState(() => _torchEnabled = enabled);
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
          QRView(
            key: _qrKey,
            onQRViewCreated: _onQrViewCreated,
            overlay: QrScannerOverlayShape(
              borderColor: Colors.white,
              borderRadius: 16,
              borderLength: 28,
              borderWidth: 6,
              cutOutSize: 250,
            ),
            onPermissionSet: _onPermissionSet,
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

  void _onQrViewCreated(QRViewController controller) {
    _controller = controller;
    controller.scannedDataStream.listen(_handleDetect);
    controller.getFlashStatus().then((enabled) {
      if (!mounted) {
        return;
      }
      setState(() => _torchEnabled = enabled ?? false);
    });
  }

  void _onPermissionSet(QRViewController controller, bool hasPermission) {
    if (hasPermission || !mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('Camera permission is required to scan QR.')),
    );
  }

  void _handleDetect(Barcode barcode) {
    if (_handled) {
      return;
    }

    final value = _extractBarcodeValue(barcode);
    if (value.isEmpty) {
      return;
    }

    debugPrint('QR Code Result (${value.length} chars) ===> $value');

    _handled = true;
    _controller?.pauseCamera();
    Navigator.of(context).pop(value);
  }

  String _extractBarcodeValue(Barcode barcode) {
    final code = barcode.code;
    if (code != null && code.trim().isNotEmpty) {
      return _sanitize(code);
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
