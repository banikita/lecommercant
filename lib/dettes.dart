import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:le_commercant/models/dettes_model.dart';
import 'package:le_commercant/database/dettes_database.dart';

// ══════════════════════════════════════════════════════════════
//  PAGE DETTES — Interface complète
// ══════════════════════════════════════════════════════════════

class PageDettes extends StatefulWidget {
  const PageDettes({super.key});

  @override
  State<PageDettes> createState() => _PageDettesState();
}

class _PageDettesState extends State<PageDettes>
    with SingleTickerProviderStateMixin {

  // ── Palette
  static const _red        = Color(0xFFA32D2D);
  static const _redLight   = Color(0xFFFCEBEB);
  static const _redMid     = Color(0xFFF09595);
  static const _green      = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _greenDark  = Color(0xFF27500A);
  static const _amber      = Color(0xFF854F0B);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid   = Color(0xFFEF9F27);
  static const _grey       = Color(0xFFF4F4F2);
  static const _hint       = Color(0xFF9CA3AF);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);

  final _db          = DetteDatabase.instance;
  List<Dette> _dettes = [];
  bool _isLoading    = true;
  bool _isSyncing    = false;
  String _filtreActif = 'tous';
  final _searchCtrl  = TextEditingController();

  // Contrôleurs formulaire ajout
  final _nomCtrl      = TextEditingController();
  final _telCtrl      = TextEditingController();
  final _montantCtrl  = TextEditingController();
  final _dureeCtrl    = TextEditingController();
  final _creancierCtrl = TextEditingController();
  DateTime _dateDebut = DateTime.now();

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _charger();
    _syncCloud();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _nomCtrl.dispose(); _telCtrl.dispose();
    _montantCtrl.dispose(); _dureeCtrl.dispose();
    _creancierCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  //  DONNÉES
  // ══════════════════════════════════════
  Future<void> _charger() async {
    setState(() => _isLoading = true);
    final dettes = await _db.chargerDettes();
    setState(() { _dettes = dettes; _isLoading = false; });
  }

  Future<void> _syncCloud() async {
    setState(() => _isSyncing = true);
    await _db.synchroniserAvecCloud();
    await _charger();
    setState(() => _isSyncing = false);
  }

  // ── Filtrage
  List<Dette> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _dettes.where((d) {
      final mq = d.nomDebiteur.toLowerCase().contains(q) ||
          d.telephone.contains(q);
      final mf = _filtreActif == 'tous' ||
          (_filtreActif == 'en_cours' && d.statutCalcule == 'en_cours') ||
          (_filtreActif == 'en_retard' && d.statutCalcule == 'en_retard') ||
          (_filtreActif == 'rembourse' && d.statutCalcule == 'rembourse');
      return mq && mf;
    }).toList();
  }

  // ── Statistiques
  double get _totalDu     => _dettes.where((d) => !d.estRembourse)
      .fold(0.0, (a, d) => a + d.montantRestant);
  int get _nbEnRetard     => _dettes.where((d) => d.estEchu).length;
  int get _nbRembourse    => _dettes.where((d) => d.estRembourse).length;

  // ══════════════════════════════════════
  //  ACTIONS
  // ══════════════════════════════════════

  Future<void> _ajouterDette() async {
    final nom     = _nomCtrl.text.trim();
    final montant = double.tryParse(_montantCtrl.text.replaceAll(' ', '')) ?? 0;
    final duree   = int.tryParse(_dureeCtrl.text) ?? 30;

    if (nom.isEmpty || montant <= 0) {
      _toast('Nom et montant obligatoires', err: true);
      return;
    }

    final dette = Dette(
      nomDebiteur:    nom,
      telephone:      _telCtrl.text.trim(),
      montantInitial: montant,
      dateDebut:      _dateDebut,
      dureeJours:     duree,
      creancier:      _creancierCtrl.text.trim().isEmpty
          ? null : _creancierCtrl.text.trim(),
    );

    await _db.ajouterDette(dette);
    _nomCtrl.clear(); _telCtrl.clear();
    _montantCtrl.clear(); _dureeCtrl.clear();
    _creancierCtrl.clear();
    _dateDebut = DateTime.now();

    Navigator.pop(context); // Fermer la bottomsheet
    await _charger();
    _toast('✅ Dette enregistrée !');
  }

  /// Ouvrir le dialogue de remboursement (total ou partiel)
  void _ouvrirRemboursement(Dette dette) {
    final montantCtrl = TextEditingController(
        text: dette.montantRestant.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    bool paiementTotal = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          margin: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Handle
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            // Titre + solde
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(dette.nomDebiteur, style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
                Text('Reste à payer : ${_fmt(dette.montantRestant)} F',
                    style: const TextStyle(color: _textMuted, fontSize: 13)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _redLight, borderRadius: BorderRadius.circular(20)),
                child: Text(_fmt(dette.montantRestant) + ' F',
                    style: const TextStyle(color: _red, fontSize: 15, fontWeight: FontWeight.w800))),
            ]),
            const SizedBox(height: 20),

            // Toggle total / partiel
            Container(
              decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () {
                    setBS(() => paiementTotal = true);
                    montantCtrl.text = dette.montantRestant.toStringAsFixed(0);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: paiementTotal ? _green : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Paiement total',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: paiementTotal ? Colors.white : _textMuted)))))),
                Expanded(child: GestureDetector(
                  onTap: () => setBS(() => paiementTotal = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    decoration: BoxDecoration(
                      color: !paiementTotal ? _amber : Colors.transparent,
                      borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text('Partiel',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                            color: !paiementTotal ? Colors.white : _textMuted)))))),
              ]),
            ),
            const SizedBox(height: 16),

            // Montant
            _bsField(montantCtrl, 'Montant reçu (FCFA)',
                Icons.payments_outlined,
                readOnly: paiementTotal,
                type: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly]),
            const SizedBox(height: 12),

            // Note optionnelle
            _bsField(noteCtrl, 'Note (optionnel)', Icons.note_outlined),
            const SizedBox(height: 20),

            // Bouton confirmer
            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final m = double.tryParse(montantCtrl.text) ?? 0;
                  if (m <= 0) { _toast('Montant invalide', err: true); return; }
                  if (m > dette.montantRestant) {
                    _toast('Montant supérieur à la dette', err: true); return;
                  }
                  Navigator.pop(context);
                  await _db.enregistrerPaiement(dette.id!, m,
                      note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim());
                  await _charger();
                  _toast(m >= dette.montantRestant
                      ? '✅ Dette entièrement remboursée !'
                      : '✅ Paiement de ${_fmt(m)} F enregistré');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                child: const Text('Confirmer le paiement',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
            const SizedBox(height: 8),
          ]),
        ),
      ),
    );
  }

  /// Voir l'historique des paiements d'une dette
  void _voirHistorique(Dette dette) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 16),

          Text('Historique — ${dette.nomDebiteur}',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 4),
          Text('${dette.paiements.length} paiement(s) enregistré(s)',
              style: const TextStyle(color: _textMuted, fontSize: 13)),
          const SizedBox(height: 16),

          if (dette.paiements.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Aucun paiement enregistré',
                  style: TextStyle(color: _hint, fontSize: 14))))
          else
            ...dette.paiements.map((p) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _greenLight,
                  borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _green, shape: BoxShape.circle),
                  child: const Center(child: Icon(Icons.check_rounded,
                      color: Colors.white, size: 18))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('+${_fmt(p.montant)} F', style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w800, color: _greenDark)),
                  Text(_formatDate(p.date),
                      style: const TextStyle(fontSize: 11, color: _textMuted)),
                  if (p.note != null)
                    Text(p.note!, style: const TextStyle(fontSize: 11, color: _hint)),
                ])),
              ])),
            ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  /// Ouvrir le formulaire d'ajout (bottomsheet)
  void _ouvrirFormulaire() {
    _dateDebut = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Container(
          margin: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),

            const Text('➕ Nouveau débiteur',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _text)),
            const SizedBox(height: 4),
            const Text('Renseignez les informations de la dette',
                style: TextStyle(color: _hint, fontSize: 13)),
            const SizedBox(height: 20),

            _bsField(_nomCtrl, 'Nom du débiteur *', Icons.person_outline_rounded),
            const SizedBox(height: 12),

            // Téléphone avec indicatif
            Container(
              decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 15),
                  decoration: const BoxDecoration(color: _greenLight,
                    borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
                  child: const Row(children: [
                    Text('🇸🇳', style: TextStyle(fontSize: 16)),
                    SizedBox(width: 4),
                    Text('+221', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
                  ])),
                Expanded(child: TextField(controller: _telCtrl,
                  keyboardType: TextInputType.phone, maxLength: 9,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 14, color: _text),
                  decoration: const InputDecoration(counterText: '',
                    hintText: '77 000 00 00', hintStyle: TextStyle(color: _hint, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 15)))),
              ])),
            const SizedBox(height: 12),

            Row(children: [
              Expanded(child: _bsField(_montantCtrl, 'Montant (FCFA) *',
                  Icons.payments_outlined, type: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly])),
              const SizedBox(width: 12),
              Expanded(child: _bsField(_dureeCtrl, 'Durée (jours)',
                  Icons.timer_outlined, type: TextInputType.number,
                  formatters: [FilteringTextInputFormatter.digitsOnly])),
            ]),
            const SizedBox(height: 12),

            _bsField(_creancierCtrl, 'Créancier (si dette envers quelqu\'un)',
                Icons.account_balance_outlined),
            const SizedBox(height: 12),

            // Sélecteur de date de début
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: ctx,
                  initialDate: _dateDebut,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  builder: (_, child) => Theme(
                    data: ThemeData.light().copyWith(
                      colorScheme: const ColorScheme.light(primary: _green)),
                    child: child!),
                );
                if (d != null) setBS(() => _dateDebut = d);
              },
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  const Icon(Icons.calendar_today_outlined, color: _hint, size: 20),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Date de début de la dette',
                        style: TextStyle(fontSize: 11, color: _hint)),
                    Text(_formatDate(_dateDebut),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _text)),
                  ]),
                  const Spacer(),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _hint),
                ])),
            ),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity, height: 52,
              child: ElevatedButton(
                onPressed: _ajouterDette,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _red, foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14))),
                child: const Text('Enregistrer la dette',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              )),
            const SizedBox(height: 8),
          ])),
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: SafeArea(child: Column(children: [

        // ── HEADER
        _buildHeader(),

        // ── RECHERCHE + FILTRES
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Rechercher un débiteur...',
              hintStyle: const TextStyle(color: _hint, fontSize: 14),
              prefixIcon: const Icon(Icons.search_rounded, color: _hint, size: 22),
              suffixIcon: _isSyncing
                  ? const Padding(padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: _green)))
                  : IconButton(icon: const Icon(Icons.sync_rounded, color: _green, size: 20),
                      onPressed: _syncCloud, tooltip: 'Synchroniser'),
              filled: true, fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 14)))),

        // ── CHIPS FILTRES
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(children: [
            _chip('tous',       'Tous (${_dettes.length})'),
            _chip('en_cours',   '🟡 En cours'),
            _chip('en_retard',  '🔴 En retard'),
            _chip('rembourse',  '✅ Remboursés'),
          ])),

        // ── LISTE
        Expanded(child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: _red))
            : _filtered.isEmpty
                ? _empty()
                : RefreshIndicator(
                    onRefresh: _syncCloud, color: _red,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _detteCard(_filtered[i])))),
      ])),

      // ── FAB ajouter débiteur
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaire,
        backgroundColor: _red,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouveau débiteur',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // ══════════════════════════════════════
  //  HEADER
  // ══════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(color: _red,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          GestureDetector(onTap: () => Navigator.pop(context),
            child: Container(width: 38, height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22))),
          const SizedBox(width: 12),
          const Expanded(child: Text('💸  Dettes clients',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          // Indicateur cloud
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Icon(_isSyncing ? Icons.sync_rounded : Icons.cloud_done_rounded,
                  color: Colors.white, size: 14),
              const SizedBox(width: 4),
              Text(_isSyncing ? 'Sync...' : 'Cloud',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ])),
        ]),
        const SizedBox(height: 14),
        // Stats
        Row(children: [
          _statBox(_fmt(_totalDu) + ' F', 'Total dû'),
          const SizedBox(width: 10),
          _statBox('${_dettes.where((d) => !d.estRembourse).length}', 'Débiteurs'),
          const SizedBox(width: 10),
          _statBox('$_nbEnRetard', 'En retard'),
        ]),
      ]));
  }

  // ══════════════════════════════════════
  //  CARTE DETTE
  // ══════════════════════════════════════
  Widget _detteCard(Dette d) {
    final couleurs = _couleurAvatar(d.nomDebiteur);
    final pct      = d.pourcentageRembourse;

    Color statutBg; Color statutClr; String statutLbl;
    switch (d.statutCalcule) {
      case 'en_retard':
        statutBg = _redLight; statutClr = _red; statutLbl = '🔴 En retard';
        break;
      case 'rembourse':
        statutBg = _greenLight; statutClr = _greenDark; statutLbl = '✅ Remboursé';
        break;
      default:
        statutBg = _amberLight; statutClr = _amber; statutLbl = '🟡 En cours';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: d.estatCalcule == 'en_retard'
              ? _red.withOpacity(0.25) : const Color(0xFFE8E8E5),
          width: d.statutCalcule == 'en_retard' ? 1 : 0.5)),
      child: Column(children: [
        // ── Ligne principale
        Padding(
          padding: const EdgeInsets.all(14),
          child: Column(children: [
            Row(children: [
              // Avatar
              Container(width: 46, height: 46,
                decoration: BoxDecoration(color: couleurs[0], shape: BoxShape.circle),
                child: Center(child: Text(_initiales(d.nomDebiteur),
                    style: TextStyle(color: couleurs[1], fontSize: 15, fontWeight: FontWeight.w800)))),
              const SizedBox(width: 12),

              // Infos débiteur
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.nomDebiteur, style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800, color: _text)),
                const SizedBox(height: 2),
                if (d.telephone.isNotEmpty)
                  Text('📞 ${d.telephone}',
                      style: const TextStyle(fontSize: 12, color: _textMuted)),
                if (d.creancier != null)
                  Text('👤 Créancier : ${d.creancier}',
                      style: const TextStyle(fontSize: 11, color: _hint)),
              ])),

              // Montant restant
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_fmt(d.montantRestant) + ' F',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                        color: d.estRembourse ? _greenDark : _red)),
                Text('restant', style: const TextStyle(fontSize: 10, color: _hint)),
              ]),
            ]),

            const SizedBox(height: 12),

            // ── Barre de progression remboursement
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('Remboursé : ${_fmt(d.montantRembourse)} F',
                    style: const TextStyle(fontSize: 11, color: _textMuted)),
                Text('/ ${_fmt(d.montantInitial)} F total',
                    style: const TextStyle(fontSize: 11, color: _hint)),
              ]),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct, minHeight: 8,
                  backgroundColor: const Color(0xFFE8E8E5),
                  valueColor: AlwaysStoppedAnimation<Color>(
                      d.estRembourse ? _green : pct > 0.5 ? _amberMid : _red))),
              const SizedBox(height: 4),
              Text('${(pct * 100).toStringAsFixed(0)}% remboursé',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                      color: d.estRembourse ? _greenDark : _textMuted)),
            ]),

            const SizedBox(height: 12),

            // ── Infos temporelles
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _grey, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                _infoTemps(Icons.calendar_today_outlined,
                    'Début', _formatDate(d.dateDebut)),
                _dividerV(),
                _infoTemps(Icons.timer_outlined,
                    'Durée', '${d.dureeJours} j'),
                _dividerV(),
                _infoTemps(
                  d.joursRestants >= 0
                      ? Icons.hourglass_bottom_rounded
                      : Icons.warning_amber_rounded,
                  d.joursRestants >= 0 ? 'Reste' : 'Retard',
                  d.estRembourse ? '—' :
                  d.joursRestants >= 0
                      ? '${d.joursRestants} j'
                      : '${d.joursRestants.abs()} j',
                  couleur: d.estRembourse ? _green :
                  d.joursRestants < 0 ? _red :
                  d.joursRestants <= 7 ? _amber : _greenDark,
                ),
              ])),
          ]),
        ),

        // ── Pied : statut + actions
        Container(
          decoration: BoxDecoration(
            color: _grey,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statutBg, borderRadius: BorderRadius.circular(20)),
              child: Text(statutLbl,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: statutClr))),
            const Spacer(),

            // Historique paiements
            if (d.paiements.isNotEmpty)
              GestureDetector(
                onTap: () => _voirHistorique(d),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _greenLight, borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.history_rounded, size: 14, color: _greenDark),
                    const SizedBox(width: 4),
                    Text('${d.paiements.length}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _greenDark)),
                  ]))),

            // Bouton rembourser (masqué si déjà remboursé)
            if (!d.estRembourse)
              GestureDetector(
                onTap: () => _ouvrirRemboursement(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                      color: _green, borderRadius: BorderRadius.circular(10)),
                  child: const Row(children: [
                    Icon(Icons.payments_rounded, size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Rembourser',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]))),
          ])),
      ]));
  }

  // ══════════════════════════════════════
  //  HELPERS UI
  // ══════════════════════════════════════
  Widget _statBox(String val, String lbl) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(12)),
    child: Column(children: [
      Text(val, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text(lbl, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
    ])));

  Widget _chip(String val, String label) {
    final active = _filtreActif == val;
    return GestureDetector(
      onTap: () => setState(() => _filtreActif = val),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _redLight : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _redMid : const Color(0xFFE0E0E0))),
        child: Text(label, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w700,
            color: active ? _red : _textMuted))));
  }

  Widget _bsField(TextEditingController ctrl, String hint, IconData icon,
      {bool readOnly = false, TextInputType type = TextInputType.text,
       List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: ctrl, readOnly: readOnly,
      keyboardType: type, inputFormatters: formatters,
      style: const TextStyle(fontSize: 14, color: _text),
      decoration: InputDecoration(
        hintText: hint, hintStyle: const TextStyle(color: _hint, fontSize: 13),
        prefixIcon: Icon(icon, color: _hint, size: 20),
        filled: true, fillColor: _grey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _red, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14)));
  }

  Widget _infoTemps(IconData icon, String lbl, String val, {Color couleur = _textMuted}) =>
    Expanded(child: Column(children: [
      Icon(icon, size: 14, color: couleur),
      const SizedBox(height: 3),
      Text(lbl, style: const TextStyle(fontSize: 9, color: _hint)),
      Text(val, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
    ]));

  Widget _dividerV() => Container(width: 0.5, height: 36, color: const Color(0xFFE0E0E0));

  Widget _empty() => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const Text('💸', style: TextStyle(fontSize: 56)),
    const SizedBox(height: 14),
    const Text('Aucun débiteur', style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w800, color: _textMuted)),
    const SizedBox(height: 6),
    const Text('Appuyez sur le bouton + pour en ajouter un',
        style: TextStyle(fontSize: 13, color: _hint)),
  ]));

  // ── Utilitaires
  String _fmt(double n) => n.toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  String _initiales(String nom) {
    final p = nom.trim().split(' ');
    return p.length >= 2 ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : nom.length >= 2 ? nom.substring(0, 2).toUpperCase() : nom.toUpperCase();
  }

  static const List<List<Color>> _avColors = [
    [Color(0xFFEAF3DE), Color(0xFF27500A)],
    [Color(0xFFFCEBEB), Color(0xFF791F1F)],
    [Color(0xFFE6F1FB), Color(0xFF0C447C)],
    [Color(0xFFFAEEDA), Color(0xFF633806)],
    [Color(0xFFEEEDFE), Color(0xFF3C3489)],
    [Color(0xFFE1F5EE), Color(0xFF085041)],
    [Color(0xFFFAECE7), Color(0xFF712B13)],
  ];

  List<Color> _couleurAvatar(String nom) =>
      _avColors[nom.codeUnitAt(0) % _avColors.length];

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: err ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }
}

// Extension pour corriger la typo dans la carte
extension on Dette {
  String get estatCalcule => statutCalcule;
}