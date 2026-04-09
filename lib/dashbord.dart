import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

// ══════════════════════════════════════════════════════════════
// MODÈLES DE DONNÉES
// ══════════════════════════════════════════════════════════════

class Transaction {
  final String nom;
  final String type;
  final int montant;
  final String date;
  final bool isCredit;
  const Transaction({
    required this.nom,
    required this.type,
    required this.montant,
    required this.date,
    required this.isCredit,
  });
}

// ══════════════════════════════════════════════════════════════
//  PAGE DASHBOARD
// ══════════════════════════════════════════════════════════════
class DashboardPage extends StatefulWidget {
  final String nomBoutique;
  final String nomCommercant;
  final String ville;

  const DashboardPage({
    super.key,
    this.nomBoutique = 'Boutique Al Amine',
    this.nomCommercant = 'Moussa Bâ',
    this.ville = 'Touba',
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  static const _green = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _amberMid = Color(0xFFFAC775);
  static const _grey = Color(0xFFF4F4F2);
  static const _textMuted = Color(0xFF6B7280);

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double> _sidebarAnim;

  final List<Transaction> _transactions = const [
    Transaction(nom: 'Aminata Baldé', type: 'vente', montant: 12500, date: 'Auj. 10:32', isCredit: true),
    Transaction(nom: 'Oumar Diallo', type: 'dette', montant: 8000, date: 'Auj. 09:15', isCredit: false),
    Transaction(nom: 'Fourni-Stock Dakar', type: 'stock', montant: 45000, date: 'Hier 16:45', isCredit: false),
    Transaction(nom: 'Mariama Kouyaté', type: 'vente', montant: 22000, date: 'Hier 14:20', isCredit: true),
    Transaction(nom: 'Ibrahima Sarr', type: 'remboursement', montant: 5000, date: 'Hier 11:05', isCredit: true),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _sidebarAnim = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  // --- METHODES DE LOGIQUE ---

  void _toggleSidebar() {
    setState(() => _sidebarOpen = !_sidebarOpen);
    _sidebarOpen ? _sidebarCtrl.forward() : _sidebarCtrl.reverse();
  }

  void _closeSidebar() {
    if (_sidebarOpen) {
      setState(() => _sidebarOpen = false);
      _sidebarCtrl.reverse();
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  Future<void> _deconnecter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
      (route) => false,
    );
  }

  // --- WIDGETS REUTILISABLES ---

  Widget _QuickBtn({required IconData icon, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: _green),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _line() => Container(width: 18, height: 2, color: Colors.white);

  Widget _balItem(String title, String value, Color color) {
    return Expanded(
      child: Column(children: [
        Text(title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
    );
  }

  // --- SECTIONS DE LA PAGE ---

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: _toggleSidebar,
              child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                  child: Column(children: [_line(), const SizedBox(height: 4), _line(), const SizedBox(height: 4), _line()]))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bonjour 👋', style: TextStyle(color: Colors.white70, fontSize: 12)),
            Text(widget.nomCommercant, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
          ])),
          CircleAvatar(backgroundColor: _amberMid, child: Text(widget.nomCommercant[0])),
        ]),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.13), borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _balItem('Ventes du jour', '87 500 F', Colors.white),
            _balItem('Dettes en cours', '34 200 F', _amberMid),
          ]),
        ),
      ]),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _QuickBtn(icon: Icons.add_shopping_cart, label: 'Vente', onTap: () => _showSnack(context, 'Nouvelle Vente')),
        _QuickBtn(icon: Icons.person_add, label: 'Client', onTap: () => _showSnack(context, 'Nouveau Client')),
        _QuickBtn(icon: Icons.history, label: 'Historique', onTap: () => _showSnack(context, 'Historique')),
      ]),
    );
  }

  Widget _buildTransactions() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _transactions.length,
      itemBuilder: (context, index) {
        final t = _transactions[index];
        return ListTile(
          leading: CircleAvatar(backgroundColor: t.isCredit ? _greenLight : Colors.red[50], 
                 child: Icon(t.isCredit ? Icons.arrow_upward : Icons.arrow_downward, color: t.isCredit ? _green : Colors.red)),
          title: Text(t.nom),
          subtitle: Text(t.date),
          trailing: Text('${t.montant} F', style: const TextStyle(fontWeight: FontWeight.bold)),
        );
      },
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 280,
      color: Colors.white,
      child: Column(children: [
        const DrawerHeader(child: Center(child: Text('Menu Boutique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
        ListTile(leading: const Icon(Icons.logout), title: const Text('Déconnexion'), onTap: _deconnecter),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: Stack(children: [
        SafeArea(child: GestureDetector(
          onTap: _closeSidebar,
          child: Column(children: [
            _buildHeader(),
            Expanded(child: SingleChildScrollView(
              child: Column(children: [_buildQuickActions(), _buildTransactions()]),
            )),
          ]),
        )),
        if (_sidebarOpen) GestureDetector(onTap: _closeSidebar, child: Container(color: Colors.black45)),
        AnimatedBuilder(
          animation: _sidebarAnim,
          builder: (context, child) => Transform.translate(offset: Offset(-280 * (1 - _sidebarAnim.value), 0), child: child),
          child: _buildSidebar(),
        ),
      ]),
    );
  }
}