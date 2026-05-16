import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'dettes.dart';
import 'fournisseurs_page.dart';
import 'page_stock.dart';
import 'page_ventes.dart';
import 'page_nouvelle_vente.dart';
import 'profil.dart';
import 'biometrie.dart';
import 'notifications.dart';
import 'parametre.dart';
import 'aide.dart';


// ─────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────
class _DS {
  static const emerald      = Color(0xFF0A5C47);
  static const emeraldMid   = Color(0xFF0D7A5F);
  static const emeraldLight = Color(0xFF10926F);
  static const emeraldGlow  = Color(0xFF1DC58A);
  static const emeraldFaint = Color(0xFFE8F5F0);
  static const emeraldTint  = Color(0xFFC8EBE0);

  static const gold         = Color(0xFFD4940A);
  static const goldLight    = Color(0xFFFFF0C2);
  static const goldMid      = Color(0xFFFABF35);
  static const coral        = Color(0xFFCC3B3B);
  static const coralLight   = Color(0xFFFFF0F0);
  static const sapphire     = Color(0xFF1A5FA8);
  static const sapphireLight= Color(0xFFEBF3FF);

  static const ink          = Color(0xFF0F1A14);
  static const inkMid       = Color(0xFF243028);
  static const slate        = Color(0xFF6B7A72);
  static const fog          = Color(0xFFF3F6F4);
  static const mist         = Color(0xFFE8EDE9);
  static const white        = Color(0xFFFFFFFF);

  static const headerGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A5C47), Color(0xFF0D7A5F), Color(0xFF0F926F)],
    stops: [0.0, 0.55, 1.0],
  );

  static const cardGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7A5F), Color(0xFF1DC58A)],
  );

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF0A5C47).withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> get shadowCard => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static TextStyle display(double size, {Color color = ink, FontWeight fw = FontWeight.w800}) =>
      TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: fw, color: color, letterSpacing: -0.3);

  static TextStyle body(double size, {Color color = ink, FontWeight fw = FontWeight.w500}) =>
      TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: fw, color: color);

  static TextStyle mono(double size, {Color color = ink, FontWeight fw = FontWeight.w700}) =>
      TextStyle(fontFamily: 'RobotoMono', fontSize: size, fontWeight: fw, color: color);
}

// ─────────────────────────────────────────
// DASHBOARD PAGE
// ─────────────────────────────────────────
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
    with TickerProviderStateMixin {

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _transactions = [];
  double _ventesJour    = 0;
  double _dettesEnCours = 0;
  bool   _loading       = true;
  String? _photoUrl;

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late AnimationController _contentCtrl;
  late Animation<double>   _sidebarAnim;
  late Animation<double>   _contentFade;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sidebarAnim =
        CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
    _contentFade =
        CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _chargerDonnees();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────
  // CHARGEMENT DEPUIS SUPABASE
  // ─────────────────────────────────────────
  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    if (_transactions.isEmpty) setState(() => _loading = true);

    try {
      final rawVentes = await _supabase
          .from('ventes')
          .select('id, date_vente, nom_client, total_montant, statut_paiement')
          .eq('commercant_id', widget.commercantId)
          .order('date_vente', ascending: false)
          .limit(10);

      final now       = DateTime.now();
      final debutJour = DateTime(now.year, now.month, now.day)
          .toIso8601String();

      final rawJour = await _supabase
          .from('ventes')
          .select('total_montant')
          .eq('commercant_id', widget.commercantId)
          .gte('date_vente', debutJour);

      final double ventesJour = (rawJour as List).fold(
          0.0,
          (s, v) => s + ((v['total_montant'] ?? 0) as num).toDouble());

      final rawDettes = await _supabase
          .from('ventes')
          .select('total_montant')
          .eq('commercant_id', widget.commercantId)
          .eq('statut_paiement', 'À crédit');

      final double dettesEnCours = (rawDettes as List).fold(
          0.0,
          (s, v) => s + ((v['total_montant'] ?? 0) as num).toDouble());

      String? photoUrl;
      try {
        final profil = await _supabase
            .from('commercants')
            .select('photo_url')
            .eq('id', widget.commercantId)
            .single();
        photoUrl = profil['photo_url'] as String?;
      } catch (_) {}

      final List<Map<String, dynamic>> transactions =
          (rawVentes as List).map<Map<String, dynamic>>((v) {
        final String statut =
            v['statut_paiement'] as String? ?? 'Payé';
        final String nomClient =
            v['nom_client'] as String? ?? '';

        String type;
        String statutTx;
        if (statut == 'À crédit') {
          type     = 'credit';
          statutTx = 'impaye';
        } else if (statut == 'Wave' || statut == 'Orange Money') {
          type     = 'vente_cash';
          statutTx = 'paye';
        } else {
          type     = 'vente_cash';
          statutTx = 'paye';
        }

        return {
          'type'            : type,
          'statut'          : statutTx,
          'label'           : nomClient,
          'produit'         : nomClient.isNotEmpty ? nomClient : 'Vente',
          'montant'         : v['total_montant'] ?? 0,
          'reste'           : 0,
          'photo_url'       : null,
          'image_categorie' : 'Autre',
          'produits_details': statut,
          'date_vente'      : v['date_vente'],
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _transactions  = transactions;
        _ventesJour    = ventesJour;
        _dettesEnCours = dettesEnCours;
        _photoUrl      = photoUrl;
        _loading       = false;
      });
      _contentCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('Erreur dashboard: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────
  void _goTo(Widget page) {
    Navigator.push(context, _slide(page)).then((_) => _chargerDonnees());
  }

  void _sidebarGoTo(Widget page) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      Navigator.push(context, _slide(page)).then((_) => _chargerDonnees());
    });
  }

  PageRoute _slide(Widget page) => PageRouteBuilder(
    pageBuilder: (_, __, ___) => page,
    transitionsBuilder: (_, a, __, child) => SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(1, 0), end: Offset.zero,
      ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
      child: child,
    ),
    transitionDuration: const Duration(milliseconds: 320),
  );

  // ─────────────────────────────────────────
  // DÉCONNEXION
  // ─────────────────────────────────────────
  Future<void> _deconnecter() async {
    _closeSidebar();
    try {
      await _supabase.auth.signOut();
    } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginPage(
            commercantId:  widget.commercantId,
            nomCommercant: widget.nomCommercant,
            nomBoutique:   widget.nomBoutique,
            ville:         widget.ville,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false);
  }

  // ─────────────────────────────────────────
  // SIDEBAR
  // ─────────────────────────────────────────
  void _toggleSidebar() {
    HapticFeedback.lightImpact();
    setState(() => _sidebarOpen = !_sidebarOpen);
    _sidebarOpen ? _sidebarCtrl.forward() : _sidebarCtrl.reverse();
  }

  void _closeSidebar() {
    if (_sidebarOpen) {
      setState(() => _sidebarOpen = false);
      _sidebarCtrl.reverse();
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  String get _initiales {
    final p = widget.nomCommercant.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  Widget _buildAvatarWidget({required double size}) {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _photoUrl!,
        width: size, height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialesWidget(size),
        errorWidget:  (_, __, ___) => _initialesWidget(size),
      );
    }
    return _initialesWidget(size);
  }

  Widget _initialesWidget(double size) => Container(
    width: size, height: size,
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFFFABF35), Color(0xFFE8A010)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Center(
      child: Text(
        _initiales,
        style: TextStyle(
          fontFamily: 'Roboto',
          fontSize: size * 0.35,
          fontWeight: FontWeight.w800,
          color: const Color(0xFF5A3000),
        ),
      ),
    ),
  );

  // ─────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _DS.fog,
        body: Stack(children: [
          SafeArea(
            child: GestureDetector(
              onTap: _closeSidebar,
              child: Column(children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                color: _DS.emeraldMid,
                                strokeWidth: 2.5,
                              ),
                              const SizedBox(height: 16),
                              Text('Chargement…',
                                  style: _DS.body(13, color: _DS.slate)),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _contentFade,
                          child: RefreshIndicator(
                            onRefresh: _chargerDonnees,
                            color: _DS.emeraldMid,
                            strokeWidth: 2.5,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildQuickActions(),
                                  _buildNewSaleBtn(),
                                  _buildTransactions(),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ]),
            ),
          ),

          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, __) => _sidebarOpen
                ? GestureDetector(
                    onTap: _closeSidebar,
                    child: Container(
                      color: _DS.ink.withValues(
                          alpha: 0.45 * _sidebarAnim.value),
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(-290 * (1 - _sidebarAnim.value), 0),
              child: child,
            ),
            child: _buildSidebar(),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ──────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: _DS.headerGrad,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x260A5C47),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: _toggleSidebar,
            child: AnimatedBuilder(
              animation: _sidebarAnim,
              builder: (_, __) => Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) => Padding(
                      padding: EdgeInsets.only(bottom: i < 2 ? 4 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: i == 1 ? 12 : 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Bonjour 👋',
                  style: _DS.body(12, color: Colors.white.withValues(alpha: 0.65))),
              const SizedBox(height: 2),
              Text(widget.nomCommercant,
                  style: _DS.display(17, color: Colors.white)),
            ]),
          ),
          GestureDetector(
            onTap: () => _goTo(ProfilPage(
              commercantId:  widget.commercantId,
              nomCommercant: widget.nomCommercant,
            )),
            child: Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.40),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _DS.gold.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipOval(child: _buildAvatarWidget(size: 46)),
            ),
          ),
        ]),

        const SizedBox(height: 18),

        Row(children: [
          Expanded(child: _StatCard(
            label:   'Ventes du jour',
            value:   '${_fmt(_ventesJour)} F',
            icon:    '📈',
            accent:  _DS.emeraldGlow,
            bgColor: Colors.white.withValues(alpha: 0.13),
          )),
          const SizedBox(width: 12),
          Expanded(child: _StatCard(
            label:   'Dettes en cours',
            value:   '${_fmt(_dettesEnCours)} F',
            icon:    '⏳',
            accent:  _DS.goldMid,
            bgColor: Colors.white.withValues(alpha: 0.13),
            valueColor: _DS.goldMid,
          )),
        ]),
      ]),
    );
  }

  // ── ACCÈS RAPIDE ────────────────────────────────
  // Les images doivent être placées dans lib/assets/categories/
  // Noms des fichiers : dettes.png, fournisseurs.png, stock.png, ventes.png
  // Déclaration dans pubspec.yaml :
  //   flutter:
  //     assets:
  //       - lib/assets/categories/dettes.png
  //       - lib/assets/categories/fournisseurs.png
  //       - lib/assets/categories/stock.png
  //       - lib/assets/categories/ventes.png
  Widget _buildQuickActions() {
    final actions = [
      _QAction(
        label:     'Dettes',
        imagePath: 'lib/assets/categories/dettes.png',
        bg:        _DS.coralLight,
        iconColor: _DS.coral,
        onTap:     () => _goTo(DettesPage(commercantId: widget.commercantId)),
      ),
      _QAction(
        label:     'Fournisseurs',
        imagePath: 'lib/assets/categories/fournisseurs.png',
        bg:        _DS.sapphireLight,
        iconColor: _DS.sapphire,
        onTap:     () => _goTo(FournisseursPage(
          commercantId: widget.commercantId,
          nomBoutique:  widget.nomBoutique,
        )),
      ),
      _QAction(
        label:     'Stock',
        imagePath: 'lib/assets/categories/stocks.png',
        bg:        _DS.emeraldFaint,
        iconColor: _DS.emeraldMid,
        onTap:     () => _goTo(StockPage(commercantId: widget.commercantId)),
      ),
      _QAction(
        label:     'Ventes',
        imagePath: 'lib/assets/categories/ventes.png',
        bg:        _DS.goldLight,
        iconColor: _DS.gold,
        onTap:     () => _goTo(VentesPage(commercantId: widget.commercantId)),
      ),
    ];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
        child: Row(children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(
                color: _DS.emeraldMid,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 8),
          Text('ACCÈS RAPIDE',
              style: _DS.body(11, color: _DS.slate, fw: FontWeight.w700)
                  .copyWith(letterSpacing: 1.2)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Expanded(child: _QuickActionCard(action: actions[0])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionCard(action: actions[1])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionCard(action: actions[2])),
            const SizedBox(width: 10),
            Expanded(child: _QuickActionCard(action: actions[3])),
          ],
        ),
      ),
    ]);
  }

  // ── BOUTON NOUVELLE VENTE ──────────────────────
  Widget _buildNewSaleBtn() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          _goTo(NouvelleVentePage(commercantId: widget.commercantId));
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 17),
          decoration: BoxDecoration(
            gradient: _DS.cardGrad,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _DS.emeraldMid.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Center(
                  child: Text('➕', style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(width: 12),
              Text('Enregistrer une vente',
                  style: _DS.display(15, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ── TRANSACTIONS ────────────────────────────────
  Widget _buildTransactions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Row(children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(
                color: _DS.emeraldMid,
                borderRadius: BorderRadius.circular(2),
              )),
          const SizedBox(width: 8),
          Text('TRANSACTIONS RÉCENTES',
              style: _DS.body(11, color: _DS.slate, fw: FontWeight.w700)
                  .copyWith(letterSpacing: 1.2)),
          const Spacer(),
          GestureDetector(
            onTap: () => _goTo(VentesPage(commercantId: widget.commercantId)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: _DS.emeraldFaint,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Voir tout',
                  style: _DS.body(11, color: _DS.emeraldMid, fw: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      if (_transactions.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              const Text('🧾', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text('Aucune transaction pour le moment',
                  style: _DS.body(13, color: _DS.slate)),
            ]),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TxCard(
            tx: _transactions[i],
            index: i,
            onTap: _transactions[i]['type'] == 'credit'
                ? () => _goTo(DettesPage(commercantId: widget.commercantId))
                : null,
          ),
        ),
    ]);
  }

  // ── SIDEBAR ─────────────────────────────────────
  Widget _buildSidebar() {
    return Container(
      width: 290,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: _DS.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 30,
            offset: Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: const BoxDecoration(gradient: _DS.headerGrad),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 62, height: 62,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.40), width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: _DS.gold.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipOval(child: _buildAvatarWidget(size: 62)),
              ),
              const SizedBox(height: 12),
              Text(widget.nomCommercant,
                  style: _DS.display(16, color: Colors.white)),
              const SizedBox(height: 4),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${widget.nomBoutique} · ${widget.ville}',
                      style: _DS.body(11,
                          color: Colors.white.withValues(alpha: 0.80))),
                ),
              ]),
            ]),
          ),

          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  _SideItem('👤', 'Mon profil',            const Color(0xFFEEEDFE), const Color(0xFF5B55D8),
                      () => _sidebarGoTo(ProfilPage(
                        commercantId:  widget.commercantId,
                        nomCommercant: widget.nomCommercant,
                      ))),
                  _SideItem('🔒', 'Biométrie & sécurité',  _DS.fog,            _DS.slate,
                      () => _sidebarGoTo(const BiometriePage())),
                  _SideItem('🔔', 'Notifications',          _DS.goldLight,      _DS.gold,
                      () => _sidebarGoTo(const NotificationsPage())),
                  _SideItem('📊', 'Rapports & statistiques',_DS.emeraldFaint,   _DS.emeraldMid,
                      () => _sidebarGoTo(VentesPage(commercantId: widget.commercantId))),
                  _SideItem('⚙️', 'Paramètres',             _DS.fog,            _DS.slate,
                      () => _sidebarGoTo(ParametresPage(commercantId: widget.commercantId))),
                  _SideItem('❓', 'Aide & support',          _DS.sapphireLight,  _DS.sapphire,
                      () => _sidebarGoTo(const AidePage())),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Divider(height: 1, color: _DS.mist),
                  ),

                  _SideItem('🚪', 'Se déconnecter', _DS.coralLight, _DS.coral,
                      _deconnecter, isDestructive: true),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// STAT CARD (dans le header)
// ─────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label, value, icon;
  final Color  accent, bgColor;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.bgColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.12), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(label,
              style: _DS.body(10,
                  color: Colors.white.withValues(alpha: 0.70),
                  fw: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text(value,
            style: _DS.mono(17,
                color: valueColor ?? Colors.white,
                fw: FontWeight.w700)),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// QUICK ACTION MODEL — supporte imagePath (PNG/asset) ou emoji fallback
// ─────────────────────────────────────────
class _QAction {
  final String       label;
  final String?      imagePath;   // ex: 'lib/assets/icons/dettes.png'
  final String?      emoji;       // fallback si pas d'image
  final Color        bg, iconColor;
  final VoidCallback onTap;

  const _QAction({
    required this.label,
    this.imagePath,
    this.emoji,
    required this.bg,
    required this.iconColor,
    required this.onTap,
  });
}

// ─────────────────────────────────────────
// QUICK ACTION CARD — affiche l'image PNG ou l'emoji en fallback
// ─────────────────────────────────────────
class _QuickActionCard extends StatefulWidget {
  final _QAction action;
  const _QuickActionCard({required this.action});

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;

    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); action.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Cercle avec image ou emoji ──
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: action.bg,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: action.iconColor.withValues(alpha: 0.20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              // Pas de ClipOval : l'image PNG avec fond transparent
              // s'affiche proprement dans le cercle coloré
              child: _buildIcon(action),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: _DS.body(10, color: _DS.slate, fw: FontWeight.w700)
                  .copyWith(height: 1.35),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon(_QAction action) {
    if (action.imagePath != null) {
      return Padding(
        // Padding interne pour que l'image ne touche pas les bords du cercle
        padding: const EdgeInsets.all(10),
        child: Image.asset(
          action.imagePath!,
          // Pas de width/height fixe : laisse le Padding gérer la taille
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) {
            // Fallback vers emoji si l'image est introuvable
            return Center(
              child: Text(
                action.emoji ?? '📁',
                style: const TextStyle(fontSize: 26),
              ),
            );
          },
        ),
      );
    }
    // Pas d'imagePath → emoji centré
    return Center(
      child: Text(
        action.emoji ?? '📁',
        style: const TextStyle(fontSize: 26),
      ),
    );
  }
}

// ─────────────────────────────────────────
// TRANSACTION CARD
// ─────────────────────────────────────────
class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback? onTap;
  final int index;

  const _TxCard({required this.tx, this.onTap, required this.index});

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  _TxConfig get _config {
    final type   = tx['type']   as String? ?? 'credit';
    final statut = tx['statut'] as String? ?? 'impaye';
    switch (type) {
      case 'vente_cash':
        return _TxConfig(
          emoji: '✅', bg: _DS.emeraldFaint,
          labelBg: _DS.emeraldFaint, labelClr: _DS.emeraldMid,
          labelTxt: 'Vendu · Payé',
          montantClr: _DS.emeraldMid, signe: '+',
          dotColor: _DS.emeraldGlow,
        );
      case 'remboursement':
        return _TxConfig(
          emoji: '💳', bg: _DS.sapphireLight,
          labelBg: _DS.sapphireLight, labelClr: _DS.sapphire,
          labelTxt: 'Remboursement',
          montantClr: _DS.sapphire, signe: '+',
          dotColor: _DS.sapphire,
        );
      case 'credit':
      default:
        if (statut == 'paye') {
          return _TxConfig(
            emoji: '✅', bg: _DS.emeraldFaint,
            labelBg: _DS.emeraldFaint, labelClr: _DS.emeraldMid,
            labelTxt: 'Crédit · Soldé',
            montantClr: _DS.emeraldMid, signe: '',
            dotColor: _DS.emeraldGlow,
          );
        }
        return _TxConfig(
          emoji: '⏳', bg: _DS.coralLight,
          labelBg: _DS.coralLight, labelClr: _DS.coral,
          labelTxt: 'Crédit · Impayé',
          montantClr: _DS.coral, signe: '',
          dotColor: _DS.coral,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg      = _config;
    final produit  = tx['produit']          as String? ?? 'Produit';
    final label    = tx['label']            as String? ?? '';
    final montant  = (tx['montant']  as num?)?.toDouble() ?? 0;
    final reste    = (tx['reste']    as num?)?.toDouble() ?? 0;
    final photoUrl = tx['photo_url']        as String?;
    final categorie= tx['image_categorie']  as String? ?? 'Autre';
    final type     = tx['type']             as String? ?? 'credit';
    final details  = tx['produits_details'] as String? ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _DS.shadowSm,
          border: Border.all(color: _DS.mist, width: 0.8),
        ),
        child: Row(children: [
          _buildAvatar(photoUrl, categorie, type, cfg),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(label,
                      style: _DS.display(13, color: _DS.ink, fw: FontWeight.w700)),
                Text(produit,
                    style: _DS.body(12, color: _DS.slate),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 7),
                Wrap(spacing: 6, children: [
                  _Badge(text: cfg.labelTxt, bg: cfg.labelBg, textColor: cfg.labelClr),
                  if (type == 'remboursement' && details.isNotEmpty)
                    _Badge(text: details, bg: _DS.goldLight, textColor: _DS.gold),
                ]),
                if (type == 'credit' && reste > 0) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(
                          color: _DS.coral, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text('Reste : ${_fmt(reste)} F',
                        style: _DS.body(11, color: _DS.coral, fw: FontWeight.w600)),
                  ]),
                ],
              ],
            ),
          ),

          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${cfg.signe}${_fmt(montant)} F',
                style: _DS.mono(13, color: cfg.montantClr, fw: FontWeight.w700)),
            if (onTap != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: _DS.emeraldFaint,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: const Center(
                    child: Icon(Icons.chevron_right,
                        size: 16, color: _DS.emeraldMid),
                  ),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  Widget _buildAvatar(
      String? photoUrl, String categorie, String type, _TxConfig cfg) {
    if (type == 'remboursement') {
      return _avatarBox(
          color: _DS.sapphireLight,
          child: const Text('💳', style: TextStyle(fontSize: 22)));
    } else if (photoUrl != null && photoUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.network(photoUrl, width: 48, height: 48, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _categoryAvatar(categorie, cfg)),
      );
    }
    return _categoryAvatar(categorie, cfg);
  }

  Widget _avatarBox({required Color color, required Widget child}) =>
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(13)),
        child: Center(child: child),
      );

  Widget _categoryAvatar(String categorie, _TxConfig cfg) {
    const catAssets = {
      'Alimentaire': 'lib/assets/categories/aliment.jpg',
      'Boissons':    'lib/assets/categories/boisson.jpg',
      'Hygiène':     'lib/assets/categories/hygienne.jpg',
    };
    const catEmoji = {
      'Alimentaire': '🍞',
      'Boissons':    '🥤',
      'Hygiène':     '🧴',
      'paiement':    '💳',
      'Autre':       '📦',
    };
    final assetPath = catAssets[categorie];
    if (assetPath != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(13),
        child: Image.asset(assetPath, width: 48, height: 48, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarBox(
              color: cfg.bg,
              child: Text(catEmoji[categorie] ?? '📦',
                  style: const TextStyle(fontSize: 22)),
            )),
      );
    }
    return _avatarBox(
      color: cfg.bg,
      child: Text(catEmoji[categorie] ?? cfg.emoji,
          style: const TextStyle(fontSize: 22)),
    );
  }
}

class _TxConfig {
  final String emoji, labelTxt, signe;
  final Color  bg, labelBg, labelClr, montantClr, dotColor;
  const _TxConfig({
    required this.emoji, required this.bg, required this.labelBg,
    required this.labelClr, required this.labelTxt,
    required this.montantClr, required this.signe, required this.dotColor,
  });
}

// ─────────────────────────────────────────
// BADGE
// ─────────────────────────────────────────
class _Badge extends StatelessWidget {
  final String text;
  final Color  bg, textColor;
  const _Badge({required this.text, required this.bg, required this.textColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text,
        style: _DS.body(10, color: textColor, fw: FontWeight.w700)),
  );
}

// ─────────────────────────────────────────
// SIDEBAR ITEM
// ─────────────────────────────────────────
class _SideItem extends StatefulWidget {
  final String       emoji, label;
  final Color        iconBg, iconColor;
  final VoidCallback onTap;
  final bool         isDestructive;

  const _SideItem(
    this.emoji, this.label, this.iconBg, this.iconColor, this.onTap,
    {this.isDestructive = false}
  );

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _hovered = true),
      onTapUp:     (_) { setState(() => _hovered = false); widget.onTap(); },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered
              ? (widget.isDestructive ? _DS.coralLight : _DS.emeraldFaint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: widget.iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Center(
              child: Text(widget.emoji,
                  style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 14),
          Text(widget.label,
              style: _DS.body(14,
                  color: widget.isDestructive ? _DS.coral : _DS.inkMid,
                  fw: FontWeight.w600)),
          const Spacer(),
          Icon(Icons.chevron_right,
              size: 16,
              color: widget.isDestructive ? _DS.coral : _DS.mist),
        ]),
      ),
    );
  }
}
