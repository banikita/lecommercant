import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  // AJOUT : On déclare le paramètre onScanned
  final Function(String)? onScanned;

  // AJOUT : On l'ajoute au constructeur
  const ScannerPage({super.key, this.onScanned});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController cameraController = MobileScannerController();
  bool isScanCompleted = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner le produit"),
        backgroundColor: const Color(0xFF0F6E56),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: cameraController,
              builder: (context, state, child) {
                return Icon(
                  cameraController.torchEnabled ? Icons.flash_on : Icons.flash_off,
                  color: cameraController.torchEnabled ? Colors.yellow : Colors.white,
                );
              },
            ),
            onPressed: () => cameraController.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: cameraController,
        onDetect: (capture) {
          if (!isScanCompleted) {
            final List<Barcode> barcodes = capture.barcodes;

            if (barcodes.isNotEmpty) {
              final String code = barcodes.first.rawValue ?? "Inconnu";
              isScanCompleted = true;

              // CORRECTION : On vérifie si onScanned a été fourni
              if (widget.onScanned != null) {
                widget.onScanned!(code);
              } else {
                // Comportement par défaut si aucun callback n'est passé
                Navigator.pop(context, code);
              }
            }
          }
        },
      ),
    );
  }
}