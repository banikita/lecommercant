import 'package:flutter/material.dart';

class DettesPage extends StatefulWidget {
  @override
  State<DettesPage> createState() => _DettesPageState();
}

class _DettesPageState extends State<DettesPage> {
  // Liste des dettes : chaque dette a un nom et un montant
  List<Map<String, dynamic>> _dettes = [
    {'nom': 'Mamadou', 'montant': 25000},
    {'nom': 'Fatou', 'montant': 12000},
  ];

  // Contrôleurs pour les champs du formulaire
  final TextEditingController _nomCtrl = TextEditingController();
  final TextEditingController _montantCtrl = TextEditingController();

  void _ajouterDette() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouvelle dette'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nomCtrl,
              decoration: InputDecoration(labelText: 'Nom client', prefixIcon: Icon(Icons.person)),
            ),
            SizedBox(height: 10),
            TextField(
              controller: _montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Montant (FCFA)', prefixIcon: Icon(Icons.money)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Annuler')),
          ElevatedButton(
            onPressed: () {
              if (_nomCtrl.text.isNotEmpty && _montantCtrl.text.isNotEmpty) {
                setState(() {
                  _dettes.add({
                    'nom': _nomCtrl.text,
                    'montant': int.parse(_montantCtrl.text),
                  });
                });
                _nomCtrl.clear();
                _montantCtrl.clear();
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
      appBar: AppBar(
        title: Text('Dettes clients'),
        backgroundColor: Colors.green,
      ),
      body: _dettes.isEmpty
          ? Center(child: Text('Aucune dette'))
          : ListView.builder(
              itemCount: _dettes.length,
              itemBuilder: (context, index) {
                final dette = _dettes[index];
                return Card(
                  margin: EdgeInsets.all(8),
                  child: ListTile(
                    leading: Icon(Icons.person, color: Colors.green),
                    title: Text(dette['nom'], style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${dette['montant']} FCFA'),
                    trailing: IconButton(
                      icon: Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        setState(() {
                          _dettes.removeAt(index);
                        });
                      },
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _ajouterDette,
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
      ),
    );
  }
}