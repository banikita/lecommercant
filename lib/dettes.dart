import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'page_stock.dart';

class PageDette extends StatefulWidget {
  final int commercantId;
  const PageDette({super.key, required this.commercantId});

  @override
  State<PageDette> createState() => _PageDetteState();
}

class _PageDetteState extends State<PageDette> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _dettes = [];
  List<Map<String, dynamic>> _dettesFiltrees = [];
  bool _loading = true;

  String _recherche = '';
  String _filtreStatut = 'tous';
  final _searchCtrl = TextEditingController();

  static const _green = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red = Color(0xFFA32D2D);
  static const _redLight = Color(0xFFFCEBEB);

  @override
  void initState() {
    super.initState();
    _chargerDettes();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerDettes() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final data = await supabase
          .from('dettes')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('created_at', ascending: false);

      // Grouper par débiteur
      final Map<String, Map<String, dynamic>> parDebiteur = {};
      for (final d in List<Map<String, dynamic>>.from(data)) {
        final nom = d['nom_debiteur'] as String? ?? '';
        if (!parDebiteur.containsKey(nom)) {
          parDebiteur[nom] = Map<String, dynamic>.from(d);
          parDebiteur[nom]!['_total_du'] = 0.0;
        }
        final double ini = (d['montant_initial'] ?? 0).toDouble();
        final double rem = (d['montant_rembourse'] ?? 0).toDouble();
        parDebiteur[nom]!['_total_du'] =
            ((parDebiteur[nom]!['_total_du'] as double)) +
                (ini - rem).clamp(0.0, double.infinity);
      }

      final liste = parDebiteur.values
          .where((d) => (d['_total_du'] as double) > 0)
          .toList();

      setState(() {
        _dettes = liste;
        _appliquerFiltres();
        _loading = false;
      });
    } catch (e) {
      debugPrint("Erreur: $e");
      setState(() => _loading = false);
    }
  }

  void _appliquerFiltres() {
    List<Map<String, dynamic>> result = List.from(_dettes);

    if (_recherche.isNotEmpty) {
      final q = _recherche.toLowerCase();
      result = result.where((d) {
        final nom = (d['nom_debiteur'] ?? '').toString().toLowerCase();
        final tel = (d['telephone'] ?? '').toString().toLowerCase();
        final prod = (d['produits_details'] ?? '').toString().toLowerCase();
        return nom.contains(q) || tel.contains(q) || prod.contains(q);
      }).toList();
    }

    if (_filtreStatut == 'retard') {
      result = result.where((d) {
        return d['date_echeance'] != null &&
            DateTime.tryParse(d['date_echeance'])
                    ?.isBefore(DateTime.now()) ==
                true;
      }).toList();
    }

    result.sort((a, b) => ((b['_total_du'] ?? 0.0) as double)
        .compareTo((a['_total_du'] ?? 0.0) as double));

    setState(() => _dettesFiltrees = result);
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final double totalGlobal = _dettes.fold(
        0.0, (s, d) => s + ((d['_total_du'] ?? 0.0) as double));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F2),
      appBar: AppBar(
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Cahier de Dettes',
            style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(onPressed: _chargerDettes, icon: const Icon(Icons.refresh))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _modalAjout,
        backgroundColor: Colors.orange,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text('Nouvelle dette',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(children: [
        _buildBandeauTotal(totalGlobal),
        _buildBarreRecherche(),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _green))
              : RefreshIndicator(
                  onRefresh: _chargerDettes,
                  color: _green,
                  child: _dettesFiltrees.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _dettesFiltrees.length,
                          itemBuilder: (_, i) =>
                              _buildCarteDebiteur(_dettesFiltrees[i]),
                        ),
                ),
        ),
      ]),
    );
  }

  Widget _buildBandeauTotal(double total) {
    return Container(
      color: _green,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.13),
            borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('💸 Total impayé',
                style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text('${_fmt(total)} F CFA',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900)),
          ]),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20)),
            child: Text('${_dettesFiltrees.length} débiteurs',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }

  Widget _buildBarreRecherche() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(children: [
        TextField(
          controller: _searchCtrl,
          onChanged: (v) {
            setState(() => _recherche = v);
            _appliquerFiltres();
          },
          decoration: InputDecoration(
            hintText: '🔍  Chercher un client...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: _green),
            suffixIcon: _recherche.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _recherche = '');
                      _appliquerFiltres();
                    })
                : null,
            filled: true,
            fillColor: const Color(0xFFF4F4F2),
            contentPadding: const EdgeInsets.symmetric(vertical: 0),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          _filtreBtn('tous', '📋', 'Tous'),
          const SizedBox(width: 8),
          _filtreBtn('impaye', '⏳', 'Impayés'),
          const SizedBox(width: 8),
          _filtreBtn('retard', '🚨', 'En retard'),
        ]),
      ]),
    );
  }

  Widget _filtreBtn(String key, String emoji, String label) {
    final bool sel = _filtreStatut == key;
    return GestureDetector(
      onTap: () {
        setState(() => _filtreStatut = key);
        _appliquerFiltres();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: sel ? _green : const Color(0xFFF4F4F2),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: sel ? _green : Colors.grey.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : Colors.grey[700])),
        ]),
      ),
    );
  }

  Widget _buildCarteDebiteur(Map<String, dynamic> d) {
    final double totalDu = (d['_total_du'] ?? 0.0) as double;
    final String? photoUrl = d['photo_url'] as String?;
    final String nom = d['nom_debiteur'] as String? ?? '?';
    final bool enRetard = d['date_echeance'] != null &&
        DateTime.tryParse(d['date_echeance'])?.isBefore(DateTime.now()) == true;

    return GestureDetector(
      onTap: () => _voirHistorique(d),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: enRetard
                  ? Colors.red.withOpacity(0.4)
                  : Colors.grey.withOpacity(0.12),
              width: enRetard ? 1.5 : 0.5),
        ),
        child: Row(children: [
          Stack(children: [
            photoUrl != null && photoUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(30),
                    child: Image.network(photoUrl,
                        width: 60, height: 60, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            _avatarInitiales(nom, enRetard)),
                  )
                : _avatarInitiales(nom, enRetard),
            if (enRetard)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                        color: Colors.red, shape: BoxShape.circle),
                    child: const Center(
                        child: Text('!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)))),
              ),
          ]),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(nom,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A1A))),
                if (d['telephone'] != null)
                  Text(d['telephone'].toString(),
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                const SizedBox(height: 6),
                if (d['produits_details'] != null &&
                    d['produits_details'].toString().isNotEmpty)
                  Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: d['produits_details']
                          .toString()
                          .split(',')
                          .take(2)
                          .map((p) => Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFF4F4F2),
                                    borderRadius: BorderRadius.circular(8)),
                                child: Text(p.trim(),
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF6B7280)),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ))
                          .toList()),
                if (enRetard) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _redLight, borderRadius: BorderRadius.circular(8)),
                    child: const Text('🚨 Échéance dépassée',
                        style: TextStyle(fontSize: 10, color: _red, fontWeight: FontWeight.w700)),
                  ),
                ],
              ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_fmt(totalDu)} F',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: enRetard ? _red : _green)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                  color: _greenLight, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Voir',
                    style: TextStyle(
                        fontSize: 11,
                        color: _green,
                        fontWeight: FontWeight.w700)),
                SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 14, color: _green),
              ]),
            ),
          ]),
        ]),
      ),
    );
  }

  Widget _avatarInitiales(String nom, bool enRetard) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
          color: enRetard ? _redLight : _greenLight,
          shape: BoxShape.circle),
      child: Center(
          child: Text(
        nom.isNotEmpty ? nom[0].toUpperCase() : '?',
        style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: enRetard ? _red : _green),
      )),
    );
  }

  Widget _buildEmptyState() {
    return ListView(children: [
      SizedBox(height: MediaQuery.of(context).size.height * 0.25),
      const Center(
          child: Column(children: [
        Text('✅', style: TextStyle(fontSize: 64)),
        SizedBox(height: 12),
        Text('Aucune dette en cours !',
            style: TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w600)),
        SizedBox(height: 6),
        Text('Tous vos clients sont à jour 🎉',
            style: TextStyle(color: Colors.grey, fontSize: 13)),
      ])),
    ]);
  }

  void _voirHistorique(Map<String, dynamic> debiteur) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _PageHistoriqueDebiteur(
          commercantId: widget.commercantId,
          debiteur: debiteur,
          onPaiement: _modalPaiement,
          onSMS: _envoyerSMS,
          onRefresh: _chargerDettes,
        ),
      ),
    );
  }

  void _envoyerSMS(Map<String, dynamic> d) async {
    final double reste = (d['_total_du'] ?? 0.0) as double;
    final String msg =
        "Bonjour ${d['nom_debiteur']}, il reste ${_fmt(reste)} F a regler. Merci.";
    final Uri url =
        Uri.parse("sms:${d['telephone']}?body=${Uri.encodeComponent(msg)}");
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _modalAjout() {
    final nomCtrl = TextEditingController();
    final telCtrl = TextEditingController();
    final montantCtrl = TextEditingController();
    List<Map<String, dynamic>> produitsSelectionnes = [];
    DateTime? echeance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Center(
                    child: Container(
                        width: 50,
                        height: 5,
                        decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 16),
                const Text('NOUVELLE DETTE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _inputField(nomCtrl, 'Nom du client', Icons.person),
                const SizedBox(height: 10),
                _inputField(telCtrl, 'Téléphone (77...)', Icons.phone, isPhone: true),
                const SizedBox(height: 16),

                if (produitsSelectionnes.isNotEmpty) ...[
                  _buildGrilleProduits(produitsSelectionnes, (i) {
                    setM(() {
                      produitsSelectionnes.removeAt(i);
                      double t = produitsSelectionnes.fold(0.0,
                          (s, p) => s + (p['prix'] as double) * (p['quantite'] as int));
                      montantCtrl.text = t > 0 ? t.toStringAsFixed(0) : '';
                    });
                  }),
                  const SizedBox(height: 12),
                ],

                GestureDetector(
                  onTap: () async {
                    FocusScope.of(ctx).unfocus();
                    final result = await Navigator.push<List<Map<String, dynamic>>>(
                        ctx,
                        MaterialPageRoute(
                            builder: (_) => const StockPage(isSelectionMode: true)));
                    if (result != null && result.isNotEmpty) {
                      setM(() {
                        for (final n in result) {
                          final idx = produitsSelectionnes
                              .indexWhere((p) => p['nom'] == n['nom']);
                          if (idx >= 0) {
                            produitsSelectionnes[idx]['quantite'] =
                                (produitsSelectionnes[idx]['quantite'] as int) +
                                    (n['quantite'] as int);
                          } else {
                            produitsSelectionnes.add(n);
                          }
                        }
                        double t = produitsSelectionnes.fold(0.0,
                            (s, p) => s + (p['prix'] as double) * (p['quantite'] as int));
                        montantCtrl.text = t.toStringAsFixed(0);
                      });
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _green.withOpacity(0.05),
                      border: Border.all(color: _green.withOpacity(0.4), width: 2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(children: [
                      const Text('🧺', style: TextStyle(fontSize: 32)),
                      const SizedBox(height: 6),
                      Text(
                        produitsSelectionnes.isEmpty
                            ? 'Choisir les produits dans le stock'
                            : 'Ajouter d\'autres produits',
                        style: const TextStyle(
                            color: _green, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: montantCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(
                      fontSize: 24, color: _red, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    labelText: 'Montant total (F CFA)',
                    prefixIcon: const Icon(Icons.money, color: _red),
                    suffix: const Text('F CFA',
                        style: TextStyle(color: _red, fontWeight: FontWeight.bold)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Text('📅', style: TextStyle(fontSize: 24)),
                  title: Text(
                      echeance == null
                          ? 'Fixer une échéance (optionnel)'
                          : 'Échéance : ${DateFormat('dd/MM/yyyy').format(echeance!)}',
                      style: const TextStyle(fontSize: 14)),
                  onTap: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2030));
                    if (d != null) setM(() => echeance = d);
                  },
                ),
                const SizedBox(height: 20),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      minimumSize: const Size(double.infinity, 58),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                  onPressed: () async {
                    if (nomCtrl.text.isEmpty || montantCtrl.text.isEmpty) return;
                    final prodDetails = produitsSelectionnes
                        .map((p) => "${p['quantite']}x ${p['nom']}")
                        .join(', ');
                    try {
                      await supabase.from('dettes').insert({
                        'commercant_id': widget.commercantId,
                        'nom_debiteur': nomCtrl.text.trim(),
                        'telephone': telCtrl.text.trim(),
                        'montant_initial': double.parse(montantCtrl.text),
                        'produits_details': prodDetails.isEmpty ? null : prodDetails,
                        'date_echeance': echeance?.toIso8601String(),
                        'statut': 'en_cours',
                        'montant_rembourse': 0,
                      });
                      Navigator.pop(ctx);
                      _chargerDettes();
                    } catch (e) {
                      debugPrint("Erreur insert: $e");
                    }
                  },
                  child: const Text('✅  ENREGISTRER LA DETTE',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 16)),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGrilleProduits(List<Map<String, dynamic>> produits, Function(int) onDel) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: _greenLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _green.withOpacity(0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${produits.length} produit(s)',
            style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.75),
          itemCount: produits.length,
          itemBuilder: (_, i) {
            final p = produits[i];
            final String? assetPath = p['image'] as String?;
            final String cat = p['category'] as String? ?? 'Autre';
            final int qty = p['quantite'] as int? ?? 1;
            final Map<String, String> catEmoji = {
              'Alimentaire': '🍞', 'Boissons': '🥤', 'Hygiène': '🧴', 'Autre': '📦'
            };
            return Stack(children: [
              Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _green.withOpacity(0.2))),
                child: Column(children: [
                  Expanded(
                      child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    child: assetPath != null
                        ? Image.asset(assetPath,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            errorBuilder: (_, __, ___) => Center(
                                child: Text(catEmoji[cat] ?? '📦',
                                    style: const TextStyle(fontSize: 24))))
                        : Center(
                            child: Text(catEmoji[cat] ?? '📦',
                                style: const TextStyle(fontSize: 24))),
                  )),
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(p['nom'] ?? '',
                        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center),
                  ),
                ]),
              ),
              Positioned(
                  top: 2,
                  right: 2,
                  child: GestureDetector(
                      onTap: () => onDel(i),
                      child: Container(
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                          child: const Icon(Icons.close, color: Colors.white, size: 12)))),
              if (qty > 1)
                Positioned(
                    bottom: 22,
                    left: 3,
                    child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(6)),
                        child: Text('×$qty',
                            style: const TextStyle(
                                color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)))),
            ]);
          },
        ),
      ]),
    );
  }

  void _modalPaiement(Map<String, dynamic> d) async {
    final dettes = await supabase
        .from('dettes')
        .select()
        .eq('commercant_id', widget.commercantId)
        .eq('nom_debiteur', d['nom_debiteur'])
        .eq('statut', 'en_cours')
        .order('created_at', ascending: false);

    if (!mounted || (dettes as List).isEmpty) return;
    final dette = Map<String, dynamic>.from(dettes.first);
    final montantCtrl = TextEditingController();
    String methode = 'Cash';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final double ini = (dette['montant_initial'] ?? 0).toDouble();
          final double rem = (dette['montant_rembourse'] ?? 0).toDouble();
          final double reste = ini - rem;
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20, right: 20, top: 20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('💰 ENCAISSEMENT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(d['nom_debiteur'],
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              Text('Reste dû : ${_fmt(reste)} F CFA',
                  style: const TextStyle(color: _red, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 20),
              Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['Cash', 'Wave', 'OM'].map((m) {
                    final icons = {'Cash': '💵', 'Wave': '🌊', 'OM': '🟠'};
                    final sel = methode == m;
                    return GestureDetector(
                      onTap: () async {
                        setM(() => methode = m);
                        if (m == 'Wave') {
                          final uri = Uri.parse('wave://');
                          if (await canLaunchUrl(uri))
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else if (m == 'OM') {
                          final uri = Uri.parse('tel:#144#');
                          if (await canLaunchUrl(uri)) await launchUrl(uri);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        decoration: BoxDecoration(
                          color: sel ? _green.withOpacity(0.1) : Colors.grey[100],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: sel ? _green : Colors.grey[300]!, width: sel ? 2 : 1),
                        ),
                        child: Column(children: [
                          Text(icons[m]!, style: const TextStyle(fontSize: 28)),
                          const SizedBox(height: 4),
                          Text(m,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                                  color: sel ? _green : Colors.grey[700])),
                        ]),
                      ),
                    );
                  }).toList()),
              const SizedBox(height: 20),
              TextField(
                controller: montantCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _green),
                decoration: InputDecoration(
                  labelText: 'Somme reçue',
                  suffixText: 'F CFA',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _green, width: 2)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    minimumSize: const Size(double.infinity, 58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                onPressed: () async {
                  if (montantCtrl.text.isEmpty) return;
                  double v = double.parse(montantCtrl.text);
                  double newRem = rem + v;
                  try {
                    await supabase.from('paiements').insert({
                      'dette_id': dette['id'],
                      'commercant_id': widget.commercantId,
                      'montant': v,
                      'methode_paiement': methode,
                    });
                    await supabase.from('dettes').update({
                      'montant_rembourse': newRem,
                      'statut': newRem >= ini ? 'termine' : 'en_cours',
                    }).eq('id', dette['id']);
                    Navigator.pop(ctx);
                    _chargerDettes();
                  } catch (e) {
                    debugPrint("Erreur paiement: $e");
                  }
                },
                child: const Text('✅  VALIDER LE PAIEMENT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
              ),
            ]),
          );
        },
      ),
    );
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon, {bool isPhone = false}) {
    return TextField(
      controller: ctrl,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: _green),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE HISTORIQUE D'UN DÉBITEUR
// ─────────────────────────────────────────────────────────────────────────────
class _PageHistoriqueDebiteur extends StatefulWidget {
  final int commercantId;
  final Map<String, dynamic> debiteur;
  final Function(Map<String, dynamic>) onPaiement;
  final Function(Map<String, dynamic>) onSMS;
  final VoidCallback onRefresh;

  const _PageHistoriqueDebiteur({
    required this.commercantId,
    required this.debiteur,
    required this.onPaiement,
    required this.onSMS,
    required this.onRefresh,
  });

  @override
  State<_PageHistoriqueDebiteur> createState() => _PageHistoriqueDebiteurState();
}

class _PageHistoriqueDebiteurState extends State<_PageHistoriqueDebiteur>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _dettes = [];
  List<Map<String, dynamic>> _paiements = [];
  bool _loading = true;
  late TabController _tabs;

  static const _green = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red = Color(0xFFA32D2D);
  static const _redLight = Color(0xFFFCEBEB);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _charger();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final nom = widget.debiteur['nom_debiteur'] as String;
      final results = await Future.wait([
        supabase
            .from('dettes')
            .select()
            .eq('commercant_id', widget.commercantId)
            .eq('nom_debiteur', nom)
            .order('created_at', ascending: false),
        supabase
            .from('paiements')
            .select()
            .eq('commercant_id', widget.commercantId)
            .order('created_at', ascending: false),
      ]);

      final dettes = results[0] as List;
      final paiements = results[1] as List;
      final idsDettes = dettes.map((d) => d['id']).toSet();

      setState(() {
        _dettes = List<Map<String, dynamic>>.from(dettes);
        _paiements = paiements
            .where((p) => idsDettes.contains(p['dette_id']))
            .cast<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _fmtDate(dynamic dt) {
    if (dt == null) return '';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dt.toString()));
    } catch (_) {
      return dt.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.debiteur;
    final double totalDu = (d['_total_du'] ?? 0.0) as double;
    final double totalPaye = _paiements.fold(
        0.0, (s, p) => s + ((p['montant'] ?? 0) as num).toDouble());
    final String? photoUrl = d['photo_url'] as String?;
    final String nom = d['nom_debiteur'] as String? ?? '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F4F2),
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            floating: false,
            backgroundColor: _green,
            foregroundColor: Colors.white,
            actions: [
              IconButton(
                  icon: const Text('💬', style: TextStyle(fontSize: 20)),
                  tooltip: 'SMS',
                  onPressed: () => widget.onSMS(d)),
              IconButton(
                  icon: const Icon(Icons.payment),
                  tooltip: 'Encaisser',
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPaiement(d);
                  }),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                    gradient: LinearGradient(
                        colors: [Color(0xFF0F6E56), Color(0xFF1D9E75)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight)),
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(36),
                      child: photoUrl != null && photoUrl.isNotEmpty
                          ? Image.network(photoUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _initAvatar(nom))
                          : _initAvatar(nom),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nom,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                    if (d['telephone'] != null)
                      Text(d['telephone'].toString(),
                          style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(children: [
                      _statBadge('Doit', '${_fmt(totalDu)} F', Colors.red[700]!, Colors.white),
                      const SizedBox(width: 8),
                      _statBadge('Payé', '${_fmt(totalPaye)} F',
                          Colors.white.withOpacity(0.2), Colors.white),
                    ]),
                  ])),
                ]),
              ),
            ),
            bottom: TabBar(
              controller: _tabs,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: '📋  Dettes'),
                Tab(text: '💳  Paiements'),
              ],
            ),
          ),
        ],
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: _green))
            : TabBarView(
                controller: _tabs,
                children: [_buildOngletDettes(), _buildOngletPaiements()],
              ),
      ),
    );
  }

  Widget _initAvatar(String nom) => Container(
      color: Colors.white24,
      child: Center(
          child: Text(nom.isNotEmpty ? nom[0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white))));

  Widget _statBadge(String label, String val, Color bg, Color textClr) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Column(children: [
          Text(label, style: TextStyle(color: textClr.withOpacity(0.7), fontSize: 10)),
          Text(val, style: TextStyle(color: textClr, fontSize: 13, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _buildOngletDettes() {
    if (_dettes.isEmpty) {
      return const Center(child: Text('Aucune dette', style: TextStyle(color: Colors.grey)));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _dettes.length,
      itemBuilder: (_, i) {
        final det = _dettes[i];
        final double ini = (det['montant_initial'] ?? 0).toDouble();
        final double rem = (det['montant_rembourse'] ?? 0).toDouble();
        final double reste = ini - rem;
        final bool solde = reste <= 0;
        final double pct = ini > 0 ? (rem / ini).clamp(0.0, 1.0) : 0.0;
        final bool enRetard = !solde &&
            det['date_echeance'] != null &&
            DateTime.tryParse(det['date_echeance'].toString())?.isBefore(DateTime.now()) == true;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: solde
                      ? Colors.green.withOpacity(0.3)
                      : enRetard
                          ? Colors.red.withOpacity(0.4)
                          : Colors.grey.withOpacity(0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_fmtDate(det['created_at']),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              _badgeStatut(solde, enRetard),
            ]),
            const SizedBox(height: 8),
            if (det['produits_details'] != null && det['produits_details'].toString().isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    const Text('🛒', style: TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(det['produits_details'].toString(),
                            style: const TextStyle(fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                  ])),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Remboursé : ${_fmt(rem)} F', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              Text('Total : ${_fmt(ini)} F', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(solde ? Colors.green : _green),
              ),
            ),
            const SizedBox(height: 6),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${(pct * 100).toStringAsFixed(0)}% payé',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500])),
              if (!solde)
                Text('Reste : ${_fmt(reste)} F',
                    style: const TextStyle(fontSize: 13, color: _red, fontWeight: FontWeight.w800)),
            ]),
            if (!solde) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: _green),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Text('💵', style: TextStyle(fontSize: 16)),
                  label: const Text('Encaisser', style: TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onPaiement(widget.debiteur);
                  },
                ),
              ),
            ],
          ]),
        );
      },
    );
  }

  Widget _badgeStatut(bool solde, bool enRetard) {
    if (solde)
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(20)),
          child: const Text('✅ Soldé',
              style: TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.w700)));
    if (enRetard)
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: _redLight, borderRadius: BorderRadius.circular(20)),
          child: const Text('🚨 En retard',
              style: TextStyle(color: _red, fontSize: 11, fontWeight: FontWeight.w700)));
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFAEEDA), borderRadius: BorderRadius.circular(20)),
        child: const Text('⏳ En cours',
            style: TextStyle(color: Color(0xFF854F0B), fontSize: 11, fontWeight: FontWeight.w700)));
  }

  Widget _buildOngletPaiements() {
    if (_paiements.isEmpty) {
      return const Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('💤', style: TextStyle(fontSize: 48)),
        SizedBox(height: 12),
        Text('Aucun paiement reçu', style: TextStyle(color: Colors.grey, fontSize: 15)),
      ]));
    }

    double totalRecu = _paiements.fold(0.0, (s, p) => s + ((p['montant'] ?? 0) as num).toDouble());

    return Column(children: [
      Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: _greenLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _green.withOpacity(0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('💰 Total reçu',
                style: TextStyle(color: _green, fontWeight: FontWeight.w700)),
            Text('${_fmt(totalRecu)} F CFA',
                style: const TextStyle(color: _green, fontSize: 18, fontWeight: FontWeight.w900)),
          ])),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: _paiements.length,
          itemBuilder: (_, i) {
            final p = _paiements[i];
            final double m = (p['montant'] ?? 0).toDouble();
            final String methode = p['methode_paiement'] ?? 'Cash';
            final Map<String, String> methEmoji = {
              'Cash': '💵', 'Wave': '🌊', 'Orange Money': '🟠', 'OM': '🟠'
            };
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withOpacity(0.1))),
              child: Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                      child: Text(methEmoji[methode] ?? '💳',
                          style: const TextStyle(fontSize: 24))),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(methode, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  Text(_fmtDate(p['created_at']),
                      style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ])),
                Text('+${_fmt(m)} F',
                    style: const TextStyle(color: _green, fontSize: 16, fontWeight: FontWeight.w900)),
              ]),
            );
          },
        ),
      ),
    ]);
  }
}