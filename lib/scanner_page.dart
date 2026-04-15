import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  // Contrôleur pour gérer la caméra
  MobileScannerController cameraController = MobileScannerController();
  bool isScanCompleted = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scanner le produit"),
        backgroundColor: const Color(0xFF0F6E56),
        actions: [
          // Bouton pour allumer le flash
       IconButton(
  color: Colors.white,
  icon: ValueListenableBuilder(
    valueListenable: cameraController, // On écoute directement le contrôleur
    builder: (context, state, child) {
      // On vérifie si le flash est allumé ou éteint via le contrôleur
      return Icon(
        cameraController.torchEnabled ? Icons.flash_on : Icons.flash_off,
        color: cameraController.torchEnabled ? Colors.yellow : Colors.grey,
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
              isScanCompleted = true;
              final String code = barcodes.first.rawValue ?? "Inconnu";
              
              // On ferme le scanner et on renvoie le code à la page Ventes
              Navigator.pop(context, code);
            }
          }
        },
      ),
    );
  }
}