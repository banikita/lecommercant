import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'page_stock.dart';

final _supa = Supabase.instance.client;
final _numFmt = NumberFormat('#,###', 'fr_FR');
String _f(num n) => '${_numFmt.format(n)} F';

const _green = Color(0xFF0F6E56);
const _greenLight = Color(0xFFE1F5EE);
const _red = Color(0xFFA32D2D);
const _redLight = Color(0xFFFCEBEB);
const _amber = Color(0xFFF59E0B);
const _amberLight = Color(0xFFFAEEDA);
const _amberMid = Color(0xFFFAC775);
const _grey = Color(0xFFF4F4F2);
const _greyMid = Color(0xFFE8E8E5);
const _textMuted = Color(0xFF6B7280);
const _textDark = Color(0xFF1A1A1A);

// ========== MODÈLES ==========
class Dette {
  final int id, commercantId, debiteurId;
  final String nomDebiteur, statut;
  final String? telephone, quartier;
  final double montantInitial, montantRembourse;
  final DateTime? echeance;
  final DateTime createdAt;

  Dette({
    required this.id,
    required this.commercantId,
    required this.debiteurId,
    required this.nomDebiteur,
    required this.statut,
    this.telephone,
    this.quartier,
    required this.montantInitial,
    required this.montantRembourse,
    this.echeance,
    required this.createdAt,
  });

  factory Dette.fromMap(
    Map<String, dynamic> m, {
    String? nomDebiteur,
    String? telephone,
    String? quartier,
  }) {
    return Dette(
      id: (m['id'] as num).toInt(),
      commercantId: (m['commercant_id'] as num).toInt(),
      debiteurId: (m['debiteur_id'] as num).toInt(),
      nomDebiteur: nomDebiteur ?? m['nom_debiteur'] as String? ?? '',
      statut: m['statut'] as String,
      telephone: telephone,
      quartier: quartier,
      montantInitial: (m['montant_initial'] as num).toDouble(),
      montantRembourse: (m['montant_rembourse'] as num).toDouble(),
      echeance: m['echeance'] != null
          ? DateTime.tryParse(m['echeance'] as String)
          : null,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  double get solde =>
      (montantInitial - montantRembourse).clamp(0, double.infinity);
  double get pct =>
      montantInitial > 0
          ? (montantRembourse / montantInitial).clamp(0.0, 1.0)
          : 0.0;
  bool get enRetard =>
      echeance != null &&
      echeance!.isBefore(DateTime.now()) &&
      statut != 'solde';
}

class Paiement {
  final int id, detteId, commercantId;
  final double montant;
  final String modePaiement;
  final DateTime date, createdAt;

  Paiement({
    required this.id,
    required this.detteId,
    required this.commercantId,
    required this.montant,
    required this.modePaiement,
    required this.date,
    required this.createdAt,
  });

  factory Paiement.fromMap(Map<String, dynamic> m) => Paiement(
        id: (m['id'] as num).toInt(),
        detteId: (m['dette_id'] as num).toInt(),
        commercantId: (m['commercant_id'] as num).toInt(),
        montant: (m['montant'] as num).toDouble(),
        modePaiement: m['mode_paiement'] as String,
        date: DateTime.parse(m['date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

class DetteProduit {
  final int id, detteId;
  final String? productId;
  final String productName;
  final int quantite;
  final double prixUnitaire;
  final String? imageUrl;

  DetteProduit({
    required this.id,
    required this.detteId,
    this.productId,
    required this.productName,
    required this.quantite,
    required this.prixUnitaire,
    this.imageUrl,
  });

  factory DetteProduit.fromMap(Map<String, dynamic> m) {
    return DetteProduit(
      id: (m['id'] as num).toInt(),
      detteId: (m['dette_id'] as num).toInt(),
      productId: m['product_id'] as String?,
      productName: m['product_name'] as String? ?? 'Produit inconnu',
      quantite: (m['quantite'] as num).toInt(),
      prixUnitaire: (m['prix_unitaire'] as num).toDouble(),
      imageUrl: m['image_url'] as String?,
    );
  }
}

class DebiteurAvecDettes {
  final int id;
  final String nom;
  final String? telephone, quartier;
  final List<Dette> dettes;

  DebiteurAvecDettes({
    required this.id,
    required this.nom,
    this.telephone,
    this.quartier,
    required this.dettes,
  });

  double get totalInitial => dettes.fold(0, (s, d) => s + d.montantInitial);
  double get totalRembourse =>
      dettes.fold(0, (s, d) => s + d.montantRembourse);
  double get soldeTotal => totalInitial - totalRembourse;
  double get pctTotal =>
      totalInitial > 0 ? totalRembourse / totalInitial : 0.0;

  String get statutGlobal {
    if (dettes.every((d) => d.statut == 'solde')) return 'solde';
    if (dettes.any((d) => d.enRetard)) return 'retard';
    return 'en_cours';
  }

  bool get enRetardGlobal => statutGlobal == 'retard';
}

class _Cfg {
  final String label, emoji;
  final Color bg, color;
  const _Cfg(this.label, this.emoji, this.bg, this.color);
}

_Cfg _cfg(Dette d) {
  if (d.statut == 'solde') return const _Cfg('Soldé', '✅', _greenLight, _green);
  if (d.enRetard) return const _Cfg('En retard', '⚠️', _redLight, _red);
  return const _Cfg('En cours', '⏳', _amberLight, _amber);
}

Color _aColor(String nom) {
  if (nom.isEmpty) return _green;
  const c = [
    _green,
    Color(0xFF1D4ED8),
    Color(0xFFA21CAF),
    Color(0xFFD97706),
    Color(0xFFDC2626)
  ];
  return c[nom.codeUnitAt(0) % c.length];
}

String _ini(String nom) {
  if (nom.isEmpty) return '?';
  final p = nom.trim().split(' ');
  return p.length >= 2
      ? '${p[0][0]}${p[1][0]}'.toUpperCase()
      : nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase();
}

// ========== WIDGET ICÔNE UNIFORMISÉ ==========
class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}

// ========== PAGE PRINCIPALE DETTES ==========
class DettesPage extends StatefulWidget {
  final int commercantId;
  const DettesPage({super.key, required this.commercantId});

  @override
  State<DettesPage> createState() => _DettesPageState();
}

class _DettesPageState extends State<DettesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  List<DebiteurAvecDettes> _debiteurs = [];
  List<Paiement> _paiements = [];
  bool _loading = true;
  String _recherche = '';
  String _filtre = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final dettesData = await _supa
          .from('dettes')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('created_at', ascending: false);

      final Set<int> debIds = {};
      for (var d in dettesData as List) {
        final id = d['debiteur_id'];
        if (id != null) debIds.add((id as num).toInt());
      }

      Map<int, Map<String, dynamic>> debMap = {};
      if (debIds.isNotEmpty) {
        final debData = await _supa
            .from('debiteurs')
            .select()
            .inFilter('id', debIds.toList());
        for (var deb in debData as List) {
          debMap[(deb['id'] as num).toInt()] = deb;
        }
      }

      Map<int, List<Dette>> group = {};
      for (var d in dettesData) {
        final int debId = (d['debiteur_id'] as num).toInt();
        final debInfo = debMap[debId];
        if (debInfo == null) continue;
        final dette = Dette.fromMap(
          d,
          nomDebiteur: debInfo['nom'] as String,
          telephone: debInfo['telephone'] as String?,
          quartier: debInfo['quartier'] as String?,
        );
        group.putIfAbsent(debId, () => []).add(dette);
      }

      final List<DebiteurAvecDettes> liste = [];
      for (var entry in group.entries) {
        final info = debMap[entry.key]!;
        liste.add(DebiteurAvecDettes(
          id: entry.key,
          nom: info['nom'] as String,
          telephone: info['telephone'] as String?,
          quartier: info['quartier'] as String?,
          dettes: entry.value,
        ));
      }

      final rp = await _supa
          .from('paiements')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('date', ascending: false);

      if (!mounted) return;
      setState(() {
        _debiteurs = liste;
        _paiements = (rp as List).map((e) => Paiement.fromMap(e)).toList();
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _snack('Erreur chargement : $e', erreur: true);
      }
    }
  }

  List<DebiteurAvecDettes> get _filtres {
    final q = _recherche.toLowerCase();
    return _debiteurs.where((deb) {
      final matchSearch = q.isEmpty ||
          deb.nom.toLowerCase().contains(q) ||
          (deb.telephone ?? '').contains(q);
      final matchFiltre = _filtre.isEmpty ||
          (_filtre == 'retard'
              ? deb.enRetardGlobal
              : deb.statutGlobal == _filtre);
      return matchSearch && matchFiltre;
    }).toList();
  }

  double get _totalCreances =>
      _debiteurs.fold(0, (s, d) => s + d.soldeTotal);
  double get _totalEncaisse =>
      _debiteurs.fold(0, (s, d) => s + d.totalRembourse);
  int get _nbRetard => _debiteurs.where((d) => d.enRetardGlobal).length;
  double get _encaissesMois {
    final now = DateTime.now();
    return _paiements
        .where((p) => p.date.year == now.year && p.date.month == now.month)
        .fold(0.0, (s, p) => s + p.montant);
  }

  void _snack(String msg, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: erreur ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: Column(children: [
        _buildHeader(),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tab,
            indicatorColor: _green,
            indicatorWeight: 3,
            labelColor: _green,
            unselectedLabelColor: _textMuted,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            tabs: const [
              Tab(text: '👤  Débiteurs'),
              Tab(text: '📊  Statistiques')
            ],
          ),
        ),
        _buildBarre(),
        Expanded(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: _green))
              : TabBarView(
                  controller: _tab,
                  children: [_buildListe(), _buildStats()]),
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _ouvrirModalAjout(null),
        backgroundColor: _green,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nouveau client',
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
        elevation: 4,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(children: [
            Row(children: [
              _IconBtn(
                  icon: Icons.arrow_back_ios_new,
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gestion des dettes',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                    Text('Débiteurs & crédits clients',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              _IconBtn(icon: Icons.refresh, onTap: _charger),
            ]),
            const SizedBox(height: 16),
            Row(children: [
              _MiniStat('Créances', _f(_totalCreances),
                  Icons.account_balance_wallet_outlined, _amberMid),
              const SizedBox(width: 8),
              _MiniStat(
                  'En retard',
                  '$_nbRetard client${_nbRetard > 1 ? 's' : ''}',
                  Icons.warning_amber_rounded,
                  Colors.redAccent.shade100),
              const SizedBox(width: 8),
              _MiniStat('Encaissé ce mois', _f(_encaissesMois),
                  Icons.check_circle_outline,
                  Colors.lightGreenAccent.shade100),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _buildBarre() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _recherche = v),
            decoration: InputDecoration(
              hintText: 'Chercher un client…',
              hintStyle: const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon:
                  const Icon(Icons.search, color: _textMuted, size: 20),
              suffixIcon: _recherche.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close,
                          size: 18, color: _textMuted),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _recherche = '');
                      })
                  : null,
              filled: true,
              fillColor: _grey,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration:
              BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _filtre,
              style: const TextStyle(
                  fontSize: 12,
                  color: _textDark,
                  fontWeight: FontWeight.w700),
              items: const [
                DropdownMenuItem(value: '', child: Text('Tous')),
                DropdownMenuItem(
                    value: 'en_cours', child: Text('🟡 En cours')),
                DropdownMenuItem(value: 'retard', child: Text('🔴 Retard')),
                DropdownMenuItem(value: 'solde', child: Text('🟢 Soldé')),
              ],
              onChanged: (v) => setState(() => _filtre = v ?? ''),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildListe() {
    if (_filtres.isEmpty) return _buildVide();
    return RefreshIndicator(
      onRefresh: _charger,
      color: _green,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 100),
        itemCount: _filtres.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final deb = _filtres[i];
          return _CarteDebiteur(
            debiteur: deb,
            onFiche: () => _ouvrirFiche(deb),
            onNouvelleDette: () => _ouvrirModalAjout(deb),
            onSupprimer: () => _confirmerSuppression(deb),
          );
        },
      ),
    );
  }

  Widget _buildVide() => Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(24)),
            child:
                const Center(child: Text('📋', style: TextStyle(fontSize: 40))),
          ),
          const SizedBox(height: 16),
          Text(
            _recherche.isNotEmpty
                ? 'Aucun résultat pour "$_recherche"'
                : 'Aucun débiteur pour l\'instant',
            style: const TextStyle(
                color: _textMuted, fontSize: 14, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text('Appuyez sur + pour ajouter un client et sa dette',
              style: TextStyle(color: _textMuted, fontSize: 12)),
        ]),
      );

  Widget _buildStats() {
    final total = _totalCreances + _totalEncaisse;
    final taux = total > 0 ? _totalEncaisse / total : 0.0;
    final top5 = [..._debiteurs]
      ..sort((a, b) => b.soldeTotal.compareTo(a.soldeTotal));
    final Map<String, double> parMois = {};
    for (final p in _paiements) {
      final k = DateFormat('MMM yy', 'fr_FR').format(p.date);
      parMois[k] = (parMois[k] ?? 0) + p.montant;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 80),
      children: [
        _SecTitle('📈  Résumé global'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
              child: _StatBig(
                  'Total créances', _f(_totalCreances), _red, _redLight)),
          const SizedBox(width: 10),
          Expanded(
              child: _StatBig(
                  'Total encaissé', _f(_totalEncaisse), _green, _greenLight)),
        ]),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _greyMid, width: 0.5),
          ),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Taux de recouvrement',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _textDark)),
              Text('${(taux * 100).round()}%',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _green)),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: taux,
                minHeight: 10,
                backgroundColor: _greyMid,
                valueColor: const AlwaysStoppedAnimation<Color>(_green),
              ),
            ),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(
                  '${_debiteurs.where((d) => d.statutGlobal == 'en_cours').length} en cours',
                  style: const TextStyle(fontSize: 11, color: _amber)),
              Text('$_nbRetard en retard',
                  style: const TextStyle(fontSize: 11, color: _red)),
              Text(
                  '${_debiteurs.where((d) => d.statutGlobal == 'solde').length} soldés',
                  style: const TextStyle(fontSize: 11, color: _green)),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        _SecTitle('🏆  Top 5 débiteurs par solde'),
        const SizedBox(height: 10),
        if (top5.isEmpty)
          _emptyCard('Aucune donnée')
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _greyMid, width: 0.5),
            ),
            child: Column(
              children: top5.take(5).map((deb) {
                final max = top5.first.soldeTotal;
                final pct = max > 0 ? deb.soldeTotal / max : 0.0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _aColor(deb.nom).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(_ini(deb.nom),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: _aColor(deb.nom))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(deb.nom,
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              Text(_f(deb.soldeTotal),
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color:
                                          deb.soldeTotal > 0 ? _red : _green)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: pct,
                              minHeight: 5,
                              backgroundColor: _greyMid,
                              valueColor:
                                  const AlwaysStoppedAnimation<Color>(_green),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),
        _SecTitle('💳  Paiements par mois'),
        const SizedBox(height: 10),
        if (parMois.isEmpty)
          _emptyCard('Aucun paiement enregistré')
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _greyMid, width: 0.5),
            ),
            child: Column(
              children: parMois.entries.map((e) {
                final isLast = e.key == parMois.keys.last;
                return Column(children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: _greenLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(e.key,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _green)),
                      ),
                      const Spacer(),
                      Text(_f(e.value),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _green)),
                    ]),
                  ),
                  if (!isLast) const Divider(height: 0, color: _greyMid),
                ]);
              }).toList(),
            ),
          ),
      ],
    );
  }

  void _ouvrirFiche(DebiteurAvecDettes debiteur) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FichePage(
          debiteurId: debiteur.id,
          nomDebiteur: debiteur.nom,
          telephone: debiteur.telephone,
          quartier: debiteur.quartier,
          commercantId: widget.commercantId,
          onRefreshParent: _charger,
        ),
      ),
    );
  }

  // ========== MODAL AJOUT DETTE (inchangé) ==========
  void _ouvrirModalAjout(DebiteurAvecDettes? debiteur) {
    final nomCtrl = TextEditingController(text: debiteur?.nom ?? '');
    final telCtrl = TextEditingController(text: debiteur?.telephone ?? '');
    final quartierCtrl =
        TextEditingController(text: debiteur?.quartier ?? '');
    final montantCtrl = TextEditingController();
    DateTime? echeance;
    String modeSaisie = 'auto';
    List<Map<String, dynamic>> produitsStock = [];
    List<Map<String, dynamic>> produitsManuels = [];

    void majTotal(StateSetter setS) {
      double total = 0;
      if (modeSaisie == 'auto') {
        total = produitsStock.fold(
            0.0,
            (s, p) =>
                s +
                (p['price'] as num).toDouble() * (p['quantite'] as int));
      } else {
        total = produitsManuels.fold(
            0.0,
            (s, p) =>
                s +
                (p['prix'] as num).toDouble() * (p['quantite'] as int));
      }
      montantCtrl.text = total.toInt().toString();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) {
          bool saving = false;
          String nouveauNom = '';
          String nouveauPrix = '';
          String nouvelleQte = '1';

          return _Modal(
            title: debiteur == null
                ? '➕  Nouveau client + dette'
                : '➕  Nouvelle dette — ${debiteur.nom}',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Champ(
                    label: 'Nom du débiteur *',
                    ctrl: nomCtrl,
                    hint: 'Ex : Fatou Diallo',
                    icon: Icons.person_outline),
                const SizedBox(height: 12),
                _Champ(
                    label: 'Téléphone',
                    ctrl: telCtrl,
                    hint: '77 xxx xx xx',
                    icon: Icons.phone_outlined,
                    type: TextInputType.phone),
                const SizedBox(height: 12),
                _Champ(
                    label: 'Quartier',
                    ctrl: quartierCtrl,
                    hint: 'Ex : Ouakam',
                    icon: Icons.location_on_outlined),
                const SizedBox(height: 12),

                // Mode saisie
                Row(children: [
                  const Text('Mode :',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'auto', label: Text('📦 Stock')),
                        ButtonSegment(
                            value: 'manual', label: Text('✍️ Manuel')),
                      ],
                      selected: {modeSaisie},
                      onSelectionChanged: (s) {
                        setS(() {
                          modeSaisie = s.first;
                          if (modeSaisie == 'manual') produitsStock.clear();
                          else produitsManuels.clear();
                          majTotal(setS);
                        });
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 12),

                // ===== MODE STOCK =====
                if (modeSaisie == 'auto') ...[
                  OutlinedButton.icon(
                    onPressed: () async {
                      final result =
                          await Navigator.push<List<Map<String, dynamic>>>(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => StockPage(
                              commercantId: widget.commercantId,
                              isSelectionMode: true),
                        ),
                      );
                      if (result != null && result.isNotEmpty) {
                        setS(() {
                          for (var n in result) {
                            final idx = produitsStock
                                .indexWhere((p) => p['id'] == n['id']);
                            if (idx != -1) {
                              produitsStock[idx]['quantite'] =
                                  (produitsStock[idx]['quantite'] as int) +
                                      (n['quantite'] as int);
                            } else {
                              produitsStock.add(n);
                            }
                          }
                          majTotal(setS);
                        });
                      }
                    },
                    icon: const Icon(Icons.shopping_cart, color: _green),
                    label: Text(
                      produitsStock.isEmpty
                          ? 'Sélectionner des produits'
                          : '${produitsStock.length} produit(s) choisi(s)',
                      style: const TextStyle(color: _green),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 46),
                      side: const BorderSide(color: _green),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (produitsStock.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                          color: _grey,
                          borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: produitsStock.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final p = produitsStock[i];
                          return ListTile(
                            dense: true,
                            leading: _ProduitImageMini(
                                imageUrl: p['imageUrl'] as String?),
                            title: Text(p['name'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${p['quantite']} × ${(p['price'] as num).toStringAsFixed(0)} F'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: _red),
                              onPressed: () => setS(() {
                                produitsStock.removeAt(i);
                                majTotal(setS);
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                ],

                // ===== MODE MANUEL =====
                if (modeSaisie == 'manual') ...[
                  Card(
                    elevation: 0,
                    color: _grey,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(children: [
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'Nom du produit',
                            prefixIcon: Icon(Icons.label, size: 20),
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (v) => nouveauNom = v,
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Prix (F)',
                                prefixIcon:
                                    Icon(Icons.attach_money, size: 20),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (v) => nouveauPrix = v,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              decoration: const InputDecoration(
                                labelText: 'Qté',
                                prefixIcon:
                                    Icon(Icons.numbers, size: 20),
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              onChanged: (v) => nouvelleQte = v,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: _green, size: 32),
                            onPressed: () {
                              final nomT = nouveauNom.trim();
                              if (nomT.isEmpty) return;
                              final prix =
                                  double.tryParse(nouveauPrix) ?? 0;
                              final qty =
                                  int.tryParse(nouvelleQte) ?? 0;
                              if (prix <= 0 || qty <= 0) return;
                              setS(() {
                                produitsManuels.add({
                                  'nom': nomT,
                                  'prix': prix,
                                  'quantite': qty
                                });
                                majTotal(setS);
                                nouveauNom = '';
                                nouveauPrix = '';
                                nouvelleQte = '1';
                              });
                            },
                          ),
                        ]),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (produitsManuels.isNotEmpty)
                    Container(
                      constraints: const BoxConstraints(maxHeight: 200),
                      decoration: BoxDecoration(
                          color: _grey,
                          borderRadius: BorderRadius.circular(12)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: produitsManuels.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 0),
                        itemBuilder: (_, i) {
                          final p = produitsManuels[i];
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.shopping_bag,
                                color: _green),
                            title: Text(p['nom'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                                '${p['quantite']} × ${(p['prix'] as num).toStringAsFixed(0)} F'),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: _red),
                              onPressed: () => setS(() {
                                produitsManuels.removeAt(i);
                                majTotal(setS);
                              }),
                            ),
                          );
                        },
                      ),
                    ),
                ],

                const SizedBox(height: 12),
                _Champ(
                    label: 'Montant dû (F CFA) *',
                    ctrl: montantCtrl,
                    hint: 'Calculé automatiquement',
                    icon: Icons.payments_outlined,
                    type: TextInputType.number,
                    fmt: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 12),

                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: ctx,
                      initialDate:
                          DateTime.now().add(const Duration(days: 30)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 365)),
                      builder: (_, child) => Theme(
                        data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                                primary: _green)),
                        child: child!,
                      ),
                    );
                    if (d != null) setS(() => echeance = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                        color: _grey,
                        borderRadius: BorderRadius.circular(12)),
                    child: Row(children: [
                      const Icon(Icons.calendar_today_outlined,
                          color: _green, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        echeance == null
                            ? "Date d'échéance (optionnel)"
                            : 'Échéance : ${echeance!.day}/${echeance!.month}/${echeance!.year}',
                        style: TextStyle(
                            fontSize: 14,
                            color: echeance == null
                                ? _textMuted
                                : _textDark),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 24),

                _Btn(
                  label: 'Enregistrer',
                  loading: saving,
                  onTap: () async {
                    final nom = nomCtrl.text.trim();
                    final tel = telCtrl.text.trim().isEmpty
                        ? null
                        : telCtrl.text.trim();
                    final quartier = quartierCtrl.text.trim().isEmpty
                        ? null
                        : quartierCtrl.text.trim();
                    final montantStr = montantCtrl.text.trim();
                    if (nom.isEmpty || montantStr.isEmpty) {
                      _snack('Remplissez le nom et le montant',
                          erreur: true);
                      return;
                    }
                    final montant = double.parse(montantStr);
                    setS(() => saving = true);
                    try {
                      int debiteurId;

                      if (debiteur != null) {
                        debiteurId = debiteur.id;
                      } else {
                        var q = _supa
                            .from('debiteurs')
                            .select()
                            .eq('commercant_id', widget.commercantId);
                        q = (tel != null && tel.isNotEmpty)
                            ? q.eq('telephone', tel)
                            : q.eq('nom', nom);
                        final existing = await q;
                        if ((existing as List).isNotEmpty) {
                          debiteurId =
                              (existing.first['id'] as num).toInt();
                        } else {
                          final now =
                              DateTime.now().toIso8601String();
                          final nd = await _supa
                              .from('debiteurs')
                              .insert({
                                'commercant_id': widget.commercantId,
                                'nom': nom,
                                'telephone': tel,
                                'quartier': quartier,
                                'created_at': now,
                                'updated_at': now,
                              })
                              .select('id')
                              .single();
                          debiteurId = (nd['id'] as num).toInt();
                        }
                      }

                      // Vérifier dettes impayées
                      final ex = await _supa
                          .from('dettes')
                          .select()
                          .eq('commercant_id', widget.commercantId)
                          .eq('debiteur_id', debiteurId)
                          .neq('statut', 'solde');
                      final unpaid = (ex as List).where((e) {
                        final r =
                            (e['montant_rembourse'] as num).toDouble();
                        final i =
                            (e['montant_initial'] as num).toDouble();
                        return i - r > 0;
                      }).toList();

                      if (unpaid.isNotEmpty) {
                        setS(() => saving = false);
                        final totalDue = unpaid.fold(0.0, (s, e) {
                          return s +
                              (e['montant_initial'] as num).toDouble() -
                              (e['montant_rembourse'] as num).toDouble();
                        });
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (dc) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18)),
                            title:
                                const Text('⚠️ Dette impayée existante'),
                            content: Text(
                              'Ce client a déjà des dettes non soldées.\n'
                              'Restant dû : ${_f(totalDue)}\n\n'
                              'Accorder quand même un crédit ?',
                              style: const TextStyle(fontSize: 14),
                            ),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(dc, false),
                                  child: const Text('Annuler',
                                      style:
                                          TextStyle(color: _textMuted))),
                              ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(dc, true),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _amber,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                child: const Text('Accorder',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        setS(() => saving = true);
                      }

                      // ✅ Créer la dette
                      final now = DateTime.now().toIso8601String();
                      final nd = await _supa
                          .from('dettes')
                          .insert({
                            'commercant_id': widget.commercantId,
                            'debiteur_id': debiteurId,
                            'nom_debiteur': nom,
                            'montant_initial': montant,
                            'montant_rembourse': 0,
                            'statut': 'en_cours',
                            'echeance': echeance
                                ?.toIso8601String()
                                .split('T')
                                .first,
                            'created_at': now,
                            'updated_at': now,
                          })
                          .select('id')
                          .single();
                      final int newId = (nd['id'] as num).toInt();

                      // ✅ Insérer produits stock
                      if (modeSaisie == 'auto' &&
                          produitsStock.isNotEmpty) {
                        for (var p in produitsStock) {
                          try {
                            debugPrint('📦 Insertion produit stock: dette_id=$newId nom=${p['name']}');
                            await _supa.from('dette_produits').insert({
                              'dette_id': newId,
                              'product_id': p['id']?.toString(),
                              'product_name': p['name'] as String,
                              'quantite': p['quantite'] as int,
                              'prix_unitaire':
                                  (p['price'] as num).toDouble(),
                              'image_url': p['imageUrl'] as String?,
                            });
                            debugPrint('✅ Produit stock inséré OK');
                          } catch (eInsert) {
                            debugPrint('❌ Erreur insertion produit stock: $eInsert');
                            _snack('Erreur produit: $eInsert', erreur: true);
                          }
                        }
                      }
                      // ✅ Insérer produits manuels
                      else if (modeSaisie == 'manual' &&
                          produitsManuels.isNotEmpty) {
                        for (var p in produitsManuels) {
                          try {
                            debugPrint('✍️ Insertion produit manuel: dette_id=$newId nom=${p['nom']}');
                            await _supa.from('dette_produits').insert({
                              'dette_id': newId,
                              'product_id': null,
                              'product_name': p['nom'] as String,
                              'quantite': p['quantite'] as int,
                              'prix_unitaire':
                                  (p['prix'] as num).toDouble(),
                              'image_url': null,
                            });
                            debugPrint('✅ Produit manuel inséré OK');
                          } catch (eInsert) {
                            debugPrint('❌ Erreur insertion produit manuel: $eInsert');
                            _snack('Erreur produit: $eInsert', erreur: true);
                          }
                        }
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      _charger();
                      final nb = modeSaisie == 'auto'
                          ? produitsStock.length
                          : produitsManuels.length;
                      _snack(
                          '✅ Dette enregistrée${nb > 0 ? ' avec $nb produit(s)' : ''} !');
                    } catch (e) {
                      setS(() => saving = false);
                      debugPrint('❌ Erreur globale enregistrement: $e');
                      _snack('Erreur : $e', erreur: true);
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _confirmerSuppression(DebiteurAvecDettes deb) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Supprimer ce client ?',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
          'Supprimer ${deb.nom} avec toutes ses dettes et paiements ?',
          style: const TextStyle(fontSize: 14, color: _textMuted),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child:
                  const Text('Annuler', style: TextStyle(color: _textMuted))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        for (var d in deb.dettes) {
          await _supa.from('dettes').delete().eq('id', d.id);
        }
        _charger();
        _snack('Client supprimé');
      } catch (e) {
        _snack('Erreur : $e', erreur: true);
      }
    }
  }

  Widget _emptyCard(String msg) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _greyMid, width: 0.5)),
        child: Center(
            child: Text(msg,
                style: const TextStyle(color: _textMuted, fontSize: 13))),
      );
}

// ========== WIDGET IMAGE MINI ==========
class _ProduitImageMini extends StatelessWidget {
  final String? imageUrl;
  const _ProduitImageMini({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.shopping_bag, size: 22, color: _green),
        ),
      );
    }
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
          color: _greenLight, borderRadius: BorderRadius.circular(6)),
      child: const Icon(Icons.shopping_bag, size: 20, color: _green),
    );
  }
}

// ========== CARTE DÉBITEUR ==========
class _CarteDebiteur extends StatelessWidget {
  final DebiteurAvecDettes debiteur;
  final VoidCallback onFiche, onNouvelleDette, onSupprimer;

  const _CarteDebiteur({
    required this.debiteur,
    required this.onFiche,
    required this.onNouvelleDette,
    required this.onSupprimer,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = _cfgStatut(debiteur);
    final av = _aColor(debiteur.nom);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _greyMid, width: 0.5),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        Row(children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: av.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: av.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Center(
                child: Text(_ini(debiteur.nom),
                    style: TextStyle(
                        color: av,
                        fontSize: 18,
                        fontWeight: FontWeight.w900))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(debiteur.nom,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textDark)),
                const SizedBox(height: 3),
                if (debiteur.telephone != null)
                  Row(children: [
                    const Icon(Icons.phone_outlined,
                        size: 12, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(debiteur.telephone!,
                        style:
                            const TextStyle(fontSize: 12, color: _textMuted)),
                  ]),
                if (debiteur.quartier != null) ...[
                  const SizedBox(height: 2),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: _textMuted),
                    const SizedBox(width: 4),
                    Text(debiteur.quartier!,
                        style:
                            const TextStyle(fontSize: 12, color: _textMuted)),
                  ]),
                ],
              ],
            ),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_f(debiteur.soldeTotal),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: debiteur.soldeTotal > 0 ? _red : _green)),
            const SizedBox(height: 4),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                  color: cfg.bg, borderRadius: BorderRadius.circular(20)),
              child: Text('${cfg.emoji}  ${cfg.label}',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: cfg.color)),
            ),
          ]),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Remboursé : ${_f(debiteur.totalRembourse)}',
              style: const TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w600)),
          Text('Total : ${_f(debiteur.totalInitial)}',
              style: const TextStyle(
                  fontSize: 11,
                  color: _textMuted,
                  fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: LinearProgressIndicator(
            value: debiteur.pctTotal,
            minHeight: 7,
            backgroundColor: _greyMid,
            valueColor: AlwaysStoppedAnimation<Color>(
                debiteur.pctTotal >= 1.0
                    ? _green
                    : _green.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: _grey,
                borderRadius: BorderRadius.circular(8)),
            child: GestureDetector(
              onTap: onFiche,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.visibility_outlined, size: 14, color: _textMuted),
                const SizedBox(width: 5),
                const Text('Voir',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: _textMuted)),
              ]),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: onNouvelleDette,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Dette', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              elevation: 1,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onSupprimer,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: _redLight,
                  borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(Icons.delete_outline, size: 16, color: _red),
            ),
          ),
        ]),
      ]),
    );
  }

  _Cfg _cfgStatut(DebiteurAvecDettes d) {
    if (d.statutGlobal == 'solde')
      return const _Cfg('Soldé', '✅', _greenLight, _green);
    if (d.enRetardGlobal)
      return const _Cfg('En retard', '⚠️', _redLight, _red);
    return const _Cfg('En cours', '⏳', _amberLight, _amber);
  }
}

// ========== FICHE DÉBITEUR (VERSION CORRIGÉE) ==========
class _FichePage extends StatefulWidget {
  final int debiteurId;
  final int commercantId;
  final String nomDebiteur;
  final String? telephone;
  final String? quartier;
  final VoidCallback onRefreshParent;

  const _FichePage({
    required this.debiteurId,
    required this.commercantId,
    required this.nomDebiteur,
    this.telephone,
    this.quartier,
    required this.onRefreshParent,
  });

  @override
  State<_FichePage> createState() => _FichePageState();
}

class _FichePageState extends State<_FichePage> {
  DebiteurAvecDettes? _debiteur;
  List<Paiement> _tousPaiements = [];
  Map<int, List<DetteProduit>> _produitsParDette = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final debData = await _supa
          .from('debiteurs')
          .select()
          .eq('id', widget.debiteurId)
          .single();

      final dettesData = await _supa
          .from('dettes')
          .select()
          .eq('commercant_id', widget.commercantId)
          .eq('debiteur_id', widget.debiteurId)
          .order('created_at', ascending: false);

      final List<Dette> dettes = (dettesData as List).map((e) {
        return Dette.fromMap(
          e,
          nomDebiteur: debData['nom'] as String,
          telephone: debData['telephone'] as String?,
          quartier: debData['quartier'] as String?,
        );
      }).toList();

      final Map<int, List<DetteProduit>> produitsParDette = {};
      for (final dette in dettes) {
        final response = await _supa
            .from('dette_produits')
            .select('*')
            .eq('dette_id', dette.id);
        final List<dynamic> data = response;
        debugPrint('📦 Dette ${dette.id} -> ${data.length} produit(s)');
        for (var item in data) {
          try {
            final prod = DetteProduit.fromMap(item as Map<String, dynamic>);
            produitsParDette.putIfAbsent(prod.detteId, () => []).add(prod);
            debugPrint('   ✅ Ajouté: ${prod.productName} (${prod.quantite}x)');
          } catch (e, stack) {
            debugPrint('   ❌ Erreur parsing: $e');
            debugPrint(stack.toString());
          }
        }
      }

      List<Paiement> paiements = [];
      for (final dette in dettes) {
        try {
          final pd = await _supa
              .from('paiements')
              .select()
              .eq('commercant_id', widget.commercantId)
              .eq('dette_id', dette.id)
              .order('date', ascending: false);
          paiements.addAll((pd as List).map((e) => Paiement.fromMap(e)));
        } catch (_) {}
      }
      paiements.sort((a, b) => b.date.compareTo(a.date));

      final debiteur = DebiteurAvecDettes(
        id: (debData['id'] as num).toInt(),
        nom: debData['nom'] as String,
        telephone: debData['telephone'] as String?,
        quartier: debData['quartier'] as String?,
        dettes: dettes,
      );

      if (mounted) {
        setState(() {
          _debiteur = debiteur;
          _tousPaiements = paiements;
          _produitsParDette = produitsParDette;
          _loading = false;
        });
      }
    } catch (e, stack) {
      debugPrint('❌ Erreur globale _loadData: $e');
      debugPrint(stack.toString());
      if (mounted) {
        setState(() => _loading = false);
        _snack('Erreur : $e', erreur: true);
      }
    }
  }

  Future<void> _paiementGlobal(double montant, String mode) async {
    if (_debiteur == null) return;
    final nonSoldees = _debiteur!.dettes
        .where((d) => d.solde > 0)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    double reste = montant;
    try {
      for (var d in nonSoldees) {
        if (reste <= 0) break;
        final part = reste < d.solde ? reste : d.solde;
        final newRemb = d.montantRembourse + part;
        final solde = newRemb >= d.montantInitial;
        await _supa.from('dettes').update({
          'montant_rembourse': newRemb,
          'statut': solde ? 'solde' : 'en_cours',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', d.id);
        await _supa.from('paiements').insert({
          'dette_id': d.id,
          'commercant_id': widget.commercantId,
          'montant': part,
          'mode_paiement': mode,
          'date': DateTime.now().toIso8601String().split('T').first,
          'created_at': DateTime.now().toIso8601String(),
        });
        reste -= part;
      }
      await _loadData();
      widget.onRefreshParent();
      _snack('✅ Paiement de ${_f(montant)} effectué !');
    } catch (e) {
      _snack('Erreur paiement : $e', erreur: true);
      rethrow;
    }
  }

  Future<void> _openMobileMoneyApp(String appScheme, String appStoreUrl) async {
    final Uri url = Uri.parse(appScheme);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      final Uri storeUrl = Uri.parse(appStoreUrl);
      if (await canLaunchUrl(storeUrl)) {
        await launchUrl(storeUrl);
      } else {
        _snack("Impossible d'ouvrir l'application ou le store.", erreur: true);
      }
    }
  }

  void _ouvrirPaiement() {
    final ctrl = TextEditingController();
    String mode = 'Espèces';
    final solde = _debiteur?.soldeTotal ?? 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setS) {
          bool saving = false;
          return _Modal(
            title: '💵 Paiement — ${_debiteur?.nom ?? ''}',
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                    color: _redLight,
                    borderRadius: BorderRadius.circular(12)),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Solde total dû',
                          style: TextStyle(
                              fontSize: 13,
                              color: _red,
                              fontWeight: FontWeight.w700)),
                      Text(_f(solde),
                          style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: _red)),
                    ]),
              ),
              const SizedBox(height: 16),
              _Champ(
                label: 'Montant (F CFA) *',
                ctrl: ctrl,
                hint: solde.toStringAsFixed(0),
                icon: Icons.payments_outlined,
                type: TextInputType.number,
                fmt: [FilteringTextInputFormatter.digitsOnly],
              ),
              const SizedBox(height: 14),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Mode de paiement',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _textMuted)),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildModeBtn('Espèces', 'assets/images/cash.jpg', mode, setS),
                  _buildModeBtn('Wave', 'assets/images/wave.png', mode, setS,
                      onExternalTap: () => _openMobileMoneyApp('wave://', 'https://play.google.com/store/apps/details?id=com.wave.android')),
                  _buildModeBtn('Orange Money', 'assets/images/orangeMoney.png', mode, setS,
                      onExternalTap: () => _openMobileMoneyApp('orangemoney://', 'https://play.google.com/store/apps/details?id=com.orange.orangemoney')),
                ],
              ),
              const SizedBox(height: 24),
              _Btn(
                label: 'Valider',
                loading: saving,
                onTap: () async {
                  final s = ctrl.text.trim();
                  if (s.isEmpty) return;
                  final m = double.parse(s);
                  if (m <= 0) {
                    _snack('Montant invalide', erreur: true);
                    return;
                  }
                  if (m > solde) {
                    _snack('Max : ${_f(solde)}', erreur: true);
                    return;
                  }
                  setS(() => saving = true);
                  try {
                    await _paiementGlobal(m, mode);
                    if (ctx2.mounted) Navigator.pop(ctx2);
                  } catch (e) {
                    // l'erreur est déjà affichée dans _paiementGlobal
                  } finally {
                    if (ctx2.mounted) setS(() => saving = false);
                  }
                },
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _buildModeBtn(String label, String assetPath, String current, StateSetter setS, {VoidCallback? onExternalTap}) {
    final selected = current == label;
    return GestureDetector(
      onTap: () {
        // 1. Mettre à jour le mode sélectionné
        setS(() => current = label);
        // 2. Si un callback externe est fourni (Wave/Orange), l'exécuter
        if (onExternalTap != null) {
          onExternalTap();
        }
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: selected ? Border.all(color: _green, width: 3) : null,
        ),
        child: Image.asset(
          assetPath,
          width: 48,
          height: 48,
        ),
      ),
    );
  }

  void _snack(String msg, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: erreur ? _red : _green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final nomAffiche = _debiteur?.nom ?? widget.nomDebiteur;

    if (_loading) {
      return Scaffold(
        backgroundColor: _grey,
        appBar: AppBar(
          title: Text(nomAffiche,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: Colors.white)),
          backgroundColor: _green,
          foregroundColor: Colors.white,
        ),
        body: const Center(
            child: CircularProgressIndicator(color: _green)),
      );
    }

    if (_debiteur == null) {
      return const Scaffold(
        backgroundColor: _grey,
        body: Center(child: Text('Débiteur introuvable')),
      );
    }

    final deb = _debiteur!;
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      backgroundColor: _grey,
      appBar: AppBar(
        title: Text(deb.nom,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: Colors.white)),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        actions: [
          _IconBtn(icon: Icons.refresh, onTap: _loadData),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Carte résumé
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(children: [
              Row(children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: _aColor(deb.nom).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                      child: Text(_ini(deb.nom),
                          style: TextStyle(
                              color: _aColor(deb.nom),
                              fontSize: 20,
                              fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(deb.nom,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _textDark)),
                        if (deb.telephone != null)
                          Row(children: [
                            const Icon(Icons.phone_outlined,
                                size: 13, color: _textMuted),
                            const SizedBox(width: 4),
                            Text(deb.telephone!,
                                style: const TextStyle(
                                    fontSize: 13, color: _textMuted)),
                          ]),
                        if (deb.quartier != null)
                          Row(children: [
                            const Icon(Icons.location_on_outlined,
                                size: 13, color: _textMuted),
                            const SizedBox(width: 4),
                            Text(deb.quartier!,
                                style: const TextStyle(
                                    fontSize: 13, color: _textMuted)),
                          ]),
                      ]),
                ),
              ]),
              const SizedBox(height: 14),
              const Divider(color: _greyMid),
              const SizedBox(height: 10),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Solde total dû :',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    Text(_f(deb.soldeTotal),
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: deb.soldeTotal > 0 ? _red : _green)),
                  ]),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                    value: deb.pctTotal,
                    minHeight: 8,
                    backgroundColor: _greyMid,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(_green)),
              ),
              const SizedBox(height: 6),
              Text(
                  'Taux de remboursement : ${(deb.pctTotal * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: _textMuted)),
            ]),
          ),

          const SizedBox(height: 20),

          Row(children: [
            const Text('📋  Dettes',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textDark)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('${deb.dettes.length} dette(s)',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _green)),
            ),
          ]),
          const SizedBox(height: 10),

          ...deb.dettes.map((dette) {
            final produits = _produitsParDette[dette.id] ?? [];
            final paiements =
                _tousPaiements.where((p) => p.detteId == dette.id).toList();

            return Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: dette.enRetard
                        ? _red.withValues(alpha: 0.3)
                        : _greyMid,
                    width: dette.enRetard ? 1.5 : 0.5),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2))
                ],
              ),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: BoxDecoration(
                        color: _cfg(dette).bg.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16)),
                      ),
                      child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      'Montant : ${_f(dette.montantInitial)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: _textDark)),
                                  Text('Solde : ${_f(dette.solde)}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: dette.solde > 0
                                              ? _red
                                              : _green,
                                          fontWeight: FontWeight.w600)),
                                ]),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                  color: _cfg(dette).bg,
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: _cfg(dette)
                                          .color
                                          .withValues(alpha: 0.3))),
                              child: Text(
                                  '${_cfg(dette).emoji} ${_cfg(dette).label}',
                                  style: TextStyle(
                                      color: _cfg(dette).color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ]),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: dette.pct,
                                minHeight: 7,
                                backgroundColor: _greyMid,
                                valueColor:
                                    const AlwaysStoppedAnimation<Color>(
                                        _green),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                                'Remboursé : ${_f(dette.montantRembourse)} / ${_f(dette.montantInitial)}',
                                style: const TextStyle(
                                    fontSize: 12, color: _textMuted)),
                            const SizedBox(height: 8),
                            Row(children: [
                              const Icon(Icons.calendar_today,
                                  size: 13, color: _textMuted),
                              const SizedBox(width: 5),
                              Text('Début : ${fmt.format(dette.createdAt)}',
                                  style: const TextStyle(
                                      fontSize: 12, color: _textMuted)),
                            ]),
                            if (dette.echeance != null) ...[
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.event,
                                    size: 13,
                                    color: dette.enRetard
                                        ? _red
                                        : _textMuted),
                                const SizedBox(width: 5),
                                Text(
                                    'Échéance : ${fmt.format(dette.echeance!)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: dette.enRetard
                                            ? _red
                                            : _textMuted,
                                        fontWeight: dette.enRetard
                                            ? FontWeight.w700
                                            : FontWeight.normal)),
                                if (dette.enRetard) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: _redLight,
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                    child: const Text('EN RETARD',
                                        style: TextStyle(
                                            fontSize: 9,
                                            color: _red,
                                            fontWeight:
                                                FontWeight.w800)),
                                  ),
                                ],
                              ]),
                            ],

                            const SizedBox(height: 14),
                            const Divider(color: _greyMid, height: 0),
                            const SizedBox(height: 12),

                            // ===== PRODUITS =====
                            Row(children: [
                              const Text('🛒 Produits',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _textDark)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: produits.isNotEmpty
                                        ? _greenLight
                                        : _grey,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: Text('${produits.length}',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: produits.isNotEmpty
                                            ? _green
                                            : _textMuted)),
                              ),
                            ]),
                            const SizedBox(height: 8),

                            if (produits.isEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                decoration: BoxDecoration(
                                    color: _grey,
                                    borderRadius:
                                        BorderRadius.circular(8)),
                                child: const Row(children: [
                                  Icon(Icons.info_outline,
                                      size: 14, color: _textMuted),
                                  SizedBox(width: 6),
                                  Text(' Aucun produit associé à cette dette',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: _textMuted,
                                          fontStyle: FontStyle.italic)),
                                ]),
                              )
                            else
                              ...produits.map((prod) => Container(
                                    margin:
                                        const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: _greenLight
                                          .withValues(alpha: 0.4),
                                      borderRadius:
                                          BorderRadius.circular(10),
                                      border:
                                          Border.all(color: _greyMid),
                                    ),
                                    child: Row(children: [
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                              color: _greyMid),
                                        ),
                                        child: (prod.imageUrl != null &&
                                                prod.imageUrl!.isNotEmpty)
                                            ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        8),
                                                child: Image.network(
                                                  prod.imageUrl!,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder: (_, c,
                                                          p) =>
                                                      p == null
                                                          ? c
                                                          : const Center(
                                                              child: SizedBox(
                                                                  width: 18,
                                                                  height: 18,
                                                                  child: CircularProgressIndicator(
                                                                      strokeWidth:
                                                                          2,
                                                                      color:
                                                                          _green))),
                                                  errorBuilder: (_, __,
                                                          ___) =>
                                                      const Icon(
                                                          Icons
                                                              .shopping_bag,
                                                          size: 24,
                                                          color: _green),
                                                ),
                                              )
                                            : const Icon(Icons.shopping_bag,
                                                size: 24, color: _green),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(prod.productName,
                                                  style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _textDark)),
                                              const SizedBox(height: 2),
                                              Text(
                                                  '${prod.quantite} × ${_f(prod.prixUnitaire)}',
                                                  style: const TextStyle(
                                                      fontSize: 12,
                                                      color: _textMuted)),
                                            ]),
                                      ),
                                      Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Text(
                                              _f(prod.quantite *
                                                  prod.prixUnitaire),
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.w800,
                                                  color: _green),
                                            ),
                                            const Text('total',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    color: _textMuted)),
                                          ]),
                                    ]),
                                  )),

                            // ===== PAIEMENTS =====
                            if (paiements.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              const Divider(color: _greyMid, height: 0),
                              const SizedBox(height: 12),
                              const Text('💳 Paiements reçus',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: _textDark)),
                              const SizedBox(height: 8),
                              ...paiements.map((p) => Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 6),
                                    child: Row(children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: const BoxDecoration(
                                            color: _greenLight,
                                            shape: BoxShape.circle),
                                        child: const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                            color: _green),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                            '${fmt.format(p.date)} · ${p.modePaiement}',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: _textMuted)),
                                      ),
                                      Text('+${_f(p.montant)}',
                                          style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: _green)),
                                    ]),
                                  )),
                            ],

                            if (dette.solde == 0) ...[
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                    color: _greenLight,
                                    borderRadius:
                                        BorderRadius.circular(10)),
                                child: const Row(children: [
                                  Icon(Icons.check_circle,
                                      color: _green, size: 18),
                                  SizedBox(width: 8),
                                  Text('Dette entièrement soldée ✅',
                                      style: TextStyle(
                                          color: _green,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13)),
                                ]),
                              ),
                            ],
                          ]),
                    ),
                  ]),
            );
          }),

          const SizedBox(height: 10),

          if (deb.soldeTotal > 0)
            ElevatedButton.icon(
              onPressed: _ouvrirPaiement,
              icon: const Icon(Icons.payment, color: Colors.white),
              label: Text('Rembourser le solde · ${_f(deb.soldeTotal)} restant',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 2,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _green.withValues(alpha: 0.3))),
              child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: _green, size: 20),
                    SizedBox(width: 8),
                    Text('Aucune dette impayée ✅',
                        style: TextStyle(
                            color: _green,
                            fontWeight: FontWeight.w700,
                            fontSize: 14)),
                  ]),
            ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ========== AUTRES WIDGETS RÉUTILISABLES (inchangés) ==========
class _Modal extends StatelessWidget {
  final String title;
  final Widget child;
  const _Modal({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24), topRight: Radius.circular(24)),
      ),
      padding: const EdgeInsets.only(top: 14, left: 20, right: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: _greyMid,
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(title,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _textDark)),
          ),
          const SizedBox(height: 20),
          Flexible(child: SingleChildScrollView(child: child)),
          SizedBox(
              height: MediaQuery.of(context).viewInsets.bottom + 20),
        ],
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  final String label, hint;
  final TextEditingController ctrl;
  final IconData icon;
  final TextInputType type;
  final List<TextInputFormatter>? fmt;
  const _Champ({
    required this.label,
    required this.hint,
    required this.ctrl,
    required this.icon,
    this.type = TextInputType.text,
    this.fmt,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _textMuted)),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl,
            keyboardType: type,
            inputFormatters: fmt,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle:
                  const TextStyle(color: _textMuted, fontSize: 13),
              prefixIcon: Icon(icon, color: _green, size: 20),
              filled: true,
              fillColor: _grey,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 13),
            ),
          ),
        ],
      );
}

class _Btn extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;
  const _Btn(
      {required this.label, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: loading ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
        ),
      );
}

class _MiniStat extends StatelessWidget {
  final String label, valeur;
  final IconData icon;
  final Color couleur;
  const _MiniStat(this.label, this.valeur, this.icon, this.couleur);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.13),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            Icon(icon, color: Colors.white70, size: 18),
            const SizedBox(height: 5),
            Text(valeur,
                style: TextStyle(
                    color: couleur,
                    fontSize: 12,
                    fontWeight: FontWeight.w900),
                textAlign: TextAlign.center),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 9,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ]),
        ),
      );
}

class _SecTitle extends StatelessWidget {
  final String text;
  const _SecTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 14, fontWeight: FontWeight.w800, color: _textDark));
}

class _StatBig extends StatelessWidget {
  final String label, valeur;
  final Color couleur, bg;
  const _StatBig(this.label, this.valeur, this.couleur, this.bg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: couleur.withValues(alpha: 0.3))),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: couleur)),
          const SizedBox(height: 6),
          Text(valeur,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: couleur)),
        ]),
      );
}