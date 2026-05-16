import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_nouvelle_vente.dart';

class _DS {
  static const emerald      = Color(0xFF0A5C47);
  static const emeraldMid   = Color(0xFF0D7A5F);
  static const emeraldFaint = Color(0xFFE8F5F0);
  static const gold         = Color(0xFFD4940A);
  static const goldLight    = Color(0xFFFFF0C2);
  static const coral        = Color(0xFFCC3B3B);
  static const coralLight   = Color(0xFFFFF0F0);
  static const orange       = Color(0xFFE8720C);
  static const orangeLight  = Color(0xFFFFF3EB);
  static const sky          = Color(0xFF1565C0);
  static const skyLight     = Color(0xFFE3F2FD);
  static const ink          = Color(0xFF0F1A14);
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

  static List<BoxShadow> get shadow => [
    BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 4)),
  ];

  static TextStyle label(double sz, {Color c = ink, FontWeight fw = FontWeight.w600}) =>
      TextStyle(fontSize: sz, fontWeight: fw, color: c);
}

class _StatutConfig {
  final String emoji;
  final Color bg, textClr, borderClr;
  const _StatutConfig(this.emoji, this.bg, this.textClr, this.borderClr);
}

String _normaliser(String statut) => statut.trim().toLowerCase();

_StatutConfig _configStatut(String statut) {
  final s = _normaliser(statut);
  if (s == 'wave') return const _StatutConfig('🌊', _DS.skyLight, _DS.sky, Color(0xFFBBDEFB));
  if (s == 'orange money' || s == 'om') return const _StatutConfig('🟠', _DS.orangeLight, _DS.orange, Color(0xFFFFCCBC));
  if (s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit')
    return const _StatutConfig('📒', _DS.coralLight, _DS.coral, Color(0xFFFFCDD2));
  return const _StatutConfig('💵', _DS.emeraldFaint, _DS.emeraldMid, Color(0xFFC8E6C9));
}

String _labelStatut(String statut) {
  final s = _normaliser(statut);
  if (s == 'wave') return 'PAYÉ PAR WAVE';
  if (s == 'orange money' || s == 'om') return 'PAYÉ PAR OM';
  if (s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit') return 'À CRÉDIT';
  return 'PAYÉ EN CASH';
}

class VentesPage extends StatefulWidget {
  final int commercantId;
  const VentesPage({super.key, required this.commercantId});

  @override
  State<VentesPage> createState() => _VentesPageState();
}

class _VentesPageState extends State<VentesPage> with TickerProviderStateMixin {
  bool _loading = true;
  List<Map<String, dynamic>> _ventes = [];
  List<Map<String, dynamic>> _ventesFiltrees = [];
  String _filtrePeriode = 'aujourd_hui';
  String _filtreStatut  = 'tous';
  final Map<int, List<Map<String, dynamic>>> _itemsCache = {};
  late AnimationController _statsAnim;
  late Animation<double>   _statsReveal;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('fr_FR', null);
    _statsAnim   = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _statsReveal = CurvedAnimation(parent: _statsAnim, curve: Curves.easeOut);
    _charger();
  }

  @override
  void dispose() { _statsAnim.dispose(); super.dispose(); }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final data = await Supabase.instance.client
          .from('ventes')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('date_vente', ascending: false);
      setState(() {
        _ventes = List<Map<String, dynamic>>.from(data);
        _itemsCache.clear();
        _appliquerFiltres();
        _loading = false;
      });
      _statsAnim.forward(from: 0);
    } catch (e) {
      debugPrint('Erreur ventes: $e');
      setState(() => _loading = false);
    }
  }

  // ✅ CORRECTION : product_id est TEXT dans Supabase
  Future<List<Map<String, dynamic>>> _chargerItems(int venteId) async {
    if (_itemsCache.containsKey(venteId)) return _itemsCache[venteId]!;
    try {
      final rawItems = await Supabase.instance.client
          .from('ventes_items')
          .select()
          .eq('vente_id', venteId)
          .order('id');
      final items = List<Map<String, dynamic>>.from(rawItems);

      // ✅ product_id = TEXT (pas int)
      final ids = items
          .map((i) => i['product_id'] as String?)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (ids.isNotEmpty) {
        try {
          final produits = await Supabase.instance.client
              .from('products')
              .select('id, image_url, name')
              .inFilter('id', ids); // ✅ ids = List<String>

          final Map<String, Map<String, String?>> prodMap = {};
          for (final p in produits as List) {
            final id = p['id'] as String?;
            if (id != null) {
              prodMap[id] = {
                'image_url': p['image_url'] as String?,
                'name':      p['name']      as String?,
              };
            }
          }

          for (final item in items) {
            final pid = item['product_id'] as String?;
            if (pid != null && prodMap.containsKey(pid)) {
              item['image_url'] = prodMap[pid]!['image_url'];
              if ((item['nom_produit'] as String?)?.isEmpty ?? true) {
                item['nom_produit'] = prodMap[pid]!['name'];
              }
            }
          }
        } catch (e) {
          debugPrint('Erreur images produits: $e');
        }
      }

      _itemsCache[venteId] = items;
      return items;
    } catch (e) {
      debugPrint('Erreur items: $e');
      return [];
    }
  }

  void _appliquerFiltres() {
    final now = DateTime.now();
    final result = _ventes.where((v) {
      try {
        final date = DateTime.parse(v['date_vente'].toString());
        switch (_filtrePeriode) {
          case 'aujourd_hui':
            if (!(date.year == now.year && date.month == now.month && date.day == now.day)) return false;
          case 'semaine':
            if (now.difference(date).inDays > 7) return false;
          case 'mois':
            if (!(date.year == now.year && date.month == now.month)) return false;
        }
      } catch (_) {}
      if (_filtreStatut != 'tous') {
        final s = _normaliser(v['statut_paiement'] as String? ?? '');
        switch (_filtreStatut) {
          case 'paye':
            if (s == 'wave' || s == 'orange money' || s == 'om' || s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit') return false;
          case 'wave':
            if (s != 'wave') return false;
          case 'om':
            if (s != 'orange money' && s != 'om') return false;
          case 'credit':
            if (s != 'à crédit' && s != 'a credit' && s != 'crédit' && s != 'credit') return false;
        }
      }
      return true;
    }).toList();
    setState(() => _ventesFiltrees = result);
  }

  void _setFiltrePeriode(String v) { setState(() => _filtrePeriode = v); _appliquerFiltres(); }
  void _setFiltreStatut(String v)  { setState(() => _filtreStatut  = v); _appliquerFiltres(); }

  double get _totalFiltre => _ventesFiltrees.fold(0.0, (s, v) => s + ((v['total_montant'] ?? 0) as num).toDouble());
  double get _totalJour {
    final now = DateTime.now();
    return _ventes.where((v) {
      try {
        final d = DateTime.parse(v['date_vente'].toString());
        return d.year == now.year && d.month == now.month && d.day == now.day;
      } catch (_) { return false; }
    }).fold(0.0, (s, v) => s + ((v['total_montant'] ?? 0) as num).toDouble());
  }
  int get _nbCreditsFiltre => _ventesFiltrees.where((v) {
    final s = _normaliser(v['statut_paiement'] as String? ?? '');
    return s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit';
  }).length;
  double get _totalCreditEnCours => _ventes.where((v) {
    final s = _normaliser(v['statut_paiement'] as String? ?? '');
    return s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit';
  }).fold(0.0, (s, v) => s + ((v['total_montant'] ?? 0) as num).toDouble());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.fog,
      body: Column(children: [
        _buildHeader(),
        _buildFiltres(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _DS.emeraldMid))
              : _ventesFiltrees.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _charger,
                      color: _DS.emeraldMid,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
                        itemCount: _ventesFiltrees.length,
                        itemBuilder: (_, i) => _buildCarteVente(_ventesFiltrees[i]),
                      ),
                    ),
        ),
      ]),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: _DS.headerGrad),
      child: SafeArea(
        bottom: false,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Mes Ventes', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('${_ventes.length} vente${_ventes.length > 1 ? 's' : ''} au total',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12)),
                ]),
              ),
              GestureDetector(
                onTap: _charger,
                child: Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          FadeTransition(
            opacity: _statsReveal,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              child: Row(children: [
                _StatCard(icon: Icons.wb_sunny_rounded, iconColor: _DS.goldLight, label: "Aujourd'hui", value: '${_fmt(_totalJour)} F', valueColor: _DS.goldLight),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.receipt_long_rounded, iconColor: Colors.white, label: 'Période', value: '${_fmt(_totalFiltre)} F', valueColor: Colors.white),
                const SizedBox(width: 10),
                _StatCard(icon: Icons.warning_amber_rounded, iconColor: const Color(0xFFFFCDD2), label: 'Crédit impayé', value: '${_fmt(_totalCreditEnCours)} F', valueColor: const Color(0xFFFFCDD2)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFiltres() {
    return Container(
      color: _DS.white,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(children: [
            Expanded(child: _FiltreChipWide(key: const ValueKey('p1'), label: 'Auj.', icon: Icons.wb_sunny_rounded, iconColor: _DS.gold, accentColor: _DS.emeraldMid, selected: _filtrePeriode == 'aujourd_hui', onTap: () => _setFiltrePeriode('aujourd_hui'))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('p2'), label: '7 jours', icon: Icons.calendar_view_week_rounded, iconColor: _DS.sky, accentColor: _DS.emeraldMid, selected: _filtrePeriode == 'semaine', onTap: () => _setFiltrePeriode('semaine'))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('p3'), label: 'Ce mois', icon: Icons.calendar_month_rounded, iconColor: _DS.emeraldMid, accentColor: _DS.emeraldMid, selected: _filtrePeriode == 'mois', onTap: () => _setFiltrePeriode('mois'))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('p4'), label: 'Tout', icon: Icons.list_alt_rounded, iconColor: _DS.slate, accentColor: _DS.emeraldMid, selected: _filtrePeriode == 'tout', onTap: () => _setFiltrePeriode('tout'))),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          child: Row(children: [
            Expanded(child: _FiltreChipWide(key: const ValueKey('s1'), label: 'Tous', icon: Icons.apps_rounded, iconColor: _DS.emeraldMid, selected: _filtreStatut == 'tous', onTap: () => _setFiltreStatut('tous'))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('s2'), label: 'Cash', assetPath: _PaymentAssets.cash, selected: _filtreStatut == 'paye', onTap: () => _setFiltreStatut('paye'), accentColor: _DS.emeraldMid)),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('s3'), label: 'Wave', assetPath: _PaymentAssets.wave, selected: _filtreStatut == 'wave', onTap: () => _setFiltreStatut('wave'), accentColor: const Color(0xFF1A6DFF))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('s4'), label: 'OM', assetPath: _PaymentAssets.om, selected: _filtreStatut == 'om', onTap: () => _setFiltreStatut('om'), accentColor: const Color(0xFFFF6600))),
            const SizedBox(width: 6),
            Expanded(child: _FiltreChipWide(key: const ValueKey('s5'), label: 'Crédit', assetPath: _PaymentAssets.credit, selected: _filtreStatut == 'credit', onTap: () => _setFiltreStatut('credit'), accentColor: _DS.coral, badge: _nbCreditsFiltre > 0 ? '$_nbCreditsFiltre' : null)),
          ]),
        ),
        const Divider(height: 1, color: _DS.mist),
      ]),
    );
  }

  Widget _buildCarteVente(Map<String, dynamic> vente) {
    final double  total  = ((vente['total_montant'] ?? 0) as num).toDouble();
    final String  statut = (vente['statut_paiement'] as String? ?? '').trim();
    final String? nom    = vente['nom_client'] as String?;
    final cfg            = _configStatut(statut);
    DateTime? date;
    try { date = DateTime.parse(vente['date_vente'].toString()); } catch (_) {}
    final bool isCredit = _normaliser(statut) == 'à crédit' || _normaliser(statut) == 'crédit' || _normaliser(statut) == 'credit';

    return GestureDetector(
      onTap: () => _voirDetail(vente),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: _DS.shadow,
          border: Border.all(color: isCredit ? _DS.coral.withValues(alpha: 0.3) : _DS.mist, width: isCredit ? 1.5 : 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            _PaymentLogoBox(statut: statut, cfg: cfg),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (nom != null && nom.isNotEmpty)
                  Text(nom, style: _DS.label(14, c: _DS.ink, fw: FontWeight.w800), overflow: TextOverflow.ellipsis),
                if (date != null)
                  Text(DateFormat('dd MMM · HH:mm', 'fr_FR').format(date), style: _DS.label(11, c: _DS.slate, fw: FontWeight.w500)),
                const SizedBox(height: 6),
                _StatutBadge(statut: statut, cfg: cfg),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmt(total)} F', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: cfg.textClr, letterSpacing: -0.3)),
              const SizedBox(height: 6),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _DS.fog, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.chevron_right, color: _DS.slate, size: 18),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  void _voirDetail(Map<String, dynamic> vente) {
    final int     id     = vente['id'] as int;
    final double  total  = ((vente['total_montant'] ?? 0) as num).toDouble();
    final String  statut = (vente['statut_paiement'] as String? ?? '').trim();
    final String? nom    = vente['nom_client'] as String?;
    final cfg            = _configStatut(statut);
    DateTime? date;
    try { date = DateTime.parse(vente['date_vente'].toString()); } catch (_) {}
    final bool isCredit = _normaliser(statut) == 'à crédit' || _normaliser(statut) == 'crédit' || _normaliser(statut) == 'credit';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.93,
          builder: (_, ctrl) => FutureBuilder<List<Map<String, dynamic>>>(
            future: _chargerItems(id),
            builder: (_, snap) {
              final items = snap.data ?? [];
              return CustomScrollView(controller: ctrl, slivers: [
                SliverToBoxAdapter(
                  child: Column(children: [
                    const SizedBox(height: 12),
                    Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: _DS.mist, borderRadius: BorderRadius.circular(3)))),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [cfg.bg, cfg.bg.withValues(alpha: 0.5)]),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cfg.borderClr),
                      ),
                      child: Row(children: [
                        _PaymentLogoBox(statut: statut, cfg: cfg, size: 58),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${_fmt(total)} F CFA', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cfg.textClr, letterSpacing: -0.5)),
                            const SizedBox(height: 4),
                            Text(_labelStatut(statut), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cfg.textClr)),
                            if (date != null)
                              Text(DateFormat('EEEE dd MMMM yyyy · HH:mm', 'fr_FR').format(date),
                                  style: _DS.label(10, c: _DS.slate, fw: FontWeight.w400)),
                          ]),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (nom != null && nom.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(color: _DS.fog, borderRadius: BorderRadius.circular(14), border: Border.all(color: _DS.mist)),
                        child: Row(children: [
                          const Icon(Icons.person_outline, color: _DS.emeraldMid, size: 20),
                          const SizedBox(width: 10),
                          Text(nom, style: _DS.label(14, c: _DS.ink, fw: FontWeight.w700)),
                          const Spacer(),
                          if (isCredit)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _DS.coralLight, borderRadius: BorderRadius.circular(8)),
                              child: Text('Client crédit', style: _DS.label(10, c: _DS.coral, fw: FontWeight.w700)),
                            ),
                        ]),
                      ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(children: [
                        Container(width: 4, height: 18, decoration: BoxDecoration(color: _DS.emeraldMid, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 8),
                        Text('Articles achetés', style: _DS.label(14, c: _DS.ink, fw: FontWeight.w800)),
                      ]),
                    ),
                    const SizedBox(height: 12),
                  ]),
                ),
                if (snap.connectionState == ConnectionState.waiting)
                  const SliverToBoxAdapter(
                    child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: _DS.emeraldMid, strokeWidth: 2))),
                  )
                else
                  SliverList(delegate: SliverChildBuilderDelegate((_, i) => _buildLigneDetail(items[i]), childCount: items.length)),
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _DS.emeraldFaint,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: _DS.emeraldMid.withValues(alpha: 0.2)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                      Text('TOTAL', style: _DS.label(14, c: _DS.emeraldMid, fw: FontWeight.w700)),
                      Text('${_fmt(total)} F CFA', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: _DS.emeraldMid, letterSpacing: -0.4)),
                    ]),
                  ),
                ),
              ]);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLigneDetail(Map<String, dynamic> item) {
    final String nom      = (item['nom_produit']   as String?)?.isNotEmpty == true ? item['nom_produit'] as String : 'Produit';
    final String cat      = item['categorie']       as String? ?? 'Autre';
    final int    qty      = (item['quantite']       as num).toInt();
    final double pu       = (item['prix_unitaire']  as num).toDouble();
    final double st       = (item['sous_total']     as num).toDouble();
    final String? imageUrl = item['image_url']      as String?;

    final String fallbackEmoji = cat == 'Alimentaire' ? '🍞' : cat == 'Boissons' ? '🥤' : cat == 'Hygiène' ? '🧴' : '📦';
    const assetMap = {'Alimentaire': 'lib/assets/categories/aliment.jpg', 'Boissons': 'lib/assets/categories/boisson.jpg', 'Hygiène': 'lib/assets/categories/hygienne.jpg'};
    final String fallbackAsset = assetMap[cat] ?? 'lib/assets/categories/produit.png';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _DS.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _DS.mist)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _buildProduitImage(imageUrl: imageUrl, fallbackAsset: fallbackAsset, fallbackEmoji: fallbackEmoji),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(nom, style: _DS.label(13, c: _DS.ink, fw: FontWeight.w700)),
            const SizedBox(height: 2),
            Text('${_fmt(pu)} F × $qty', style: _DS.label(11, c: _DS.slate, fw: FontWeight.w400)),
          ]),
        ),
        Text('${_fmt(st)} F', style: _DS.label(14, c: _DS.emeraldMid, fw: FontWeight.w900)),
      ]),
    );
  }

  Widget _buildProduitImage({required String? imageUrl, required String fallbackAsset, required String fallbackEmoji}) {
    const double size = 46;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        imageUrl, width: size, height: size, fit: BoxFit.cover,
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(width: size, height: size, color: _DS.emeraldFaint, child: const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _DS.emeraldMid, strokeWidth: 2))));
        },
        errorBuilder: (_, __, ___) => _buildAssetImage(fallbackAsset, fallbackEmoji, size),
      );
    }
    return _buildAssetImage(fallbackAsset, fallbackEmoji, size);
  }

  Widget _buildAssetImage(String assetPath, String emoji, double size) {
    return Image.asset(assetPath, width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          width: size, height: size,
          decoration: BoxDecoration(color: _DS.emeraldFaint, borderRadius: BorderRadius.circular(10)),
          child: Center(child: Text(emoji, style: const TextStyle(fontSize: 22))),
        ));
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 100, height: 100, decoration: const BoxDecoration(color: _DS.mist, shape: BoxShape.circle), child: const Center(child: Text('🛒', style: TextStyle(fontSize: 48)))),
          const SizedBox(height: 24),
          Text('Aucune vente trouvée', style: _DS.label(18, c: _DS.ink, fw: FontWeight.w800)),
          const SizedBox(height: 8),
          Text('Changez les filtres ou\ncréez votre première vente', textAlign: TextAlign.center, style: _DS.label(13, c: _DS.slate, fw: FontWeight.w400)),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (_) => NouvelleVentePage(commercantId: widget.commercantId)));
              _charger();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_DS.emerald, _DS.emeraldMid]),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: _DS.emeraldMid.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add_circle_outline, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text('Nouvelle vente', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: () async {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => NouvelleVentePage(commercantId: widget.commercantId)));
        _charger();
      },
      backgroundColor: _DS.orange,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      icon: const Icon(Icons.add, size: 22),
      label: const Text('Nouvelle vente', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
    );
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}

class _PaymentAssets {
  static const cash   = 'assets/images/cash.jpg';
  static const wave   = 'assets/images/wave.png';
  static const om     = 'assets/images/orangeMoney.png';
  static const credit = 'assets/images/dettes.png';

  static String forStatut(String statut) {
    final s = statut.trim().toLowerCase();
    if (s == 'wave') return wave;
    if (s == 'orange money' || s == 'om') return om;
    if (s == 'à crédit' || s == 'a credit' || s == 'crédit' || s == 'credit') return credit;
    return cash;
  }
}

class _PaymentLogoBox extends StatelessWidget {
  final String statut;
  final _StatutConfig cfg;
  final double size;
  const _PaymentLogoBox({required this.statut, required this.cfg, this.size = 52});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.27);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(color: cfg.bg, borderRadius: radius, border: Border.all(color: cfg.borderClr, width: 1)),
      child: ClipRRect(
        borderRadius: radius,
        child: Image.asset(_PaymentAssets.forStatut(statut), width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallback()),
      ),
    );
  }

  Widget _buildFallback() {
    final s = statut.trim().toLowerCase();
    final (icon, color) = s == 'wave'
        ? (Icons.waves_rounded, const Color(0xFF1A6DFF))
        : (s == 'orange money' || s == 'om')
            ? (Icons.account_balance_wallet_rounded, const Color(0xFFFF6600))
            : (s == 'à crédit' || s == 'crédit' || s == 'credit')
                ? (Icons.menu_book_rounded, _DS.coral)
                : (Icons.payments_rounded, _DS.emeraldMid);
    return Container(color: cfg.bg, child: Center(child: Icon(icon, color: color, size: size * 0.48)));
  }
}

class _StatutBadge extends StatelessWidget {
  final String statut;
  final _StatutConfig cfg;
  const _StatutBadge({required this.statut, required this.cfg});

  @override
  Widget build(BuildContext context) {
    final s = statut.trim().toLowerCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: cfg.bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: cfg.borderClr, width: 0.5)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.asset(_PaymentAssets.forStatut(statut), width: 16, height: 16, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                s == 'à crédit' || s == 'crédit' || s == 'credit' ? Icons.menu_book_rounded : s == 'wave' ? Icons.waves_rounded : s == 'orange money' || s == 'om' ? Icons.account_balance_wallet_rounded : Icons.payments_rounded,
                color: cfg.textClr, size: 13,
              )),
        ),
        const SizedBox(width: 5),
        Text(_labelStatut(statut), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: cfg.textClr, letterSpacing: 0.5)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final String   label, value;
  final Color    valueColor;
  const _StatCard({required this.icon, required this.iconColor, required this.label, required this.value, required this.valueColor});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
      ),
      child: Column(children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(height: 5),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 9, fontWeight: FontWeight.w500), textAlign: TextAlign.center),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: valueColor, fontSize: 12, fontWeight: FontWeight.w900), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}

class _FiltreChipWide extends StatelessWidget {
  final String     label;
  final String?    assetPath;
  final IconData?  icon;
  final Color?     iconColor;
  final Color      accentColor;
  final bool       selected;
  final VoidCallback onTap;
  final String?    badge;

  const _FiltreChipWide({
    super.key,
    required this.label,
    this.assetPath,
    this.icon,
    this.iconColor,
    this.accentColor = _DS.emeraldMid,
    required this.selected,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 58,
        decoration: BoxDecoration(
          color: selected ? accentColor.withValues(alpha: 0.15) : _DS.fog,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? accentColor : _DS.mist, width: selected ? 2 : 1),
          boxShadow: selected ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3))] : [],
        ),
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: assetPath != null
                ? Image.asset(assetPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fallback())
                : _fallback(),
          ),
          if (selected)
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Container(
                color: accentColor.withValues(alpha: 0.35),
                child: const Center(child: Icon(Icons.check_circle_rounded, color: Colors.white, size: 22)),
              ),
            ),
          if (badge != null)
            Positioned(
              top: 4, right: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: _DS.coral, borderRadius: BorderRadius.circular(10)),
                child: Text(badge!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800)),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _fallback() => Container(
    color: selected ? accentColor.withValues(alpha: 0.12) : _DS.fog,
    child: Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon ?? Icons.payments_rounded, size: 20, color: selected ? accentColor : (iconColor ?? _DS.slate)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: selected ? accentColor : _DS.slate), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ]),
    ),
  );
}