import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'creanciers_page.dart'; // à importer

const Color _kGreen = Color(0xFF0F6E56);
const Color _kRed = Color(0xFFA32D2D);

class DepensesPage extends StatefulWidget {
  final int commercantId;
  const DepensesPage({super.key, required this.commercantId});

  @override
  State<DepensesPage> createState() => _DepensesPageState();
}

class _DepensesPageState extends State<DepensesPage> {
  final _supa = Supabase.instance.client;
  List<Map<String, dynamic>> _depenses = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  String _periode = 'mois';
  DateTime _selectedDate = DateTime.now();

  final _libelleCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  final _categorieCtrl = TextEditingController();
  DateTime _dateDepense = DateTime.now();

  @override
  void initState() {
    super.initState();
    _charger();
    _searchCtrl.addListener(_filterLocal);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _libelleCtrl.dispose();
    _montantCtrl.dispose();
    _categorieCtrl.dispose();
    super.dispose();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    // Jointure avec la table creanciers pour récupérer le nom du créancier
    final data = await _supa
        .from('depenses')
        .select('*, creanciers(nom)')
        .eq('commercant_id', widget.commercantId)
        .order('date_depense', ascending: false);
    setState(() {
      _depenses = List<Map<String, dynamic>>.from(data);
      _filterLocal();
      _loading = false;
    });
  }

  void _filterLocal() {
    String query = _searchCtrl.text.toLowerCase();
    final filteredBySearch = _depenses.where((d) {
      final libelle = (d['libelle'] as String).toLowerCase();
      final categorie = (d['categorie'] as String).toLowerCase();
      final creancierNom = (d['creanciers'] as Map?)?.containsKey('nom') == true
          ? (d['creanciers']['nom'] as String).toLowerCase()
          : '';
      return libelle.contains(query) || categorie.contains(query) || creancierNom.contains(query);
    }).toList();
    _filtered = filteredBySearch;
    _applyPeriodFilter();
  }

  void _applyPeriodFilter() {
    DateTime start;
    DateTime end = _selectedDate;
    if (_periode == 'jour') {
      start = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      end = start.add(const Duration(days: 1));
    } else if (_periode == 'mois') {
      start = DateTime(_selectedDate.year, _selectedDate.month, 1);
      end = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
    } else {
      start = DateTime(_selectedDate.year, 1, 1);
      end = DateTime(_selectedDate.year + 1, 1, 1);
    }
    setState(() {
      _filtered = _filtered.where((d) {
        DateTime date = DateTime.parse(d['date_depense']);
        return date.isAfter(start.subtract(const Duration(days: 1))) && date.isBefore(end);
      }).toList();
    });
  }

  Future<void> _ajouterDepenseManuelle() async {
    if (_libelleCtrl.text.trim().isEmpty || _montantCtrl.text.trim().isEmpty) {
      _showSnackBar('Veuillez remplir le libellé et le montant');
      return;
    }
    final montant = double.parse(_montantCtrl.text.trim());
    await _supa.from('depenses').insert({
      'commercant_id': widget.commercantId,
      'libelle': _libelleCtrl.text.trim(),
      'categorie': _categorieCtrl.text.trim().isEmpty ? 'Divers' : _categorieCtrl.text.trim(),
      'montant': montant,
      'date_depense': _dateDepense.toIso8601String().split('T').first,
      'type': 'divers',
      'creancier_id': null,
    });
    _libelleCtrl.clear();
    _montantCtrl.clear();
    _categorieCtrl.clear();
    _dateDepense = DateTime.now();
    _charger();
    if (mounted) Navigator.pop(context);
    _showSnackBar('Dépense ajoutée');
  }

  Future<void> _supprimer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Voulez-vous vraiment supprimer cette dépense ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (confirm != true) return;
    await _supa.from('depenses').delete().eq('id', id);
    _charger();
    _showSnackBar('Dépense supprimée');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  double get _totalDepensesPeriod {
    return _filtered.fold(0.0, (sum, d) => sum + (d['montant'] as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dépenses'),
        backgroundColor: _kGreen,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher (libellé, catégorie, créancier)',
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withOpacity(0.2),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPeriodFilters(),
                _buildTotalCard(),
                Expanded(child: _buildList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _kGreen,
        onPressed: () => _ouvrirFormulaire(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter dépense'),
      ),
    );
  }

  Widget _buildPeriodFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 2)]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildPeriodChip('Jour', 'jour'),
          _buildPeriodChip('Mois', 'mois'),
          _buildPeriodChip('Année', 'annee'),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
                _applyPeriodFilter();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodChip(String label, String value) {
    return FilterChip(
      label: Text(label),
      selected: _periode == value,
      onSelected: (sel) {
        if (sel) setState(() => _periode = value);
        _applyPeriodFilter();
      },
      backgroundColor: Colors.grey.shade200,
      selectedColor: _kGreen.withOpacity(0.2),
    );
  }

  Widget _buildTotalCard() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total ${_periode == 'jour' ? 'du jour' : _periode == 'mois' ? 'du mois' : 'de l\'année'} :',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            '${_totalDepensesPeriod.toStringAsFixed(0)} F',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _kRed),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_filtered.isEmpty) return const Center(child: Text('Aucune dépense pour cette période'));
    return ListView.builder(
      itemCount: _filtered.length,
      itemBuilder: (_, i) {
        final d = _filtered[i];
        final montantStr = (d['montant'] as num).toStringAsFixed(0);
        final type = d['type'] ?? 'divers';
        String typeIcon = '';
        if (type == 'achat_fournisseur') typeIcon = '🛒';
        if (type == 'remboursement_creancier') typeIcon = '🤝';
        final creancierNom = (d['creanciers'] as Map?)?.containsKey('nom') == true ? d['creanciers']['nom'] : null;

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            leading: Text(typeIcon, style: const TextStyle(fontSize: 24)),
            title: Text(d['libelle']),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${d['categorie']} · ${DateFormat('dd/MM/yyyy').format(DateTime.parse(d['date_depense']))}'),
                if (creancierNom != null) Text('Créancier : $creancierNom', style: const TextStyle(color: _kGreen)),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$montantStr F', style: const TextStyle(fontWeight: FontWeight.bold)),
                if (type == 'remboursement_creancier' && d['creancier_id'] != null)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: _kGreen),
                    tooltip: 'Détails du créancier',
                    onPressed: () => _voirHistoriqueCreancier(d['creancier_id']),
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _supprimer(d['id']),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _voirHistoriqueCreancier(int? creancierId) {
    if (creancierId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreanciersPage(
          commercantId: widget.commercantId,
          selectedCreancierId: creancierId,
        ),
      ),
    );
  }

  void _ouvrirFormulaire() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _libelleCtrl, decoration: const InputDecoration(labelText: 'Libellé *')),
              TextField(controller: _montantCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Montant *')),
              TextField(controller: _categorieCtrl, decoration: const InputDecoration(labelText: 'Catégorie')),
              ListTile(
                title: Text('Date : ${DateFormat('dd/MM/yyyy').format(_dateDepense)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: _dateDepense,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) setState(() => _dateDepense = date);
                  },
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _ajouterDepenseManuelle,
                style: ElevatedButton.styleFrom(backgroundColor: _kGreen),
                child: const Text('Enregistrer'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}