import 'package:flutter/material.dart';

class FournisseursPage extends StatelessWidget {
  // Exemple de données : pour chaque produit, la liste des fournisseurs avec leurs prix
  final Map<String, List<Map<String, dynamic>>> _offres = {
    'Riz 5kg': [
      {'nom': 'Fournisseur A', 'prix': 3500},
      {'nom': 'Fournisseur B', 'prix': 3400},
      {'nom': 'Fournisseur C', 'prix': 3600},
    ],
    'Huile 1L': [
      {'nom': 'Fournisseur A', 'prix': 1200},
      {'nom': 'Fournisseur B', 'prix': 1150},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Comparer fournisseurs'),
        backgroundColor: Colors.green,
      ),
      body: ListView(
        children: _offres.keys.map((produit) {
          final fournisseurs = _offres[produit]!;
          // Trier du moins cher au plus cher
          fournisseurs.sort((a, b) => a['prix'].compareTo(b['prix']));
          return Card(
            margin: EdgeInsets.all(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.shopping_bag, color: Colors.green),
                      SizedBox(width: 8),
                      Text(produit, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: 12),
                  ...fournisseurs.map((f) => ListTile(
                        leading: Icon(Icons.store),
                        title: Text(f['nom']),
                        trailing: Text('${f['prix']} FCFA', style: TextStyle(fontSize: 16)),
                      )),
                  // Le moins cher est en évidence
                  Container(
                    margin: EdgeInsets.only(top: 8),
                    padding: EdgeInsets.all(8),
                    color: Colors.green[50],
                    child: Row(
                      children: [
                        Icon(Icons.verified, color: Colors.green),
                        SizedBox(width: 8),
                        Text('Moins cher : ${fournisseurs.first['nom']} (${fournisseurs.first['prix']} FCFA)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}