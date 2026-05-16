import 'package:supabase_flutter/supabase_flutter.dart';

class EcheanceService {
  final supabase = Supabase.instance.client;

  Future<void> verifierEcheances() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final troisJours = today.add(const Duration(days: 3));

    // 1. Dettes (crédits clients) – le commerçant doit être payé
    // ✅ Correction : jointure avec debiteurs pour récupérer telephone et nom
    final dettes = await supabase
        .from('dettes')
        .select('''
          id,
          commercant_id,
          montant_initial,
          montant_rembourse,
          echeance,
          statut,
          debiteur_id,
          debiteurs!inner (
            nom,
            telephone,
            quartier
          )
        ''')
        .eq('statut', 'en_cours')
        .not('echeance', 'is', null);

    for (var d in dettes) {
      final echeance = DateTime.parse(d['echeance']);
      final solde = (d['montant_initial'] as num) - (d['montant_rembourse'] as num);
      // Récupération du nom et téléphone depuis la jointure
      final nomDebiteur = d['debiteurs']['nom'];
      final tel = d['debiteurs']['telephone'] ?? 'pas de téléphone';

      // 3 jours avant
      if (echeance.isAfter(today) && echeance.isBefore(troisJours.add(const Duration(days: 1)))) {
        await _envoyerNotification(
          commercantId: d['commercant_id'],
          titre: '⚠️ Échéance dans 3 jours',
          message: '$nomDebiteur (📞 $tel) doit vous rembourser $solde F CFA avant ${echeance.toLocal().toString().split(' ')[0]}.',
          type: 'rappel_echeance_dette',
          detteId: d['id'],
        );
      }
      // Dépassée
      else if (echeance.isBefore(today) && solde > 0) {
        await _envoyerNotification(
          commercantId: d['commercant_id'],
          titre: '❌ Dette impayée',
          message: '$nomDebiteur (📞 $tel) n’a pas payé sa dette de $solde F CFA échue le ${echeance.toLocal().toString().split(' ')[0]}.',
          type: 'echeance_depassee_dette',
          detteId: d['id'],
        );
      }
    }

    // 2. Créances (dettes envers les créanciers) – le commerçant doit payer
    // (Cette partie reste inchangée car elle utilise la table creanciers qui contient bien telephone)
    final creanciers = await supabase
        .from('creanciers')
        .select('id, commercant_id, nom, telephone, montant_initial, montant_rembourse, echeance')
        .eq('statut', 'en_cours')
        .not('echeance', 'is', null);

    for (var c in creanciers) {
      final echeance = DateTime.parse(c['echeance']);
      final solde = (c['montant_initial'] as num) - (c['montant_rembourse'] as num);
      final tel = c['telephone'] ?? 'pas de téléphone';

      if (echeance.isAfter(today) && echeance.isBefore(troisJours.add(const Duration(days: 1)))) {
        await _envoyerNotification(
          commercantId: c['commercant_id'],
          titre: '⚠️ Échéance créance dans 3 jours',
          message: 'Vous devez rembourser ${c['nom']} (📞 $tel) un montant de $solde F CFA avant ${echeance.toLocal().toString().split(' ')[0]}.',
          type: 'rappel_echeance_creance',
          creancierId: c['id'],
        );
      } else if (echeance.isBefore(today) && solde > 0) {
        await _envoyerNotification(
          commercantId: c['commercant_id'],
          titre: '❌ Créance impayée',
          message: 'Vous n’avez pas remboursé ${c['nom']} (📞 $tel) la somme de $solde F CFA échue le ${echeance.toLocal().toString().split(' ')[0]}.',
          type: 'echeance_depassee_creance',
          creancierId: c['id'],
        );
      }
    }
  }

  Future<void> _envoyerNotification({
    required int commercantId,
    required String titre,
    required String message,
    required String type,
    int? detteId,
    int? creancierId,
  }) async {
    // Éviter les doublons pour le même type et la même dette/creance aujourd’hui
    final todayStart = DateTime.now().toIso8601String().split('T')[0];
    final query = supabase
        .from('notifications')
        .select('id')
        .eq('commercant_id', commercantId)
        .eq('type', type)
        .eq('est_lu', false)
        .gte('created_at', todayStart);

    if (detteId != null) query.eq('dette_id', detteId);
    if (creancierId != null) query.eq('creancier_id', creancierId);

    final exists = await query.maybeSingle();
    if (exists == null) {
      await supabase.from('notifications').insert({
        'commercant_id': commercantId,
        'titre': titre,
        'message': message,
        'type': type,
        'dette_id': detteId,
        'creancier_id': creancierId,
        'est_lu': false,
        'created_at': DateTime.now().toIso8601String(),
      });
    }
  }
}