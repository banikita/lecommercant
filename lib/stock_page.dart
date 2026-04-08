import 'package:flutter/material.dart';

class StockPage extends StatefulWidget {
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Map<String, dynamic>> _produits = [
    {'nom': 'Riz 5kg', 'quantite': 10},
    {'nom': 'Huile 1L', 'quantite': 5},
  ];

  void _changerQuantite(int index, int delta) {
    setState(() {
      int nouvelle = _produits[index]['quantite'] + delta;
      if (nouvelle >= 0) {
        _produits[index]['quantite'] = nouvelle;
      }
    });
  }

  void _ajouterProduit() {
    final nomCtrl = TextEditingController();
    final qteCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau produit'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomCtrl, decoration: InputDecoration(labelText: 'Nom produit')),
            SizedBox(height: 10),
            TextField(controller: qteCtrl, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Quantité')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (nomCtrl.text.isNotEmpty && qteCtrl.text.isNotEmpty) {
                setState(() {
                  _produits.add({'nom': nomCtrl.text, 'quantite': int.parse(qteCtrl.text)});
                });
                Navigator.pop(context);
              }
            },
            child: Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stock'), backgroundColor: Colors.green),
      body: ListView.builder(
        itemCount: _produits.length,
        itemBuilder: (context, index) {
          final p = _produits[index];
          return Card(
            margin: EdgeInsets.all(8),
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(Icons.inventory, size: 40, color: Colors.green),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['nom'], style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('Quantité : ${p['quantite']}'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.remove, color: Colors.red),
                    onPressed: () => _changerQuantite(index, -1),
                  ),
                  Text('${p['quantite']}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.add, color: Colors.green),
                    onPressed: () => _changerQuantite(index, 1),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterProduit,
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
      ),
    );
  }
}