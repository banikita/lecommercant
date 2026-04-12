import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:le_commercant/models/dettes_model.dart';
import 'package:le_commercant/database/dettes_database.dart';

class PageDettes extends StatefulWidget {
  const PageDettes({super.key});

  @override
  State<PageDettes> createState() => _PageDettesState();
}

class _PageDettesState extends State<PageDettes> with SingleTickerProviderStateMixin {
  
  // ── Palette Cohérente avec le Dashboard
  static const _green      = Color(0xFF0F6E56); 
  static const _greenLight = Color(0xFFE1F5EE);
  static const _greenDark  = Color(0xFF27500A);
  static const _red        = Color(0xFFA32D2D); 
  static const _redLight   = Color(0xFFFCEBEB);
  static const _amber      = Color(0xFF854F0B);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid   = Color(0xFFFAC775);
  static const _blueLight  = Color(0xFFE6F1FB);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _hint       = Color(0xFF9CA3AF);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);

  final _db           = DetteDatabase.instance;
  List<Dette> _dettes = [];
  bool _isLoading     = true;
  bool _isSyncing     = false;
  String _filtreActif = 'tous';
  final _searchCtrl   = TextEditingController();

  final _nomCtrl       = TextEditingController();
  final _telCtrl       = TextEditingController();
  final _montantCtrl   = TextEditingController();
  final _dureeCtrl     = TextEditingController();
  final _creancierCtrl = TextEditingController();
  DateTime _dateDebut = DateTime.now();

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _searchCtrl.dispose(); _nomCtrl.dispose(); _telCtrl.dispose();
    _montantCtrl.dispose(); _dureeCtrl.dispose(); _creancierCtrl.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════
  //  LOGIQUE
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

  List<Dette> get _filtered {
    final q = _searchCtrl.text.toLowerCase();
    return _dettes.where((d) {
      final mq = d.nomDebiteur.toLowerCase().contains(q) || d.telephone.contains(q);
      final mf = _filtreActif == 'tous' ||
          (_filtreActif == 'en_cours' && d.statutCalcule == 'en_cours') ||
          (_filtreActif == 'en_retard' && d.statutCalcule == 'en_retard') ||
          (_filtreActif == 'rembourse' && d.statutCalcule == 'rembourse');
      return mq && mf;
    }).toList();
  }

  double get _totalDu => _dettes.where((d) => !d.estRembourse).fold(0.0, (a, d) => a + d.montantRestant);
  int get _nbEnRetard => _dettes.where((d) => d.statutCalcule == 'en_retard').length;

  // ══════════════════════════════════════
  //  ACTIONS & NAVIGATION
  // ══════════════════════════════════════

  void _ouvrirFormulaire() {
    _nomCtrl.clear(); _telCtrl.clear(); _montantCtrl.clear(); _dureeCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildFormulaire(),
    );
  }

  void _ouvrirRemboursement(Dette d) {
    _montantCtrl.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text("Rembourser ${d.nomDebiteur}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: _montantCtrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Montant du versement (F)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Annuler", style: TextStyle(color: _textMuted))),
          ElevatedButton(
            onPressed: () async {
              final montant = double.tryParse(_montantCtrl.text) ?? 0;
              if (montant > 0) {
                // Ta logique de mise à jour en DB ici
                Navigator.pop(context);
                _charger();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: const Text("Valider", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════
  //  BUILD PRINCIPAL
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _grey,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Rechercher un débiteur...',
                hintStyle: const TextStyle(color: _hint, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded, color: _hint, size: 22),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), 
                    borderSide: const BorderSide(color: _greyMid, width: 0.5)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), 
                    borderSide: const BorderSide(color: _greyMid, width: 0.5)),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Row(children: [
              _chip('tous', 'Tous (${_dettes.length})'),
              _chip('en_cours', '🟡 En cours'),
              _chip('en_retard', '🔴 En retard'),
              _chip('rembourse', '✅ Payé'),
            ]),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _green))
                : RefreshIndicator(
                    onRefresh: _syncCloud,
                    color: _green,
                    child: _filtered.isEmpty 
                      ? _buildEmptyState() 
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                          itemCount: _filtered.length,
                          itemBuilder: (_, i) => _buildDetteCard(_filtered[i]),
                        ),
                  ),
          ),
        ]),
      ),
      
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ouvrirFormulaire,
        backgroundColor: _green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nouvelle dette', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }

  // ── COMPOSANTS UI
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: _green,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: Column(children: [
        Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 22))),
          const SizedBox(width: 12),
          const Expanded(child: Text('Dettes Clients', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
          if (_isSyncing)
            const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else
            IconButton(onPressed: _syncCloud, icon: const Icon(Icons.sync_rounded, color: Colors.white70, size: 20)),
        ]),
        const SizedBox(height: 16),
        Row(children: [
          _statBox('${_fmt(_totalDu)} F', 'Total à percevoir'),
          const SizedBox(width: 10),
          _statBox('$_nbEnRetard', 'En retard', isAlert: _nbEnRetard > 0),
        ]),
      ]),
    );
  }

  Widget _statBox(String val, String lbl, {bool isAlert = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isAlert ? _red.withOpacity(0.2) : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: isAlert ? Border.all(color: Colors.white24) : null,
        ),
        child: Column(children: [
          Text(val, style: TextStyle(color: isAlert ? _amberMid : Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          Text(lbl, style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  Widget _buildDetteCard(Dette d) {
    final bool estRetard = d.statutCalcule == 'en_retard';
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: estRetard ? _red.withOpacity(0.3) : _greyMid, width: 0.5),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: estRetard ? _redLight : _greenLight, shape: BoxShape.circle),
              child: Center(child: Text(d.nomDebiteur.substring(0,1).toUpperCase(), 
                style: TextStyle(color: estRetard ? _red : _green, fontWeight: FontWeight.w800)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(d.nomDebiteur, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text(d.telephone.isEmpty ? 'Pas de numéro' : d.telephone, style: const TextStyle(color: _textMuted, fontSize: 12)),
              ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmt(d.montantRestant)} F', 
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: estRetard ? _red : _text)),
              Text(d.estRembourse ? 'Réglé' : 'À payer', style: const TextStyle(fontSize: 10, color: _hint)),
            ]),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: d.pourcentageRembourse,
              backgroundColor: _grey,
              color: d.estRembourse ? _green : (estRetard ? _red : _amberMid),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: const BoxDecoration(color: _grey, borderRadius: BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16))),
          child: Row(children: [
            Text(estRetard ? '⚠️ Retard de ${d.joursRestants.abs()}j' : '📅 Échéance: ${d.dureeJours}j', 
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: estRetard ? _red : _textMuted)),
            const Spacer(),
            if (!d.estRembourse)
              GestureDetector(
                onTap: () => _ouvrirRemboursement(d),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(8)),
                  child: const Text('Rembourser', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
          ]),
        )
      ]),
    );
  }

  Widget _buildFormulaire() {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _greyMid, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text("Nouvelle Dette", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _green)),
          const SizedBox(height: 20),
          TextField(controller: _nomCtrl, decoration: const InputDecoration(labelText: "Nom du débiteur", prefixIcon: Icon(Icons.person_outline))),
          const SizedBox(height: 12),
          TextField(controller: _telCtrl, decoration: const InputDecoration(labelText: "Téléphone", prefixIcon: Icon(Icons.phone_outlined)), keyboardType: TextInputType.phone),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: _montantCtrl, decoration: const InputDecoration(labelText: "Montant (F)", prefixIcon: Icon(Icons.money)), keyboardType: TextInputType.number)),
            const SizedBox(width: 10),
            Expanded(child: TextField(controller: _dureeCtrl, decoration: const InputDecoration(labelText: "Délai (jours)", prefixIcon: Icon(Icons.timer_outlined)), keyboardType: TextInputType.number)),
          ]),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: () { /* Logique Save DB */ Navigator.pop(context); _charger(); },
              style: ElevatedButton.styleFrom(backgroundColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text("Enregistrer la dette", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ]),
      ),
    );
  }

  Widget _chip(String val, String label) {
    final active = _filtreActif == val;
    return GestureDetector(
      onTap: () => setState(() => _filtreActif = val),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _green : _greyMid),
        ),
        child: Text(label, style: TextStyle(color: active ? Colors.white : _textMuted, fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildEmptyState() => const Center(child: Text('Aucune dette trouvée', style: TextStyle(color: _textMuted)));

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
}