import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const Color _kGreen = Color(0xFF1A4A3A);
const Color _kGreenLight = Color(0xFF2D7A61);
const Color _kRed = Color(0xFFA32D2D);
const Color _kRedLight = Color(0xFFFFF0F0);
const Color _kWhite = Colors.white;
const Color _kGrey = Color(0xFFF5F5F5);
const Color _kBorder = Color(0xFFE2E8F0);

class CreanciersPage extends StatefulWidget {
  final int commercantId;
  final String? suggestedNom;
  final String? suggestedBoutique;
  final int? suggereId;
  final int? selectedCreancierId;
  final String? nomCommercant; // Pour les notifications

  const CreanciersPage({
    super.key,
    required this.commercantId,
    this.suggestedNom,
    this.suggestedBoutique,
    this.suggereId,
    this.selectedCreancierId,
    this.nomCommercant,
  });

  @override
  State<CreanciersPage> createState() => _CreanciersPageState();
}

class _CreanciersPageState extends State<CreanciersPage> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _creanciers = [];
  List<Map<String, dynamic>> _filteredList = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  final _nomCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  final _adresseCtrl = TextEditingController();
  final _montantCtrl = TextEditingController();
  DateTime? _echeance;

  List<String> _suggestions = [];

  // ✅ Méthode de formatage (accessible partout)
  String _fmt(double n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');

  @override
  void initState() {
    super.initState();
    _chargerCreanciers();
    _chargerSuggestions();
    _searchCtrl.addListener(_filter);
    if (widget.suggestedNom != null) {
      _nomCtrl.text = widget.suggestedNom!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _ouvrirFormulaire(preRempli: true);
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _adresseCtrl.dispose();
    _montantCtrl.dispose();
    super.dispose();
  }

  Future<void> _chargerCreanciers() async {
    setState(() => _loading = true);
    final data = await _supabase
        .from('creanciers')
        .select()
        .eq('commercant_id', widget.commercantId)
        .order('created_at', ascending: false);
    setState(() {
      _creanciers = List<Map<String, dynamic>>.from(data);
      _filter();
      _loading = false;
    });
  }

  Future<void> _chargerSuggestions() async {
    final creanciers = await _supabase
        .from('creanciers')
        .select('nom')
        .eq('commercant_id', widget.commercantId);
    List<String> noms = (creanciers as List).map((c) => c['nom'] as String).toList();

    final autresCommercants = await _supabase
        .from('commercants')
        .select('nom')
        .neq('id', widget.commercantId);
    noms.addAll((autresCommercants as List).map((c) => c['nom'] as String));

    setState(() {
      _suggestions = noms.toSet().toList();
    });
  }

  void _filter() {
    final query = _searchCtrl.text.toLowerCase();
    var filtered = _creanciers.where((c) {
      final nom = (c['nom'] as String).toLowerCase();
      final tel = (c['telephone'] as String? ?? '').toLowerCase();
      return nom.contains(query) || tel.contains(query);
    }).toList();

    if (widget.selectedCreancierId != null) {
      filtered = filtered.where((c) => c['id'] == widget.selectedCreancierId).toList();
    }

    setState(() {
      _filteredList = filtered;
    });
  }

  Future<void> _ajouter() async {
    if (_nomCtrl.text.trim().isEmpty || _montantCtrl.text.trim().isEmpty) {
      _showSnackBar('Veuillez remplir le nom et le montant');
      return;
    }
    final montant = double.parse(_montantCtrl.text.trim());
    await _supabase.from('creanciers').insert({
      'commercant_id': widget.commercantId,
      'nom': _nomCtrl.text.trim(),
      'telephone': _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
      'adresse': _adresseCtrl.text.trim().isEmpty ? null : _adresseCtrl.text.trim(),
      'montant_initial': montant,
      'montant_rembourse': 0,
      'echeance': _echeance?.toIso8601String().split('T').first,
      'statut': 'en_cours',
    });
    _viderChamps();
    _chargerCreanciers();
    if (mounted) Navigator.pop(context);
    _showSnackBar('Créancier ajouté');
  }

  void _viderChamps() {
    _nomCtrl.clear();
    _telCtrl.clear();
    _adresseCtrl.clear();
    _montantCtrl.clear();
    _echeance = null;
  }

  Future<void> _ajouterDetteExistante(Map<String, dynamic> creancier) async {
    final montantCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Ajouter une dette'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Créancier : ${creancier['nom']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Montant supplémentaire',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final montantSupp = double.tryParse(montantCtrl.text.trim()) ?? 0;
    if (montantSupp <= 0) return;
    final nouveauInitial = (creancier['montant_initial'] as num) + montantSupp;
    await _supabase.from('creanciers').update({
      'montant_initial': nouveauInitial,
      'statut': 'en_cours',
    }).eq('id', creancier['id']);
    _chargerCreanciers();
    _showSnackBar('Dette ajoutée');
  }

  Future<void> _effectuerRemboursement(Map<String, dynamic> creancier) async {
    final montantCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remboursement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Créancier : ${creancier['nom']}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(
              'Reste : ${_fmt(((creancier['montant_initial'] as num) - (creancier['montant_rembourse'] as num)).toDouble())} F',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: montantCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Montant remboursé',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kGreen,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final remboursement = double.tryParse(montantCtrl.text.trim()) ?? 0;
    if (remboursement <= 0) return;
    final nouveauRembourse = (creancier['montant_rembourse'] as num) + remboursement;
    final montantInitial = (creancier['montant_initial'] as num).toDouble();
    final statut = nouveauRembourse >= montantInitial ? 'solde' : 'en_cours';

    // Mise à jour du créancier
    await _supabase.from('creanciers').update({
      'montant_rembourse': nouveauRembourse,
      'statut': statut,
    }).eq('id', creancier['id']);

    // Enregistrement dans depenses
    await _supabase.from('depenses').insert({
      'commercant_id': widget.commercantId,
      'libelle': 'Remboursement à ${creancier['nom']}',
      'categorie': 'Remboursement créancier',
      'montant': remboursement,
      'date_depense': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      'type': 'remboursement_creancier',
      'creancier_id': creancier['id'],
    });

    // Notification au créancier (si autre commerçant)
    final autreCommercant = await _supabase
        .from('commercants')
        .select('id')
        .eq('nom', creancier['nom'])
        .maybeSingle();

    if (autreCommercant != null && autreCommercant['id'] != widget.commercantId) {
      await _supabase.from('notifications').insert({
        'commercant_id': autreCommercant['id'],
        'titre': '✅ Remboursement reçu',
        'message': '${widget.nomCommercant ?? "Un commerçant"} a remboursé ${_fmt(remboursement)} F CFA sur une dette initiale de ${_fmt(montantInitial)} F CFA.',
        'type': 'remboursement_creance',
        'creancier_id': creancier['id'],
        'est_lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    _chargerCreanciers();
    _showSnackBar('Remboursement enregistré');
  }

  Future<void> _supprimer(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer'),
        content: const Text('Supprimer ce créancier ?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kRed,
              foregroundColor: _kWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await _supabase.from('creanciers').delete().eq('id', id);
    _chargerCreanciers();
    _showSnackBar('Supprimé');
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  Widget _buildAutocomplete() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _suggestions.where((option) =>
            option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        _nomCtrl.text = selection;
      },
      fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
        return TextField(
          controller: _nomCtrl,
          focusNode: focusNode,
          decoration: InputDecoration(
            labelText: 'Nom *',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kGrey,
      appBar: AppBar(
        title: const Text('Mes créanciers',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _kGreen,
        foregroundColor: _kWhite,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Rechercher par nom ou téléphone',
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
          ? const Center(child: CircularProgressIndicator(color: _kGreenLight))
          : _filteredList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline, size: 64, color: _kGreenLight),
                      const SizedBox(height: 16),
                      Text('Aucun créancier',
                          style: TextStyle(fontSize: 16, color: _kGreenLight)),
                      const SizedBox(height: 8),
                      if (widget.selectedCreancierId == null)
                        Text('Ajoutez votre premier créancier',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filteredList.length,
                  itemBuilder: (_, i) {
                    final c = _filteredList[i];
                    final solde = (c['montant_initial'] as num) - (c['montant_rembourse'] as num);
                    final soldeStr = _fmt(solde.toDouble()); // ✅ conversion explicite
                    final isSolde = c['statut'] == 'solde';
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(c['nom'],
                                          style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w800,
                                              color: _kGreen)),
                                      const SizedBox(height: 4),
                                      Text('Dû: $soldeStr F',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: isSolde ? Colors.grey.shade600 : _kRed,
                                              fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                                if (!isSolde)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _kRedLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text('À rembourser',
                                        style: TextStyle(fontSize: 11, color: _kRed)),
                                  ),
                              ],
                            ),
                            const Divider(height: 20, color: _kBorder),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (!isSolde) ...[
                                  _ActionIcon(
                                    icon: Icons.add_circle_outline,
                                    label: 'Dette',
                                    color: _kGreen,
                                    onTap: () => _ajouterDetteExistante(c),
                                  ),
                                  const SizedBox(width: 12),
                                  _ActionIcon(
                                    icon: Icons.payment,
                                    label: 'Rembourser',
                                    color: _kGreen,
                                    onTap: () => _effectuerRemboursement(c),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                _ActionIcon(
                                  icon: Icons.delete_outline,
                                  label: 'Supprimer',
                                  color: Colors.red.shade400,
                                  onTap: () => _supprimer(c['id']),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: widget.selectedCreancierId == null
          ? FloatingActionButton.extended(
              onPressed: () => _ouvrirFormulaire(),
              backgroundColor: _kGreen,
              icon: const Icon(Icons.add, color: _kWhite),
              label: const Text('Nouveau créancier',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  void _ouvrirFormulaire({bool preRempli = false}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (_, scrollController) => Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: _kBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('Ajouter un créancier',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    _buildAutocomplete(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _telCtrl,
                      decoration: InputDecoration(
                        labelText: 'Téléphone',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _adresseCtrl,
                      decoration: InputDecoration(
                        labelText: 'Adresse',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _montantCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Montant dû *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: ctx,
                          initialDate: DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) setState(() => _echeance = date);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: _kBorder),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, color: _kGreen),
                            const SizedBox(width: 12),
                            Text(
                              _echeance == null
                                  ? 'Date d’échéance (optionnel)'
                                  : DateFormat('dd/MM/yyyy').format(_echeance!),
                              style: TextStyle(
                                color: _echeance == null ? Colors.grey.shade600 : _kGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _ajouter,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGreen,
                          foregroundColor: _kWhite,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Enregistrer',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Widget utilitaire pour les icônes d'action
class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}