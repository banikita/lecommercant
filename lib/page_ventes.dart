import 'package:flutter/material.dart';

class PageVentes extends StatelessWidget {
  final int commercantId;
  const PageVentes({super.key, required this.commercantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Historique des Ventes")),
      body: Center(child: Text("Ventes pour le commerçant #$commercantId")),
    );
  }
}