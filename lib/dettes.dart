import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dette_models.dart';
import 'details_debiteur_page.dart';

final _supa = Supabase.instance.client;

// Liste des modes de paiement avec images
final List<_ModePaiement> _modesPaiement = [
  _ModePaiement(nom: 'Espèces', icone: Icons.money, imageAsset:'assets/images/cash.jpg', couleur: green),
  _ModePaiement(nom: 'Wave', icone: Icons.waves, imageAsset: 'assets/images/wave.png', couleur: Colors.blue.shade700),
  _ModePaiement(nom: 'Orange Money', icone: Icons.phone_android, imageAsset: 'assets/images/orangeMoney.png', couleur: Colors.orange),
];

class _ModePaiement {
  final String nom;
  final IconData icone;
  final String? imageAsset;
  final Color couleur;
  _ModePaiement({required this.nom, required this.icone, this.imageAsset, required this.couleur});
}

class DettesPage extends StatefulWidget {
  final int commercantId;
  final int? selectedDebiteurId;

  const DettesPage({
    super.key,
    required this.commercantId,
    this.selectedDebiteurId,
  });

  @override
  State<DettesPage> createState() => _DettesPageState();
}

class _DettesPageState extends State<DettesPage> {
  List<DebiteurAvecDettes> _debiteurs = [];
  bool _loading = true;
  String _recherche = '';

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final dettesData = await _supa
          .from('dettes')
          .select('*, debiteurs(nom, telephone, quartier)')
          .eq('commercant_id', widget.commercantId)
          .order('created_at', ascending: false);

      Map<int, DebiteurAvecDettes> map = {};
      for (var d in dettesData as List) {
        final debId = (d['debiteur_id'] as num).toInt();
        final debInfo = d['debiteurs'] as Map?;
        if (!map.containsKey(debId)) {
          map[debId] = DebiteurAvecDettes(
            id: debId,
            nom: debInfo?['nom'] as String? ?? d['nom_debiteur'] as String? ?? '',
            telephone: debInfo?['telephone'] as String?,
            quartier: debInfo?['quartier'] as String?,
            dettes: [],
          );
        }
        final dette = Dette.fromMap(
          d,
          nomDebiteur: map[debId]!.nom,
          telephone: map[debId]!.telephone,
          quartier: map[debId]!.quartier,
        );
        map[debId]!.dettes.add(dette);
      }
      var liste = map.values.toList();
      liste.sort((a, b) => a.nom.compareTo(b.nom));

      if (widget.selectedDebiteurId != null) {
        liste = liste.where((deb) => deb.id == widget.selectedDebiteurId).toList();
        if (liste.isEmpty && mounted) {
          _snack('Débiteur introuvable', erreur: true);
        }
      }

      setState(() {
        _debiteurs = liste;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      _snack('Erreur : $e', erreur: true);
    }
  }

  List<DebiteurAvecDettes> get _filtres {
    final q = _recherche.toLowerCase();
    return _debiteurs.where((deb) =>
        deb.nom.toLowerCase().contains(q) ||
        (deb.telephone ?? '').contains(q)).toList();
  }

  void _snack(String msg, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: erreur ? red : green,
      behavior: SnackBarBehavior.floating,
    ));
  }

  void _afficherInfosDebiteur(DebiteurAvecDettes deb) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.person, color: green),
            const SizedBox(width: 8),
            Text(deb.nom, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (deb.telephone != null && deb.telephone!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.phone, size: 18, color: textMuted),
                    const SizedBox(width: 8),
                    Text(deb.telephone!),
                  ],
                ),
              ),
            if (deb.quartier != null && deb.quartier!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 18, color: textMuted),
                    const SizedBox(width: 8),
                    Text(deb.quartier!),
                  ],
                ),
              ),
            if ((deb.telephone == null || deb.telephone!.isEmpty) && (deb.quartier == null || deb.quartier!.isEmpty))
              const Text('Aucune information supplémentaire', style: TextStyle(color: textMuted)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  void _ouvrirDetails(DebiteurAvecDettes deb) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DetailsDebiteurPage(debiteur: deb),
      ),
    );
  }

  void _ouvrirPaiement(DebiteurAvecDettes deb) async {
    final montantCtrl = TextEditingController();
    String modeSelectionne = _modesPaiement.first.nom;
    final soldeTotal = deb.soldeTotal;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDialogState) {
          return AlertDialog(
            title: Text('Remboursement - ${deb.nom}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Solde total dû : ${f(soldeTotal)}'),
                const SizedBox(height: 12),
                TextField(
                  controller: montantCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: 'Montant à rembourser',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('Mode de paiement :', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _modesPaiement.map((mode) {
                    final isSelected = mode.nom == modeSelectionne;
                    return GestureDetector(
                      onTap: () => setDialogState(() => modeSelectionne = mode.nom),
                      child: Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected ? mode.couleur.withOpacity(0.2) : Colors.grey.shade100,
                          border: Border.all(
                            color: isSelected ? mode.couleur : Colors.grey.shade400,
                            width: isSelected ? 3 : 1,
                          ),
                        ),
                        child: Center(
                          child: mode.imageAsset != null
                              ? ClipOval(
                                  child: Image.asset(
                                    mode.imageAsset!,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(mode.icone, size: 40, color: mode.couleur),
                                  ),
                                )
                              : Icon(mode.icone, size: 40, color: mode.couleur),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler', style: TextStyle(fontSize: 14)),
              ),
              ElevatedButton(
                onPressed: () async {
                  final montant = double.tryParse(montantCtrl.text.trim()) ?? 0;
                  if (montant <= 0 || montant > soldeTotal) {
                    _snack('Montant invalide', erreur: true);
                    return;
                  }
                  Navigator.pop(ctx);
                  await _enregistrerPaiement(deb, montant, modeSelectionne);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(80, 36),
                ),
                child: const Text('Valider', style: TextStyle(fontSize: 14)),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _enregistrerPaiement(
      DebiteurAvecDettes deb, double montant, String mode) async {
    try {
      double reste = montant;
      for (var dette in deb.dettes) {
        if (reste <= 0) break;
        if (dette.solde <= 0) continue;
        final part = reste < dette.solde ? reste : dette.solde;
        final newRemb = dette.montantRembourse + part;
        final solde = newRemb >= dette.montantInitial;
        await _supa.from('dettes').update({
          'montant_rembourse': newRemb,
          'statut': solde ? 'solde' : 'en_cours',
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', dette.id);
        await _supa.from('paiements').insert({
          'dette_id': dette.id,
          'commercant_id': widget.commercantId,
          'montant': part,
          'mode_paiement': mode,
          'date': DateTime.now().toIso8601String().split('T').first,
          'created_at': DateTime.now().toIso8601String(),
        });
        reste -= part;
      }
      _charger();
      _snack('Paiement de ${f(montant)} effectué');
    } catch (e) {
      _snack('Erreur paiement : $e', erreur: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: grey,
      appBar: AppBar(
        title: const Text('Dettes clients', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: green,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _recherche = v),
              decoration: InputDecoration(
                hintText: 'Rechercher un client',
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
          ? const Center(child: CircularProgressIndicator(color: green))
          : _filtres.isEmpty
              ? const Center(child: Text('Aucun débiteur'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _filtres.length,
                  itemBuilder: (_, i) => _CarteDebiteur(
                    debiteur: _filtres[i],
                    onDetails: () => _ouvrirDetails(_filtres[i]),
                    onPaiement: () => _ouvrirPaiement(_filtres[i]),
                    onInfo: () => _afficherInfosDebiteur(_filtres[i]),
                  ),
                ),
    );
  }
}

class _CarteDebiteur extends StatelessWidget {
  final DebiteurAvecDettes debiteur;
  final VoidCallback onDetails, onPaiement, onInfo;

  const _CarteDebiteur({
    required this.debiteur,
    required this.onDetails,
    required this.onPaiement,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    final solde = debiteur.soldeTotal;
    final isEnRetard = debiteur.enRetardGlobal;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: aColor(debiteur.nom).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      ini(debiteur.nom),
                      style: TextStyle(
                          color: aColor(debiteur.nom),
                          fontSize: 18,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(debiteur.nom,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w800)),
                      if (debiteur.telephone != null)
                        Text(debiteur.telephone!,
                            style: const TextStyle(
                                fontSize: 12, color: textMuted)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      f(solde),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: solde > 0 ? red : green),
                    ),
                    if (isEnRetard)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: redLight,
                            borderRadius: BorderRadius.circular(20)),
                        child: const Text('⚠️ Retard',
                            style: TextStyle(fontSize: 10, color: red)),
                      ),
                  ],
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ActionButton(
                  icon: Icons.info_outline,
                  label: 'Infos',
                  onTap: onInfo,
                  backgroundColor: Colors.blueGrey,
                  foregroundColor: Colors.white,
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  icon: Icons.info_outline,
                  label: 'Détails',
                  onTap: onDetails,
                  backgroundColor: grey,
                  foregroundColor: textMuted,
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  icon: Icons.payment,
                  label: 'Rembourser',
                  onTap: onPaiement,
                  backgroundColor: green,
                  foregroundColor: Colors.white,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color foregroundColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 115, // Largeur augmentée pour que "Rembourser" tienne sur une ligne
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          elevation: 1,
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}