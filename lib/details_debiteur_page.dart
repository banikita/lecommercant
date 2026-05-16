import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dette_models.dart';

final _supa = Supabase.instance.client;

class DetailsDebiteurPage extends StatefulWidget {
  final DebiteurAvecDettes debiteur;
  const DetailsDebiteurPage({super.key, required this.debiteur});

  @override
  State<DetailsDebiteurPage> createState() => _DetailsDebiteurPageState();
}

class _DetailsDebiteurPageState extends State<DetailsDebiteurPage> {
  Map<int, List<DetteProduit>> _produitsParDette = {};
  Map<int, List<Paiement>> _paiementsParDette = {};

  @override
  void initState() {
    super.initState();
    _chargerDetails();
  }

  Future<void> _chargerDetails() async {
    for (var dette in widget.debiteur.dettes) {
      final produits = await _supa
          .from('dette_produits')
          .select('*')
          .eq('dette_id', dette.id);
      _produitsParDette[dette.id] =
          (produits as List).map((p) => DetteProduit.fromMap(p)).toList();

      final paiements = await _supa
          .from('paiements')
          .select()
          .eq('dette_id', dette.id)
          .order('date', ascending: false);
      _paiementsParDette[dette.id] =
          (paiements as List).map((p) => Paiement.fromMap(p)).toList();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.debiteur.nom),
        backgroundColor: green,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Carte récapitulative
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Column(
              children: [
                Text(
                  'Solde total dû : ${f(widget.debiteur.soldeTotal)}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w900, color: red),
                ),
                const SizedBox(height: 8),
                Text(
                    'Taux de remboursement : ${(widget.debiteur.pctTotal * 100).toStringAsFixed(0)}%'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Liste des dettes
          ...widget.debiteur.dettes.map((dette) {
            final produits = _produitsParDette[dette.id] ?? [];
            final paiements = _paiementsParDette[dette.id] ?? [];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: dette.enRetard ? red.withOpacity(0.3) : greyMid,
                    width: dette.enRetard ? 1.5 : 0.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Dette du ${DateFormat('dd/MM/yyyy').format(dette.createdAt)}',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: cfg(dette).bg,
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            '${cfg(dette).emoji} ${cfg(dette).label}',
                            style: TextStyle(fontSize: 11, color: cfg(dette).color),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Montant : ${f(dette.montantInitial)}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('Remboursé : ${f(dette.montantRembourse)}'),
                    if (dette.echeance != null)
                      Row(
                        children: [
                          const Icon(Icons.event, size: 14, color: textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Échéance : ${DateFormat('dd/MM/yyyy').format(dette.echeance!)}',
                            style: TextStyle(
                                color: dette.enRetard ? red : textMuted,
                                fontWeight:
                                    dette.enRetard ? FontWeight.w700 : FontWeight.normal),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: dette.pct,
                        minHeight: 6,
                        backgroundColor: greyMid,
                        valueColor: const AlwaysStoppedAnimation<Color>(green),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Produits
                    if (produits.isNotEmpty) ...[
                      const Text('🛒 Produits :',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...produits.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                if (p.imageUrl != null && p.imageUrl!.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      p.imageUrl!,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image, size: 20),
                                    ),
                                  )
                                else
                                  const Icon(Icons.shopping_bag, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                    child: Text('${p.productName} (${p.quantite}x)')),
                                Text('${f(p.prixUnitaire * p.quantite)} F'),
                              ],
                            ),
                          )),
                      const SizedBox(height: 8),
                    ],

                    // Paiements reçus
                    if (paiements.isNotEmpty) ...[
                      const Text('💳 Paiements reçus :',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      ...paiements.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    '${DateFormat('dd/MM/yyyy').format(p.date)} · ${p.modePaiement}'),
                                Text('+${f(p.montant)} F',
                                    style: const TextStyle(
                                        color: green, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}