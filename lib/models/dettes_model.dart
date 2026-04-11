// ══════════════════════════════════════════════════════════════
//  MODÈLE : Dette + Paiement
//  Utilisé à la fois par SQLite local et Supabase cloud
// ══════════════════════════════════════════════════════════════

class Paiement {
  final String? id;          // UUID Supabase
  final String detteId;
  final double montant;
  final DateTime date;
  final String? note;
  bool syncCloud;            // true = déjà envoyé au cloud

  Paiement({
    this.id,
    required this.detteId,
    required this.montant,
    required this.date,
    this.note,
    this.syncCloud = false,
  });

  // ── Depuis SQLite (Map local)
  factory Paiement.fromMap(Map<String, dynamic> m) => Paiement(
    id:         m['id'],
    detteId:    m['dette_id'],
    montant:    (m['montant'] as num).toDouble(),
    date:       DateTime.parse(m['date']),
    note:       m['note'],
    syncCloud:  (m['sync_cloud'] as int?) == 1,
  );

  // ── Vers SQLite
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'dette_id':   detteId,
    'montant':    montant,
    'date':       date.toIso8601String(),
    'note':       note,
    'sync_cloud': syncCloud ? 1 : 0,
  };

  // ── Vers Supabase (JSON)
  Map<String, dynamic> toCloud(String commercantId) => {
    'id':            id,
    'dette_id':      detteId,
    'commercant_id': commercantId,
    'montant':       montant,
    'date':          date.toIso8601String(),
    'note':          note,
  };

  // ── Depuis Supabase
  factory Paiement.fromCloud(Map<String, dynamic> m) => Paiement(
    id:         m['id'],
    detteId:    m['dette_id'],
    montant:    (m['montant'] as num).toDouble(),
    date:       DateTime.parse(m['date']),
    note:       m['note'],
    syncCloud:  true,
  );
}

// ──────────────────────────────────────────────────────────────

class Dette {
  final String? id;           // UUID Supabase / clé locale
  String nomDebiteur;
  String telephone;
  double montantInitial;      // Montant total emprunté
  double montantRembourse;    // Cumulé des paiements
  DateTime dateDebut;
  int dureeJours;             // Durée accordée en jours
  String? creancier;          // Nom du créancier (si dette envers quelqu'un)
  String statut;              // 'en_cours' | 'rembourse' | 'en_retard'
  bool syncCloud;
  List<Paiement> paiements;

  Dette({
    this.id,
    required this.nomDebiteur,
    required this.telephone,
    required this.montantInitial,
    this.montantRembourse = 0,
    required this.dateDebut,
    required this.dureeJours,
    this.creancier,
    this.statut = 'en_cours',
    this.syncCloud = false,
    this.paiements = const [],
  });

  // ── Calculs dérivés
  double get montantRestant => (montantInitial - montantRembourse).clamp(0, double.infinity);
  double get pourcentageRembourse => montantInitial > 0 ? (montantRembourse / montantInitial).clamp(0, 1) : 0;
  DateTime get dateEcheance => dateDebut.add(Duration(days: dureeJours));
  int get joursRestants => dateEcheance.difference(DateTime.now()).inDays;
  bool get estEchu => joursRestants < 0 && montantRestant > 0;
  bool get estRembourse => montantRestant <= 0;

  String get statutCalcule {
    if (estRembourse) return 'rembourse';
    if (estEchu)      return 'en_retard';
    return 'en_cours';
  }

  // ── Depuis SQLite
  factory Dette.fromMap(Map<String, dynamic> m) => Dette(
    id:                 m['id']?.toString(),
    nomDebiteur:        m['nom_debiteur'],
    telephone:          m['telephone'] ?? '',
    montantInitial:     (m['montant_initial'] as num).toDouble(),
    montantRembourse:   (m['montant_rembourse'] as num? ?? 0).toDouble(),
    dateDebut:          DateTime.parse(m['date_debut']),
    dureeJours:         m['duree_jours'] as int,
    creancier:          m['creancier'],
    statut:             m['statut'] ?? 'en_cours',
    syncCloud:          (m['sync_cloud'] as int?) == 1,
  );

  // ── Vers SQLite
  Map<String, dynamic> toMap() => {
    if (id != null) 'id': id,
    'nom_debiteur':      nomDebiteur,
    'telephone':         telephone,
    'montant_initial':   montantInitial,
    'montant_rembourse': montantRembourse,
    'date_debut':        dateDebut.toIso8601String(),
    'duree_jours':       dureeJours,
    'creancier':         creancier,
    'statut':            statutCalcule,
    'sync_cloud':        syncCloud ? 1 : 0,
  };

  // ── Vers Supabase
  Map<String, dynamic> toCloud(String commercantId) => {
    'id':                id,
    'commercant_id':     commercantId,
    'nom_debiteur':      nomDebiteur,
    'telephone':         telephone,
    'montant_initial':   montantInitial,
    'montant_rembourse': montantRembourse,
    'date_debut':        dateDebut.toIso8601String(),
    'duree_jours':       dureeJours,
    'creancier':         creancier,
    'statut':            statutCalcule,
  };

  // ── Depuis Supabase
  factory Dette.fromCloud(Map<String, dynamic> m) => Dette(
    id:                 m['id'],
    nomDebiteur:        m['nom_debiteur'],
    telephone:          m['telephone'] ?? '',
    montantInitial:     (m['montant_initial'] as num).toDouble(),
    montantRembourse:   (m['montant_rembourse'] as num? ?? 0).toDouble(),
    dateDebut:          DateTime.parse(m['date_debut']),
    dureeJours:         m['duree_jours'] as int,
    creancier:          m['creancier'],
    statut:             m['statut'] ?? 'en_cours',
    syncCloud:          true,
  );

  Dette copyWith({
    double? montantRembourse,
    String? statut,
    List<Paiement>? paiements,
  }) => Dette(
    id:                id,
    nomDebiteur:       nomDebiteur,
    telephone:         telephone,
    montantInitial:    montantInitial,
    montantRembourse:  montantRembourse ?? this.montantRembourse,
    dateDebut:         dateDebut,
    dureeJours:        dureeJours,
    creancier:         creancier,
    statut:            statut ?? this.statut,
    syncCloud:         syncCloud,
    paiements:         paiements ?? this.paiements,
  );
}