import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:le_commercant/database/app_database.dart';
import 'login.dart';
import 'dettes.dart';
import 'fournisseurs_page.dart';
import 'page_stock.dart';
import 'page_ventes.dart';
import 'page_nouvelle_vente.dart';

class DashboardPage extends StatefulWidget {
  final int commercantId;
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
  static const _green = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red = Color(0xFFA32D2D);
  static const _redLight = Color(0xFFFCEBEB);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid = Color(0xFFFAC775);
  static const _blueLight = Color(0xFFE6F1FB);
  static const _grey = Color(0xFFF4F4F2);
  static const _greyMid = Color(0xFFE8E8E5);
  static const _textMuted = Color(0xFF6B7280);

  final _db = AppDatabase.instance;

  List<Map<String, dynamic>> _transactions = [];
  double _ventesJour = 0;
  double _dettesEnCours = 0;
  bool _loading = true;

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late Animation<double> _sidebarAnim;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _sidebarAnim =
        CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    if (_transactions.isEmpty) setState(() => _loading = true);
    try {
      final transactions = await _db.chargerTransactionsRecentes(
          widget.commercantId, limite: 10);
      final ventes = await _db.ventesAujourdhui(widget.commercantId);
      final dettes = await _db.dettesEnCours(widget.commercantId);
      if (!mounted) return;
      setState(() {
        _transactions = transactions;
        _ventesJour = ventes;
        _dettesEnCours = dettes;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goTo(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page))
        .then((_) => _chargerDonnees());
  }

  Future<void> _deconnecter() async {
    _closeSidebar();
    await _db.fermerSession(widget.commercantId);
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginPage(
            commercantId: widget.commercantId,
            nomCommercant: widget.nomCommercant,
            nomBoutique: widget.nomBoutique,
            ville: widget.ville,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false);
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

  String get _initiales {
    final p = widget.nomCommercant.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: Stack(children: [
        SafeArea(
            child: GestureDetector(
          onTap: _closeSidebar,
          child: Column(children: [
            _buildHeader(),
            Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(color: _green))
                    : RefreshIndicator(
                        onRefresh: _chargerDonnees,
                        color: _green,
                        child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildQuickActions(),
                                  _buildNewSaleBtn(),
                                  _buildTransactions(),
                                  const SizedBox(height: 24),
                                ])))),
          ]),
        )),

        AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, __) => _sidebarOpen
                ? GestureDetector(
                    onTap: _closeSidebar,
                    child: Container(
                        color: Colors.black
                            .withOpacity(0.42 * _sidebarAnim.value)))
                : const SizedBox.shrink()),

        AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, child) => Transform.translate(
                offset: Offset(-280 * (1 - _sidebarAnim.value), 0),
                child: child),
            child: _buildSidebar()),
      ]),
    );
  }

  // ── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
          color: _green,
          borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          GestureDetector(
              onTap: _toggleSidebar,
              child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10)),
                  child:
                      Column(mainAxisSize: MainAxisSize.min, children: [
                    _hamLine(),
                    const SizedBox(height: 4),
                    _hamLine(),
                    const SizedBox(height: 4),
                    _hamLine()
                  ]))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Bonjour 👋',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12, height: 1)),
                const SizedBox(height: 3),
                Text(widget.nomCommercant,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ])),
          Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                  color: _amberMid,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withOpacity(0.35), width: 2)),
              child: Center(
                  child: Text(_initiales,
                      style: const TextStyle(
                          color: Color(0xFF633806),
                          fontSize: 14,
                          fontWeight: FontWeight.w800)))),
        ]),
        const SizedBox(height: 14),
        Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.13),
                borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Expanded(
                  child: Column(children: [
                const Text('Ventes du jour',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${_fmt(_ventesJour)} F',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ])),
              Container(
                  height: 36,
                  width: 0.5,
                  color: Colors.white.withOpacity(0.3)),
              Expanded(
                  child: Column(children: [
                const Text('Dettes en cours',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('${_fmt(_dettesEnCours)} F',
                    style: const TextStyle(
                        color: _amberMid,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
              ])),
            ])),
      ]),
    );
  }

  Widget _hamLine() => Container(
      width: 18,
      height: 2.5,
      decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(2)));

  // ── ACCÈS RAPIDE ───────────────────────────────────────────────────────────

  Widget _buildQuickActions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 12),
          child: Text('ACCÈS RAPIDE',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: _textMuted,
                  letterSpacing: 0.8))),
      Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(children: [
            _QBtn(
                label: 'Dettes\nclients',
                emoji: '💸',
                bg: _redLight,
                onTap: () => _goTo(
                    PageDette(commercantId: widget.commercantId))),
            const SizedBox(width: 10),
            _QBtn(
                label: 'Fournis-\nseurs',
                emoji: '🏭',
                bg: _blueLight,
                onTap: () => _goTo(const PageFournisseurs())),
            const SizedBox(width: 10),
            _QBtn(
                label: 'Stock',
                emoji: '🧺',
                bg: _greenLight,
                onTap: () => _goTo(const StockPage())),
            const SizedBox(width: 10),
            _QBtn(
                label: 'Mes\nventes',
                emoji: '📈',
                bg: _amberLight,
                onTap: () => _goTo(
                    PageVentes(commercantId: widget.commercantId))),
          ])),
    ]);
  }

  Widget _buildNewSaleBtn() => Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: GestureDetector(
          onTap: () => _goTo(
              PageNouvelleVente(commercantId: widget.commercantId)),
          child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                  color: _green, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('➕', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 10),
                    Text('Enregistrer une nouvelle vente',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800)),
                  ]))));

  // ── TRANSACTIONS ───────────────────────────────────────────────────────────

  Widget _buildTransactions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(children: [
            const Text('TRANSACTIONS RÉCENTES',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: _textMuted,
                    letterSpacing: 0.8)),
            const Spacer(),
            GestureDetector(
                onTap: () =>
                    _goTo(PageVentes(commercantId: widget.commercantId)),
                child: const Text('Voir tout',
                    style: TextStyle(
                        color: _green,
                        fontSize: 12,
                        fontWeight: FontWeight.w700))),
          ])),
      if (_transactions.isEmpty)
        const Center(
            child: Padding(
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
            itemBuilder: (_, i) => _TxCard(
                  tx: _transactions[i],
                  onTap: _transactions[i]['type'] == 'credit'
                      ? () => _goTo(PageDette(
                          commercantId: widget.commercantId))
                      : null,
                )),
    ]);
  }

  // ── SIDEBAR ────────────────────────────────────────────────────────────────

  Widget _buildSidebar() {
    return Container(
      width: 280,
      height: double.infinity,
      color: Colors.white,
      child: SafeArea(
          child: Column(children: [
        Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 30, 20, 22),
            color: _green,
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                          color: _amberMid,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withOpacity(0.4),
                              width: 2)),
                      child: Center(
                          child: Text(_initiales,
                              style: const TextStyle(
                                  color: Color(0xFF633806),
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800)))),
                  const SizedBox(height: 10),
                  Text(widget.nomCommercant,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text('${widget.nomBoutique} · ${widget.ville}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ])),
        Expanded(
            child: SingleChildScrollView(
                child: Column(children: [
          const SizedBox(height: 8),
          _SItem(
              emoji: '👤',
              label: 'Mon profil',
              color: const Color(0xFFEEEDFE),
              onTap: () => _closeSidebar()),
          _SItem(
              emoji: '🔒',
              label: 'Biométrie & sécurité',
              color: _grey,
              onTap: () => _closeSidebar()),
          _SItem(
              emoji: '🔔',
              label: 'Notifications',
              color: _amberLight,
              onTap: () => _closeSidebar()),
          _SItem(
              emoji: '📊',
              label: 'Rapports & stats',
              color: _greenLight,
              onTap: () => _closeSidebar()),
          _SItem(
              emoji: '⚙️',
              label: 'Paramètres',
              color: _grey,
              onTap: () => _closeSidebar()),
          _SItem(
              emoji: '❓',
              label: 'Aide & support',
              color: _blueLight,
              onTap: () => _closeSidebar()),
          const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Divider(height: 1, color: _greyMid)),
          _SItem(
              emoji: '🚪',
              label: 'Se déconnecter',
              color: _redLight,
              textColor: _red,
              onTap: _deconnecter),
          const SizedBox(height: 16),
        ]))),
      ])),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGET CARTE TRANSACTION — ENRICHIE
// Affiche : image catégorie / avatar client, nom produit, type, statut, montant
// ─────────────────────────────────────────────────────────────────────────────
class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;

  const _TxCard({required this.tx, this.onTap});

  static const _green = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFEAF3DE);
  static const _greenDark = Color(0xFF27500A);
  static const _red = Color(0xFFA32D2D);
  static const _redLight = Color(0xFFFCEBEB);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberDark = Color(0xFF854F0B);
  static const _blueLight = Color(0xFFE6F1FB);
  static const _blueDark = Color(0xFF185FA5);

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  // Mappe type → config visuelle
  _TxConfig get _config {
    final type = tx['type'] as String? ?? 'credit';
    final statut = tx['statut'] as String? ?? 'impaye';

    switch (type) {
      case 'vente_cash':
        return _TxConfig(
          emoji: '✅',
          bg: _greenLight,
          labelBg: _greenLight,
          labelClr: _greenDark,
          labelTxt: 'Vendu · Payé',
          montantClr: _green,
          signe: '+',
        );
      case 'remboursement':
        return _TxConfig(
          emoji: '💳',
          bg: _blueLight,
          labelBg: _blueLight,
          labelClr: _blueDark,
          labelTxt: 'Remboursement',
          montantClr: _blueDark,
          signe: '+',
        );
      case 'credit':
      default:
        if (statut == 'paye') {
          return _TxConfig(
            emoji: '✅',
            bg: _greenLight,
            labelBg: _greenLight,
            labelClr: _greenDark,
            labelTxt: 'Crédit · Soldé',
            montantClr: _green,
            signe: '',
          );
        }
        return _TxConfig(
          emoji: '⏳',
          bg: _redLight,
          labelBg: _redLight,
          labelClr: _red,
          labelTxt: 'Crédit · Impayé',
          montantClr: _red,
          signe: '',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _config;
    final String produit = tx['produit'] as String? ?? 'Produit';
    final String label = tx['label'] as String? ?? '';
    final double montant = (tx['montant'] as num?)?.toDouble() ?? 0;
    final double reste = (tx['reste'] as num?)?.toDouble() ?? 0;
    final String? photoUrl = tx['photo_url'] as String?;
    final String categorie = tx['image_categorie'] as String? ?? 'Autre';
    final String type = tx['type'] as String? ?? 'credit';
    final String details = tx['produits_details'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE8E8E5), width: 0.5)),
          child: Row(children: [
            // ── Avatar / image produit ──
            _buildAvatar(photoUrl, categorie, type, cfg),
            const SizedBox(width: 12),

            // ── Infos ──
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Nom client ou "Remboursement"
                  if (label.isNotEmpty)
                    Text(label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1A1A1A))),

                  // Nom produit(s)
                  Text(produit,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),

                  const SizedBox(height: 5),

                  // Badge statut
                  Row(children: [
                    Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: cfg.labelBg,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(cfg.labelTxt,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: cfg.labelClr))),

                    // Badge méthode paiement pour remboursement
                    if (type == 'remboursement' && details.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                              color: _amberLight,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(details,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: _amberDark))),
                    ],
                  ]),

                  // Reste à payer si crédit impayé
                  if (type == 'credit' && reste > 0) ...[
                    const SizedBox(height: 4),
                    Text('Reste : ${_fmt(reste)} F',
                        style: const TextStyle(
                            fontSize: 11,
                            color: _red,
                            fontWeight: FontWeight.w600)),
                  ],
                ])),

            // ── Montant ──
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${cfg.signe}${_fmt(montant)} F',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: cfg.montantClr)),
              if (onTap != null)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFFBBBBBB)),
                ),
            ]),
          ])),
    );
  }

  Widget _buildAvatar(
      String? photoUrl, String categorie, String type, _TxConfig cfg) {
    // Remboursement → icône fixe
    if (type == 'remboursement') {
      return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
              color: _blueLight, borderRadius: BorderRadius.circular(12)),
          child: const Center(
              child: Text('💳', style: TextStyle(fontSize: 22))));
    }

    // Photo client si disponible
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(photoUrl,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _categoryAvatar(categorie, cfg)),
      );
    }

    return _categoryAvatar(categorie, cfg);
  }

  Widget _categoryAvatar(String categorie, _TxConfig cfg) {
    final Map<String, String> catAssets = {
      'Alimentaire': 'lib/assets/categories/aliment.jpg',
      'Boissons': 'lib/assets/categories/boisson.jpg',
      'Hygiène': 'lib/assets/categories/hygienne.jpg',
    };
    final Map<String, String> catEmoji = {
      'Alimentaire': '🍞',
      'Boissons': '🥤',
      'Hygiène': '🧴',
      'paiement': '💳',
      'Autre': '📦',
    };
    final String? assetPath = catAssets[categorie];

    if (assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.asset(assetPath,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: cfg.bg,
                    borderRadius: BorderRadius.circular(12)),
                child: Center(
                    child: Text(catEmoji[categorie] ?? '📦',
                        style: const TextStyle(fontSize: 22))))),
      );
    }

    return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: cfg.bg, borderRadius: BorderRadius.circular(12)),
        child: Center(
            child: Text(catEmoji[categorie] ?? cfg.emoji,
                style: const TextStyle(fontSize: 22))));
  }
}

class _TxConfig {
  final String emoji;
  final Color bg, labelBg, labelClr, montantClr;
  final String labelTxt, signe;
  const _TxConfig({
    required this.emoji,
    required this.bg,
    required this.labelBg,
    required this.labelClr,
    required this.labelTxt,
    required this.montantClr,
    required this.signe,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS RÉUTILISABLES
// ─────────────────────────────────────────────────────────────────────────────

class _QBtn extends StatelessWidget {
  final String label, emoji;
  final Color bg;
  final VoidCallback onTap;
  const _QBtn(
      {required this.label,
      required this.emoji,
      required this.bg,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
        child: GestureDetector(
            onTap: onTap,
            child: Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 13, horizontal: 6),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFFE8E8E5), width: 0.5)),
                child: Column(children: [
                  Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(11)),
                      child: Center(
                          child: Text(emoji,
                              style:
                                  const TextStyle(fontSize: 22)))),
                  const SizedBox(height: 7),
                  Text(label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6B7280),
                          height: 1.3)),
                ]))));
  }
}

class _SItem extends StatelessWidget {
  final String emoji, label;
  final Color color, textColor;
  final VoidCallback onTap;
  const _SItem(
      {required this.emoji,
      required this.label,
      required this.color,
      required this.onTap,
      this.textColor = const Color(0xFF1A1A1A)});

  @override
  Widget build(BuildContext context) => InkWell(
      onTap: onTap,
      child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 12),
              child: Row(children: [
                Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(10)),
                    child: Center(
                        child: Text(emoji,
                            style:
                                const TextStyle(fontSize: 18)))),
                const SizedBox(width: 14),
                Text(label,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor)),
              ]))));
}