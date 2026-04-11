import 'package:flutter/material.dart';

class PageNouvelleVente extends StatelessWidget {
  final int commercantId;
  const PageNouvelleVente({super.key, required this.commercantId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nouvelle Vente")),
      body: const Center(child: Text("Formulaire de vente (À implémenter)")),
    );
  }
}