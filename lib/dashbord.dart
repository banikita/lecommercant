import 'package:flutter/material.dart';
import 'package:le_commercant/database/app_database.dart';
import 'login.dart';
import 'dettes.dart';
import 'page_fournisseurs.dart';
import 'page_stock.dart';
import 'page_ventes.dart';
import 'page_nouvelle_vente.dart';

// ══════════════════════════════════════════════════════════════
//  DASHBOARD — Branché sur AppDatabase
//
//  Lecture DB :
//    • AppDatabase.chargerTransactionsRecentes() → liste du bas
//    • AppDatabase.ventesAujourdhui()            → chiffre vert
//    • AppDatabase.dettesEnCours()               → chiffre amber
//  Écriture DB :
//    • AppDatabase.fermerSession()               → déconnexion
// ══════════════════════════════════════════════════════════════

class DashboardPage extends StatefulWidget {
  final int    commercantId;
  final String nomCommercant;
  final String nomBoutique;
  final String ville;

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

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {

  static const _green      = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red        = Color(0xFFA32D2D);
  static const _redLight   = Color(0xFFFCEBEB);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid   = Color(0xFFFAC775);
  static const _blueLight  = Color(0xFFE6F1FB);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _textMuted  = Color(0xFF6B7280);

  final _db = AppDatabase.instance;

  // ── Données chargées depuis SQLite
  List<Map<String, dynamic>> _transactions = [];
  double _ventesJour   = 0;
  double _dettesEnCours = 0;
  bool   _loading       = true;

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarAnim;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 280));
    _sidebarAnim = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────
  //  CHARGEMENT DB
  // ──────────────────────────────────────
  Future<void> _chargerDonnees() async {
    setState(() => _loading = true);
    final transactions = await _db.chargerTransactionsRecentes(
        widget.commercantId, limite: 5);
    final ventes  = await _db.ventesAujourdhui(widget.commercantId);
    final dettes  = await _db.dettesEnCours(widget.commercantId);
    setState(() {
      _transactions  = transactions;
      _ventesJour    = ventes;
      _dettesEnCours = dettes;
      _loading       = false;
    });
  }

  // ──────────────────────────────────────
  //  DÉCONNEXION — ferme session en DB
  // ──────────────────────────────────────
  Future<void> _deconnecter() async {
    _closeSidebar();
    await _db.fermerSession(widget.commercantId);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => LoginPage(
        commercantId:  widget.commercantId,
        nomCommercant: widget.nomCommercant,
        nomBoutique:   widget.nomBoutique,
        ville:         widget.ville,
      ),
      transitionsBuilder: (_, a, __, child) =>
          FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ), (_) => false);
  }

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

  void _goTo(Widget page) {
    _closeSidebar();
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _chargerDonnees()); // Recharger à la fin
  }

  String get _initiales {
    final p = widget.nomCommercant.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  String _fmt(double n) => n.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: Stack(children: [
        SafeArea(child: GestureDetector(
          onTap: _closeSidebar,
          child: Column(children: [
            _buildHeader(),
            Expanded(child: _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : RefreshIndicator(
                  onRefresh: _chargerDonnees, color: _green,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildQuickActions(),
                      _buildNewSaleBtn(),
                      _buildTransactions(),
                      const SizedBox(height: 24),
                    ])))),
          ]))),

        // Overlay sidebar
        AnimatedBuilder(animation: _sidebarAnim,
          builder: (_, __) => _sidebarOpen
            ? GestureDetector(onTap: _closeSidebar,
                child: Container(color: Colors.black.withOpacity(0.42 * _sidebarAnim.value)))
            : const SizedBox.shrink()),

        // Sidebar
        AnimatedBuilder(animation: _sidebarAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(-280 * (1 - _sidebarAnim.value), 0), child: child),
          child: _buildSidebar()),
      ]),
    );
  }

  // ══════════════════════════════════════
  //  HEADER — données réelles depuis DB
  // ══════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: _green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: _toggleSidebar,
            child: Container(padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _hamLine(), const SizedBox(height: 4),
                _hamLine(), const SizedBox(height: 4),
                _hamLine()]))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bonjour 👋',
                style: TextStyle(color: Colors.white70, fontSize: 12, height: 1)),
            const SizedBox(height: 3),
            Text(widget.nomCommercant, style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ])),
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _amberMid, shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.35), width: 2)),
            child: Center(child: Text(_initiales, style: const TextStyle(
                color: Color(0xFF633806), fontSize: 14, fontWeight: FontWeight.w800)))),
        ]),
        const SizedBox(height: 14),

        // ── Résumé : données réelles DB
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            // Ventes du jour lues depuis SQLite
            Expanded(child: Column(children: [
              const Text('Ventes du jour', style: TextStyle(
                  color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_fmt(_ventesJour)} F', style: const TextStyle(
                  color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            ])),
            Container(height: 36, width: 0.5, color: Colors.white.withOpacity(0.3)),
            // Dettes en cours lues depuis SQLite
            Expanded(child: Column(children: [
              const Text('Dettes en cours', style: TextStyle(
                  color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_fmt(_dettesEnCours)} F', style: const TextStyle(
                  color: _amberMid, fontSize: 18, fontWeight: FontWeight.w800)),
            ])),
          ])),
      ]));
  }

  Widget _hamLine() => Container(width: 18, height: 2.5,
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)));

  // ══════════════════════════════════════
  //  ACCÈS RAPIDES
  // ══════════════════════════════════════
  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Text('ACCÈS RAPIDE', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800,
            color: _textMuted, letterSpacing: 0.8))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          _QBtn(label: 'Dettes\nclients', emoji: '💸', bg: _redLight,
              onTap: () => _goTo(const PageDettes())),
          const SizedBox(width: 10),
          _QBtn(label: 'Fournis-\nseurs', emoji: '🏭', bg: _blueLight,
              onTap: () => _goTo(const PageFournisseurs())),
          const SizedBox(width: 10),
          _QBtn(label: 'Stock', emoji: '🧺', bg: _greenLight,
              onTap: () => _goTo(const StockPage())),
          const SizedBox(width: 10),
          _QBtn(label: 'Mes\nventes', emoji: '📈', bg: _amberLight,
              onTap: () => _goTo(const PageVentes(commercantId: 0))),
        ])),
    ]);
  }

  // ══════════════════════════════════════
  //  BOUTON NOUVELLE VENTE
  // ══════════════════════════════════════
  Widget _buildNewSaleBtn() => Padding(
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
    child: GestureDetector(
      onTap: () => _goTo(PageNouvelleVente(commercantId: widget.commercantId)),
      child: Container(width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('➕', style: TextStyle(fontSize: 20)),
          SizedBox(width: 10),
          Text('Enregistrer une nouvelle vente',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
        ]))));

  // ══════════════════════════════════════
  //  TRANSACTIONS — lues depuis SQLite
  // ══════════════════════════════════════
  Widget _buildTransactions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          const Text('TRANSACTIONS RÉCENTES', style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800,
              color: _textMuted, letterSpacing: 0.8)),
          const Spacer(),
          GestureDetector(
            onTap: () => _goTo(PageVentes(commercantId: widget.commercantId)),
            child: const Text('Voir tout', style: TextStyle(
                color: _green, fontSize: 12, fontWeight: FontWeight.w700))),
        ])),

      if (_transactions.isEmpty)
        const Center(child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Aucune transaction pour le moment',
              style: TextStyle(color: _textMuted, fontSize: 13))))
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => _TxCard(tx: _transactions[i])),
    ]);
  }

  // ══════════════════════════════════════
  //  SIDEBAR
  // ══════════════════════════════════════
  Widget _buildSidebar() {
    return Container(
      width: 280, height: double.infinity, color: Colors.white,
      child: SafeArea(child: Column(children: [
        Container(width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
          color: _green,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 56, height: 56,
              decoration: BoxDecoration(color: _amberMid, shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
              child: Center(child: Text(_initiales, style: const TextStyle(
                  color: Color(0xFF633806), fontSize: 20, fontWeight: FontWeight.w800)))),
            const SizedBox(height: 10),
            Text(widget.nomCommercant, style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${widget.nomBoutique} · ${widget.ville}',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),

        Expanded(child: SingleChildScrollView(child: Column(children: [
          const SizedBox(height: 8),
          _SItem(emoji: '👤', label: 'Mon profil',           color: const Color(0xFFEEEDFE), onTap: () => _closeSidebar()),
          _SItem(emoji: '🔒', label: 'Biométrie & sécurité', color: _grey,        onTap: () => _closeSidebar()),
          _SItem(emoji: '🔔', label: 'Notifications',         color: _amberLight,  onTap: () => _closeSidebar()),
          _SItem(emoji: '📊', label: 'Rapports & stats',      color: _greenLight,  onTap: () => _closeSidebar()),
          _SItem(emoji: '⚙️',  label: 'Paramètres',           color: _grey,        onTap: () => _closeSidebar()),
          _SItem(emoji: '❓', label: 'Aide & support',         color: _blueLight,   onTap: () => _closeSidebar()),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Divider(height: 1, color: _greyMid)),
          // Déconnexion → ferme session en DB
          _SItem(emoji: '🚪', label: 'Se déconnecter',
              color: _redLight, textColor: _red, onTap: _deconnecter),
          const SizedBox(height: 16),
        ]))),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  WIDGETS RÉUTILISABLES
// ══════════════════════════════════════════════════════════════

class _QBtn extends StatelessWidget {
  final String label, emoji;
  final Color bg;
  final VoidCallback onTap;
  const _QBtn({required this.label, required this.emoji, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: GestureDetector(onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
        decoration: BoxDecoration(color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5)),
        child: Column(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22)))),
          const SizedBox(height: 7),
          Text(label, textAlign: TextAlign.center, style: const TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), height: 1.3)),
        ]))));
  }
}

// Carte transaction lisant les données SQLite brutes
class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;

  static const _typeBg  = {'vente': Color(0xFFEAF3DE), 'dette': Color(0xFFFCEBEB), 'stock': Color(0xFFFAEEDA), 'remboursement': Color(0xFFEAF3DE)};
  static const _typeClr = {'vente': Color(0xFF27500A), 'dette': Color(0xFF791F1F), 'stock': Color(0xFF633806), 'remboursement': Color(0xFF27500A)};
  static const _typeLbl = {'vente': 'Vente', 'dette': 'Dette', 'stock': 'Stock reçu', 'remboursement': 'Remboursement'};
  static const _avColors = [
    [Color(0xFFEAF3DE), Color(0xFF27500A)], [Color(0xFFFCEBEB), Color(0xFF791F1F)],
    [Color(0xFFE6F1FB), Color(0xFF0C447C)], [Color(0xFFFAEEDA), Color(0xFF633806)],
    [Color(0xFFEEEDFE), Color(0xFF3C3489)],
  ];

  const _TxCard({required this.tx});

  String get _nom     => tx['nom_client'] as String? ?? '—';
  String get _type    => tx['type']       as String? ?? 'vente';
  double get _montant => (tx['montant']   as num?)?.toDouble() ?? 0;
  bool   get _credit  => (tx['is_credit'] as int?) == 1;
  String get _date    => _formatDate(tx['date'] as String? ?? '');

  String _formatDate(String iso) {
    try {
      final d = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      if (d.day == now.day && d.month == now.month) {
        return 'Auj. ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
      }
      return 'Hier ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    } catch (_) { return '—'; }
  }

  String _ini() {
    final p = _nom.split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : _nom.length >= 2 ? _nom.substring(0,2).toUpperCase() : _nom.toUpperCase();
  }

  String _fmt(double n) => n.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final colors = _avColors[_nom.codeUnitAt(0) % _avColors.length];
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5)),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: colors[0], shape: BoxShape.circle),
          child: Center(child: Text(_ini(),
              style: TextStyle(color: colors[1], fontSize: 13, fontWeight: FontWeight.w800)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(_date, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _typeBg[_type], borderRadius: BorderRadius.circular(20)),
            child: Text(_typeLbl[_type] ?? _type, style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: _typeClr[_type]))),
        ])),
        Text('${_credit ? '+' : '-'}${_fmt(_montant)} F',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
                color: _credit ? const Color(0xFF0F6E56) : const Color(0xFFA32D2D))),
      ]));
  }
}

class _SItem extends StatelessWidget {
  final String emoji, label;
  final Color color, textColor;
  final VoidCallback onTap;
  const _SItem({required this.emoji, required this.label, required this.color,
      required this.onTap, this.textColor = const Color(0xFF1A1A1A)});

  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap,
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 18)))),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        ]))));
}