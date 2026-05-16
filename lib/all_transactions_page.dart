import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dettes.dart';
import 'page_ventes.dart';
import 'creanciers_page.dart';
import 'fournisseurs_page.dart';
import 'depenses_page.dart';

const Color _kEmerald      = Color(0xFF0A5C47);
const Color _kEmeraldMid   = Color(0xFF0D7A5F);
const Color _kEmeraldFaint = Color(0xFFE8F5F0);
const Color _kCoral        = Color(0xFFCC3B3B);
const Color _kCoralLight   = Color(0xFFFFF0F0);
const Color _kGold         = Color(0xFFD4940A);
const Color _kGoldLight    = Color(0xFFFFF0C2);
const Color _kSlate        = Color(0xFF6B7A72);
const Color _kFog          = Color(0xFFF3F6F4);
const Color _kWhite        = Colors.white;
const Color _kSapphire     = Color(0xFF1A5FA8);

class AllTransactionsPage extends StatefulWidget {
  final int commercantId;
  const AllTransactionsPage({super.key, required this.commercantId});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _allTransactions = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _filtering = false;
  String _periode = 'mois';
  DateTime _selectedDate = DateTime.now();
  String _recherche = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _chargerToutesTransactions();
    _searchCtrl.addListener(() {
      _recherche = _searchCtrl.text;
      _appliquerFiltres();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime(2000);
    if (value is DateTime) return value;
    final parsed = DateTime.tryParse(value.toString());
    return parsed ?? DateTime(2000);
  }

  Future<void> _chargerToutesTransactions() async {
    setState(() => _loading = true);
    try {
      List<Map<String, dynamic>> all = [];

      // 1. Ventes (hors crédit) - sans limit
      final ventes = await _supabase
          .from('ventes')
          .select('id, date_vente, nom_client, total_montant, statut_paiement')
          .eq('commercant_id', widget.commercantId)
          .neq('statut_paiement', 'À crédit')
          .order('date_vente', ascending: false);

      final ventesIds = ventes.map<int>((v) => v['id'] as int).toList();
      Map<int, Map<String, dynamic>> ventesProduits = {};
      if (ventesIds.isNotEmpty) {
        final items = await _supabase
            .from('ventes_items')
            .select('vente_id, nom_produit, image_url')
            .inFilter('vente_id', ventesIds);
        for (var item in items) {
          final vId = item['vente_id'] as int;
          if (!ventesProduits.containsKey(vId)) {
            ventesProduits[vId] = {
              'nom_produit': item['nom_produit'],
              'image_url': item['image_url']
            };
          }
        }
      }

      for (final v in ventes) {
        final produitInfo = ventesProduits[v['id']];
        all.add({
          'source': 'vente',
          'label': v['nom_client'] ?? '',
          'produit': produitInfo?['nom_produit'] ?? 'Vente',
          'montant': (v['total_montant'] ?? 0).toDouble(),
          'photo_url': produitInfo?['image_url'],
          'date': v['date_vente'],
          'id_ref': v['id'],
          'icone': '💵',
          'couleur': _kEmeraldMid,
        });
      }

      // 2. Dettes clients (montant initial) - sans limit
      final dettes = await _supabase
          .from('dettes')
          .select('id, created_at, nom_debiteur, montant_initial, debiteur_id')
          .eq('commercant_id', widget.commercantId)
          .order('created_at', ascending: false);

      final dettesIds = dettes.map<int>((d) => d['id'] as int).toList();
      Map<int, String?> imagesDette = {};
      if (dettesIds.isNotEmpty) {
        final items = await _supabase
            .from('dette_produits')
            .select('dette_id, image_url')
            .inFilter('dette_id', dettesIds);
        for (var item in items) {
          imagesDette[item['dette_id'] as int] = item['image_url'] as String?;
        }
      }

      for (final d in dettes) {
        all.add({
          'source': 'dette',
          'label': d['nom_debiteur'] ?? '',
          'produit': 'Dette client',
          'montant': (d['montant_initial'] ?? 0).toDouble(),
          'photo_url': imagesDette[d['id']],
          'date': d['created_at'],
          'id_ref': d['id'],
          'debiteur_id': d['debiteur_id'],
          'icone': '📝',
          'couleur': _kGold,
        });
      }

      // 3. Paiements clients (remboursements) - sans limit
      final paiements = await _supabase
          .from('paiements')
          .select('id, date, montant, dette_id, dettes(nom_debiteur, debiteur_id)')
          .eq('commercant_id', widget.commercantId)
          .order('date', ascending: false);

      final dettesIdPaiement = paiements.map<int>((p) => p['dette_id'] as int).toSet().toList();
      Map<int, String?> imageParDette = {};
      if (dettesIdPaiement.isNotEmpty) {
        final produits = await _supabase
            .from('dette_produits')
            .select('dette_id, image_url')
            .inFilter('dette_id', dettesIdPaiement);
        for (var prod in produits) {
          imageParDette[prod['dette_id'] as int] = prod['image_url'] as String?;
        }
      }

      for (final p in paiements) {
        final detteInfo = p['dettes'] as Map?;
        final nomDebiteur = detteInfo?['nom_debiteur'] ?? 'Client';
        final detteId = p['dette_id'] as int;
        all.add({
          'source': 'paiement_client',
          'label': nomDebiteur,
          'produit': 'Remboursement reçu',
          'montant': (p['montant'] ?? 0).toDouble(),
          'photo_url': imageParDette[detteId],
          'date': p['date'],
          'id_ref': p['id'],
          'debiteur_id': detteInfo?['debiteur_id'],
          'icone': '💳',
          'couleur': _kSapphire,
        });
      }

      // 4. Paiements créanciers - sans limit
      final paiementsCreanciers = await _supabase
          .from('depenses')
          .select('id, date_depense, montant, libelle, creanciers(nom)')
          .eq('commercant_id', widget.commercantId)
          .eq('type', 'remboursement_creancier')
          .order('date_depense', ascending: false);

      for (final d in paiementsCreanciers) {
        final creancierNom = (d['creanciers'] as Map?)?['nom'] ?? 'Créancier';
        all.add({
          'source': 'paiement_creancier',
          'label': creancierNom,
          'produit': d['libelle'] ?? 'Remboursement',
          'montant': (d['montant'] ?? 0).toDouble(),
          'photo_url': null,
          'date': d['date_depense'],
          'id_ref': d['id'],
          'icone': '🤝',
          'couleur': _kCoral,
        });
      }

      // 5. Autres dépenses - sans limit
      final autresDepenses = await _supabase
          .from('depenses')
          .select('id, date_depense, montant, libelle, type, categorie')
          .eq('commercant_id', widget.commercantId)
          .inFilter('type', ['achat_fournisseur', 'divers'])
          .order('date_depense', ascending: false);

      for (final d in autresDepenses) {
        final type = d['type'];
        String label = type == 'achat_fournisseur' ? 'Fournisseur' : (d['categorie'] ?? 'Divers');
        String produit = d['libelle'] ?? (type == 'achat_fournisseur' ? 'Achat' : 'Dépense');
        String icone = type == 'achat_fournisseur' ? '🛒' : '📉';
        Color couleur = type == 'achat_fournisseur' ? _kGold : _kSlate;
        all.add({
          'source': 'depense',
          'label': label,
          'produit': produit,
          'montant': (d['montant'] ?? 0).toDouble(),
          'photo_url': null,
          'date': d['date_depense'],
          'id_ref': d['id'],
          'icone': icone,
          'couleur': couleur,
        });
      }

      // Tri global descendant (plus récent en premier)
      all.sort((a, b) {
        final da = _parseDate(a['date']);
        final db = _parseDate(b['date']);
        return db.compareTo(da);
      });

      setState(() {
        _allTransactions = all;
        _appliquerFiltres();
        _loading = false;
      });
    } catch (e) {
      debugPrint('Erreur chargement transactions : $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: _kCoral),
        );
      }
      setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  // Filtres
  // ─────────────────────────────────────────
  Future<void> _appliquerFiltres() async {
    if (_filtering) return;
    setState(() => _filtering = true);
    try {
      final periodFiltered = _allTransactions.where((tx) {
        final dateStr = tx['date'] as String?;
        if (dateStr == null) return false;
        final DateTime txDate = _parseDate(dateStr);
        DateTime start, end;
        final now = _selectedDate;
        if (_periode == 'jour') {
          start = DateTime(now.year, now.month, now.day);
          end = start.add(const Duration(days: 1));
        } else if (_periode == 'semaine') {
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          start = DateTime(weekStart.year, weekStart.month, weekStart.day);
          end = start.add(const Duration(days: 7));
        } else if (_periode == 'mois') {
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 1);
        } else {
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year + 1, 1, 1);
        }
        return txDate.isAfter(start.subtract(const Duration(days: 1))) && txDate.isBefore(end);
      }).toList();

      final query = _recherche.toLowerCase();
      setState(() {
        _filtered = periodFiltered.where((tx) {
          final label = (tx['label'] as String).toLowerCase();
          final produit = (tx['produit'] as String).toLowerCase();
          return label.contains(query) || produit.contains(query);
        }).toList();
      });
    } finally {
      if (mounted) setState(() => _filtering = false);
    }
  }

  void _changerPeriode(String nouvellePeriode) {
    setState(() => _periode = nouvellePeriode);
    _appliquerFiltres();
  }

  Future<void> _changerDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
      _appliquerFiltres();
    }
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Toutes les transactions'),
        backgroundColor: _kEmerald,
        foregroundColor: _kWhite,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (client, produit…)',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _kEmerald))
          : Column(
              children: [
                _buildPeriodFilter(),
                Expanded(
                  child: _filtering
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? const Center(child: Text('Aucune transaction pour cette période'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) => _TransactionCard(
                                tx: _filtered[i],
                                fmt: _fmt,
                                onTap: () => _naviguerVersDetail(_filtered[i]),
                              ),
                            ),
                ),
              ],
            ),
    );
  }

  Widget _buildPeriodFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kWhite,
        boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 2)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _filterChip('Jour', 'jour'),
          _filterChip('Semaine', 'semaine'),
          _filterChip('Mois', 'mois'),
          _filterChip('Année', 'annee'),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _changerDate,
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _periode == value,
      onSelected: (sel) {
        if (sel) _changerPeriode(value);
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: _kEmerald.withOpacity(0.2),
    );
  }

  void _naviguerVersDetail(Map<String, dynamic> tx) {
    final source = tx['source'];
    if (source == 'vente') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => VentesPage(commercantId: widget.commercantId)));
    } else if (source == 'dette' || source == 'paiement_client') {
      final debiteurId = tx['debiteur_id'];
      Navigator.push(context, MaterialPageRoute(builder: (_) => DettesPage(
        commercantId: widget.commercantId,
        selectedDebiteurId: debiteurId,
      )));
    } else if (source == 'paiement_creancier') {
      final id = tx['id_ref'];
      Navigator.push(context, MaterialPageRoute(builder: (_) => CreanciersPage(
        commercantId: widget.commercantId,
        selectedCreancierId: id,
      )));
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DepensesPage(commercantId: widget.commercantId)));
    }
  }
}

class _TransactionCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final String Function(double) fmt;
  final VoidCallback onTap;
  const _TransactionCard({required this.tx, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final label = tx['label'] ?? '';
    final produit = tx['produit'] ?? '';
    final montant = (tx['montant'] as num).toDouble();
    final photoUrl = tx['photo_url'];
    final icone = tx['icone'] ?? '📄';
    final couleur = tx['couleur'] ?? _kSlate;
    final source = tx['source'] ?? '';

    String signe = '';
    if (source == 'vente' || source == 'paiement_client') {
      signe = '+';
    } else if (source == 'paiement_creancier' || source == 'depense') {
      signe = '-';
    }

    String badgeTexte = '';
    Color badgeBg = _kEmeraldFaint;
    Color badgeClr = _kEmeraldMid;

    switch (source) {
      case 'vente':
        badgeTexte = 'Vente';
        break;
      case 'dette':
        badgeTexte = 'Dette';
        badgeBg = _kGoldLight;
        badgeClr = _kGold;
        break;
      case 'paiement_client':
        badgeTexte = 'Remboursement';
        badgeBg = const Color(0xFFEBF3FF);
        badgeClr = _kSapphire;
        break;
      case 'paiement_creancier':
        badgeTexte = 'Paiement créancier';
        badgeBg = _kCoralLight;
        badgeClr = _kCoral;
        break;
      case 'depense':
        badgeTexte = 'Dépense';
        badgeBg = _kFog;
        badgeClr = _kSlate;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.shade300, blurRadius: 4, offset: const Offset(0, 2))],
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
              child: Center(
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(photoUrl, width: 46, height: 46, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(icone, style: const TextStyle(fontSize: 24))),
                      )
                    : Text(icone, style: const TextStyle(fontSize: 24)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (label.isNotEmpty)
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  Text(produit, style: const TextStyle(fontSize: 12, color: _kSlate)),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                    child: Text(badgeTexte, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeClr)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('$signe${fmt(montant)} F',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: couleur)),
                const SizedBox(height: 6),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: _kEmeraldFaint, borderRadius: BorderRadius.circular(8)),
                  child: const Center(child: Icon(Icons.chevron_right, size: 18, color: _kEmeraldMid)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}