import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login.dart';

class Transaction {
  final String nom;
  final String type;
  final int montant;
  final String date;
  final bool isCredit;
  const Transaction({required this.nom, required this.type,
    required this.montant, required this.date, required this.isCredit});
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
    this.nomBoutique   = 'Boutique Al Amine',
    this.nomCommercant = 'Moussa Bâ',
    this.ville         = 'Touba',
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
  static const _amber      = Color(0xFF854F0B);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid   = Color(0xFFFAC775);
  static const _blue       = Color(0xFF185FA5);
  static const _blueLight  = Color(0xFFE6F1FB);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _border     = Color(0xFFE8E8E5);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double>   _sidebarAnim;

  final List<Transaction> _transactions = const [
    Transaction(nom: 'Aminata Baldé',    type: 'vente',         montant: 12500, date: 'Auj. 10:32', isCredit: true),
    Transaction(nom: 'Oumar Diallo',     type: 'dette',         montant: 8000,  date: 'Auj. 09:15', isCredit: false),
    Transaction(nom: 'Fourni-Stock Dakar', type: 'stock',       montant: 45000, date: 'Hier 16:45', isCredit: false),
    Transaction(nom: 'Mariama Kouyaté', type: 'vente',          montant: 22000, date: 'Hier 14:20', isCredit: true),
    Transaction(nom: 'Ibrahima Sarr',    type: 'remboursement', montant: 5000,  date: 'Hier 11:05', isCredit: true),
  ];

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 280));
    _sidebarAnim = CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
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

  // ── DÉCONNEXION : efface la session (is_logged_in = false)
  //    Le compte reste → prochain lancement affiche LoginPage
  Future<void> _deconnecter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginPage(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  String get _initials {
    final parts = widget.nomCommercant.trim().split(' ');
    return parts.length >= 2
        ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
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
              physics: const BouncingScrollPhysics(),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _buildQuickActions(),
                _buildNewSaleBtn(),
                _buildTransactions(),
                const SizedBox(height: 20),
              ]),
            )),
          ]),
        )),

        // Overlay
        AnimatedBuilder(
          animation: _sidebarAnim,
          builder: (_, __) => _sidebarOpen
            ? GestureDetector(onTap: _closeSidebar,
                child: Container(color: Colors.black.withOpacity(0.42 * _sidebarAnim.value)))
            : const SizedBox.shrink()),

        // Sidebar
        AnimatedBuilder(
          animation: _sidebarAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(-280 * (1 - _sidebarAnim.value), 0), child: child),
          child: _buildSidebar()),
      ]),
    );
  }

  // ── HEADER
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: _green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          // Hamburger
          GestureDetector(onTap: _toggleSidebar,
            child: Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                _line(), const SizedBox(height: 4), _line(), const SizedBox(height: 4), _line(),
              ]))),
          const SizedBox(width: 12),

          // Bienvenue
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Bonjour 👋',
              style: TextStyle(color: Colors.white70, fontSize: 12, height: 1)),
            const SizedBox(height: 3),
            Text(widget.nomCommercant,
              style: const TextStyle(
                color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
          ])),

          // Avatar
          GestureDetector(
            onTap: () => _snack('👤 Mon profil'),
            child: Container(width: 44, height: 44,
              decoration: BoxDecoration(color: _amberMid, shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.35), width: 2)),
              child: Center(child: Text(_initials,
                style: const TextStyle(
                  color: Color(0xFF633806), fontSize: 14, fontWeight: FontWeight.w800))))),
        ]),

        const SizedBox(height: 14),

        // Bande résumé
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(14)),
          child: Row(children: [
            _balItem('Ventes du jour', '87 500 F', Colors.white),
            Container(height: 36, width: 0.5, color: Colors.white.withOpacity(0.3)),
            _balItem('Dettes en cours', '34 200 F', _amberMid),
          ])),
      ]),
    );
  }

  Widget _line() => Container(width: 18, height: 2.5,
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2)));

  Widget _balItem(String lbl, String val, Color valColor) => Expanded(
    child: Column(children: [
      Text(lbl, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(val, style: TextStyle(color: valColor, fontSize: 18, fontWeight: FontWeight.w800)),
    ]));

  // ── ACCÈS RAPIDES
  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
        child: Text('ACCÈS RAPIDE', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 0.8))),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          _QBtn(label: 'Dettes\nclients', emoji: '💸', bg: _redLight,
            onTap: () => _snack('💸 Dettes clients')),
          const SizedBox(width: 10),
          _QBtn(label: 'Fournis-\nseurs', emoji: '🏭', bg: _blueLight,
            onTap: () => _snack('🏭 Fournisseurs')),
          const SizedBox(width: 10),
          _QBtn(label: 'Stock', emoji: '🧺', bg: _greenLight,
            onTap: () => _snack('🧺 Stock')),
          const SizedBox(width: 10),
          _QBtn(label: 'Mes\nventes', emoji: '📈', bg: _amberLight,
            onTap: () => _snack('📈 Mes ventes')),
        ])),
    ]);
  }

  // ── BOUTON NOUVELLE VENTE
  Widget _buildNewSaleBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: GestureDetector(
        onTap: () => _snack('➕ Nouvelle vente'),
        child: Container(width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('➕', style: TextStyle(fontSize: 20)),
            SizedBox(width: 10),
            Text('Enregistrer une nouvelle vente',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
          ]))));
  }

  // ── TRANSACTIONS
  Widget _buildTransactions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Row(children: [
          const Text('TRANSACTIONS RÉCENTES', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w800, color: _textMuted, letterSpacing: 0.8)),
          const Spacer(),
          GestureDetector(onTap: () => _snack('Voir tout'),
            child: const Text('Voir tout',
              style: TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700))),
        ])),
      ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _transactions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _TxCard(tx: _transactions[i])),
    ]);
  }

  // ── SIDEBAR
  Widget _buildSidebar() {
    return Container(
      width: 280,
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(child: Column(children: [
        // En-tête vert
        Container(width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
          color: _green,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 58, height: 58,
              decoration: BoxDecoration(color: _amberMid, shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 2)),
              child: Center(child: Text(_initials,
                style: const TextStyle(color: Color(0xFF633806), fontSize: 20, fontWeight: FontWeight.w800)))),
            const SizedBox(height: 10),
            Text(widget.nomCommercant,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text('${widget.nomBoutique} · ${widget.ville}',
              style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ])),

        // Menu
        Expanded(child: SingleChildScrollView(child: Column(children: [
          const SizedBox(height: 8),
          _SItem(emoji: '👤', label: 'Mon profil',          color: const Color(0xFFEEEDFE),
            onTap: () { _closeSidebar(); _snack('👤 Mon profil'); }),
          _SItem(emoji: '🔒', label: 'Biométrie & sécurité', color: _grey,
            onTap: () { _closeSidebar(); _snack('🔒 Biométrie'); }),
          _SItem(emoji: '🔔', label: 'Notifications',         color: _amberLight,
            onTap: () { _closeSidebar(); _snack('🔔 Notifications'); }),
          _SItem(emoji: '📊', label: 'Rapports & stats',      color: _greenLight,
            onTap: () { _closeSidebar(); _snack('📊 Rapports'); }),
          _SItem(emoji: '⚙️',  label: 'Paramètres',           color: _grey,
            onTap: () { _closeSidebar(); _snack('⚙️ Paramètres'); }),
          _SItem(emoji: '❓', label: 'Aide & support',         color: _blueLight,
            onTap: () { _closeSidebar(); _snack('❓ Aide'); }),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Divider(height: 1, color: _greyMid)),
          // ── Déconnexion : efface session → LoginPage au prochain lancement
          _SItem(emoji: '🚪', label: 'Se déconnecter',        color: _redLight,
            textColor: _red, onTap: () { _closeSidebar(); _deconnecter(); }),
          const SizedBox(height: 16),
        ]))),
      ])),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// WIDGETS RÉUTILISABLES
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
          Text(label, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280), height: 1.3)),
        ]))));
  }
}

class _TxCard extends StatelessWidget {
  final Transaction tx;
  static const _typeLabels = {'vente':'Vente','dette':'Dette','stock':'Stock reçu','remboursement':'Remboursement'};
  static const _typeBg  = {'vente':Color(0xFFEAF3DE),'dette':Color(0xFFFCEBEB),'stock':Color(0xFFFAEEDA),'remboursement':Color(0xFFEAF3DE)};
  static const _typeClr = {'vente':Color(0xFF27500A),'dette':Color(0xFF791F1F),'stock':Color(0xFF633806),'remboursement':Color(0xFF27500A)};
  static const _avColors = [
    [Color(0xFFEAF3DE),Color(0xFF27500A)],[Color(0xFFFCEBEB),Color(0xFF791F1F)],
    [Color(0xFFE6F1FB),Color(0xFF0C447C)],[Color(0xFFFAEEDA),Color(0xFF633806)],
    [Color(0xFFEEEDFE),Color(0xFF3C3489)],
  ];
  const _TxCard({required this.tx});

  String _ini() {
    final p = tx.nom.split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase() : tx.nom.substring(0,2).toUpperCase();
  }
  String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final colors = _avColors[tx.nom.codeUnitAt(0) % _avColors.length];
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
          Text(tx.nom, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A1A)), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(tx.date, style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF))),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: _typeBg[tx.type], borderRadius: BorderRadius.circular(20)),
            child: Text(_typeLabels[tx.type] ?? tx.type,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _typeClr[tx.type]))),
        ])),
        Text('${tx.isCredit ? '+' : '-'}${_fmt(tx.montant)} F',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800,
            color: tx.isCredit ? const Color(0xFF0F6E56) : const Color(0xFFA32D2D))),
      ]));
  }
}

class _SItem extends StatelessWidget {
  final String emoji, label;
  final Color color;
  final Color textColor;
  final VoidCallback onTap;
  const _SItem({required this.emoji, required this.label, required this.color,
    required this.onTap, this.textColor = const Color(0xFF1A1A1A)});

  @override
  Widget build(BuildContext context) {
    return InkWell(onTap: onTap,
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
}