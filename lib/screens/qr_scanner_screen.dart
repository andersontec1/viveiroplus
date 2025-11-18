import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/degrade_fundo.dart';

class QRScannerScreen extends StatelessWidget {
  const QRScannerScreen({required this.onCodeScanned, super.key});
  final Function(String) onCodeScanned;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(
          'Escanear QR Code',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: DegradeFundo(
        child: MobileScanner(
          onDetect: (capture) {
            final barcode = capture.barcodes.first;
            final code = barcode.rawValue;
            if (code != null) {
              onCodeScanned(code);
              Navigator.pop(context);
            }
          },
        ),
      ),
    );
  }
}
