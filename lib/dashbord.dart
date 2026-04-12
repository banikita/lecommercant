import 'package:flutter/material.dart';
import 'package:le_commercant/database/app_database.dart';

class DashboardPage extends StatefulWidget {
  final int commercantId;
  final String nomCommercant;
  final String nomBoutique;
  final String ville;

  // Le constructeur doit accepter ces 4 paramètres obligatoires
  const DashboardPage({
    super.key,
    required this.commercantId,
    required this.nomCommercant,
    required this.nomBoutique,
    required this.ville,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final AppDatabase _db = AppDatabase.instance; // Utilisation de l'instance corrigée
  
  bool _loading = true;
  double _ventes = 0.0;
  double _dettes = 0.0;
  List<Map<String, dynamic>> _transactions = [];

  @override
  void initState() {
    super.initState();
    _chargerDonnees();
  }

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      // Ces méthodes existent maintenant dans ton app_database.dart complet
      final v = await _db.ventesAujourdhui(widget.commercantId);
      final d = await _db.dettesEnCours(widget.commercantId);
      final t = await _db.chargerTransactionsRecentes(widget.commercantId);

      if (mounted) {
        setState(() {
          _ventes = v;
          _dettes = d;
          _transactions = t;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Erreur Dashboard: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nomBoutique),
        backgroundColor: const Color(0xFF0F6E56),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerDonnees,
          )
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : RefreshIndicator(
            onRefresh: _chargerDonnees,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text("Bienvenue, ${widget.nomCommercant}", 
                     style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                
                _buildStatCard("Ventes (Aujourd'hui)", "$_ventes F", Colors.green),
                _buildStatCard("Dettes Clients", "$_dettes F", Colors.red),
                
                const SizedBox(height: 25),
                const Text("Dernières opérations", 
                           style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Divider(),

                if (_transactions.isEmpty)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Text("Aucune transaction"),
                  ))
                else
                  ..._transactions.map((t) => ListTile(
                    leading: Icon(
                      t['type'] == 'vente' ? Icons.add_circle : Icons.remove_circle,
                      color: t['type'] == 'vente' ? Colors.green : Colors.red,
                    ),
                    title: Text(t['nom_client'] ?? "Client"),
                    subtitle: Text(t['date'].toString()),
                    trailing: Text("${t['montant']} F", 
                                   style: const TextStyle(fontWeight: FontWeight.bold)),
                  )).toList(),
              ],
            ),
          ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Card(
      child: ListTile(
        title: Text(title),
        trailing: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
    );
  }
}