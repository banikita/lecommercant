import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'scanner_page.dart';
final supabase = Supabase.instance.client;

class VentesPage extends StatefulWidget {
  const VentesPage({super.key});

  @override
  State<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends State<VentesPage> {
  static const Color green = Color(0xFF0F6E56);
  static const Color orange = Color(0xFFF57C00);
  bool _isLoading = true;
  List<Map<String, dynamic>> _ventes = [];

  @override
  void initState() {
    super.initState();
    _chargerHistorique();
  }

  // Charger l'historique des ventes depuis Supabase
  Future<void> _chargerHistorique() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('ventes')
          .select('*, products(name, category, price)')
          .order('date_vente', ascending: false);
      setState(() {
        _ventes = List<Map<String, dynamic>>.from(data);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Fonction pour gérer la vente par Scan
  Future<void> _vendreParScan() async {
    // Rediriger vers votre page Scanner existante
    final String? codeScanne = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ScannerPage(onScanned: (val) {})),
    );

    if (codeScanne != null) {
      _processVente(codeScanne);
    }
  }

  // Logique de mise à jour du stock après vente
  Future<void> _processVente(String barcode) async {
    try {
      // 1. Trouver le produit
      final prod = await supabase.from('products').select().eq('barcode', barcode).single();
      int nouvelleQte = prod['quantity'] - 1;

      if (nouvelleQte < 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Stock insuffisant !")));
        return;
      }

      // 2. Mettre à jour le stock et enregistrer la vente
      await supabase.from('products').update({'quantity': nouvelleQte}).eq('id', prod['id']);
      await supabase.from('ventes').insert({
        'product_id': prod['id'],
        'quantite': 1,
        'prix_total': prod['price'],
        'date_vente': DateTime.now().toIso8601String(),
      });

      _chargerHistorique(); // Actualiser la liste
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Vendu : ${prod['name']}")));
    } catch (e) {
      print("Erreur vente: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Historique des Ventes", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildHeaderStats(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: green))
                : _ventes.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(15),
                        itemCount: _ventes.length,
                        itemBuilder: (context, index) => _buildVenteCard(_ventes[index]),
                      ),
          ),
        ],
      ),
      // BOUTONS D'ACTION RAPIDE
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // BOUTON SCANNER (Très important pour l'illettrisme)
          FloatingActionButton.extended(
            heroTag: "scan",
            onPressed: _vendreParScan,
            backgroundColor: orange,
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            label: const Text("Vendre par Scan", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          // BOUTON ALLER AU STOCK
          FloatingActionButton.extended(
            heroTag: "stock",
            onPressed: () => Navigator.pushNamed(context, '/stock'),
            backgroundColor: green,
            icon: const Icon(Icons.inventory, color: Colors.white),
            label: const Text("Stock", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderStats() {
    double totalJour = _ventes.fold(0, (sum, item) => sum + (item['prix_total'] ?? 0));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: green,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Recette Totale", style: TextStyle(color: Colors.white70, fontSize: 16)),
          Text("${NumberFormat('#,###').format(totalJour)} FCFA", 
               style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildVenteCard(Map<String, dynamic> vente) {
    final produit = vente['products'];
    final DateTime date = DateTime.parse(vente['date_vente']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // IMAGE DU PRODUIT (Priorité au visuel)
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.asset(
                'assets/categories/${produit['category'].toString().toLowerCase()}.jpg',
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, color: Colors.grey, size: 40),
              ),
            ),
            const SizedBox(width: 15),
            // INFOS VENTE
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(produit['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(DateFormat('dd MMM à HH:mm', 'fr_FR').format(date), 
                       style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
            ),
            // PRIX
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text("${vente['prix_total']} F", 
                     style: const TextStyle(color: green, fontWeight: FontWeight.bold, fontSize: 16)),
                const Text("Vendu", style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("Aucune vente aujourd'hui", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}