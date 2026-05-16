import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// ========== COULEURS PUBLIQUES (sans underscore) ==========
const Color green = Color(0xFF0F6E56);
const Color greenLight = Color(0xFFE1F5EE);
const Color red = Color(0xFFA32D2D);
const Color redLight = Color(0xFFFCEBEB);
const Color amber = Color(0xFFF59E0B);
const Color amberLight = Color(0xFFFAEEDA);
const Color grey = Color(0xFFF4F4F2);
const Color greyMid = Color(0xFFE8E8E5);
const Color textMuted = Color(0xFF6B7280);

// ========== FORMATAGE ==========
final NumberFormat _numFmt = NumberFormat('#,###', 'fr_FR');
String f(num n) => '${_numFmt.format(n)} F';

// ========== MODÈLE DETTE ==========
class Dette {
  final int id, commercantId, debiteurId;
  final String nomDebiteur, statut;
  final String? telephone, quartier;
  final double montantInitial, montantRembourse;
  final DateTime? echeance;
  final DateTime createdAt;

  Dette({
    required this.id,
    required this.commercantId,
    required this.debiteurId,
    required this.nomDebiteur,
    required this.statut,
    this.telephone,
    this.quartier,
    required this.montantInitial,
    required this.montantRembourse,
    this.echeance,
    required this.createdAt,
  });

  factory Dette.fromMap(Map<String, dynamic> m,
      {String? nomDebiteur, String? telephone, String? quartier}) {
    return Dette(
      id: (m['id'] as num).toInt(),
      commercantId: (m['commercant_id'] as num).toInt(),
      debiteurId: (m['debiteur_id'] as num).toInt(),
      nomDebiteur: nomDebiteur ?? m['nom_debiteur'] as String? ?? '',
      statut: m['statut'] as String,
      telephone: telephone,
      quartier: quartier,
      montantInitial: (m['montant_initial'] as num).toDouble(),
      montantRembourse: (m['montant_rembourse'] as num).toDouble(),
      echeance: m['echeance'] != null
          ? DateTime.tryParse(m['echeance'] as String)
          : null,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  double get solde =>
      (montantInitial - montantRembourse).clamp(0, double.infinity);
  double get pct =>
      montantInitial > 0
          ? (montantRembourse / montantInitial).clamp(0.0, 1.0)
          : 0.0;
  bool get enRetard =>
      echeance != null &&
      echeance!.isBefore(DateTime.now()) &&
      statut != 'solde';
}

// ========== DÉBITEUR AVEC DETTES ==========
class DebiteurAvecDettes {
  final int id;
  final String nom;
  final String? telephone, quartier;
  final List<Dette> dettes;

  DebiteurAvecDettes({
    required this.id,
    required this.nom,
    this.telephone,
    this.quartier,
    required this.dettes,
  });

  double get totalInitial => dettes.fold(0, (s, d) => s + d.montantInitial);
  double get totalRembourse =>
      dettes.fold(0, (s, d) => s + d.montantRembourse);
  double get soldeTotal => totalInitial - totalRembourse;
  double get pctTotal =>
      totalInitial > 0 ? totalRembourse / totalInitial : 0.0;

  String get statutGlobal {
    if (dettes.every((d) => d.statut == 'solde')) return 'solde';
    if (dettes.any((d) => d.enRetard)) return 'retard';
    return 'en_cours';
  }
  bool get enRetardGlobal => statutGlobal == 'retard';
}

// ========== PRODUIT D'UNE DETTE ==========
class DetteProduit {
  final int id, detteId;
  final String? productId;
  final String productName;
  final int quantite;
  final double prixUnitaire;
  final String? imageUrl;

  DetteProduit({
    required this.id,
    required this.detteId,
    this.productId,
    required this.productName,
    required this.quantite,
    required this.prixUnitaire,
    this.imageUrl,
  });

  factory DetteProduit.fromMap(Map<String, dynamic> m) => DetteProduit(
        id: (m['id'] as num).toInt(),
        detteId: (m['dette_id'] as num).toInt(),
        productId: m['product_id'] as String?,
        productName: m['product_name'] as String? ?? 'Produit inconnu',
        quantite: (m['quantite'] as num).toInt(),
        prixUnitaire: (m['prix_unitaire'] as num).toDouble(),
        imageUrl: m['image_url'] as String?,
      );
}

// ========== PAIEMENT ==========
class Paiement {
  final int id, detteId, commercantId;
  final double montant;
  final String modePaiement;
  final DateTime date, createdAt;

  Paiement({
    required this.id,
    required this.detteId,
    required this.commercantId,
    required this.montant,
    required this.modePaiement,
    required this.date,
    required this.createdAt,
  });

  factory Paiement.fromMap(Map<String, dynamic> m) => Paiement(
        id: (m['id'] as num).toInt(),
        detteId: (m['dette_id'] as num).toInt(),
        commercantId: (m['commercant_id'] as num).toInt(),
        montant: (m['montant'] as num).toDouble(),
        modePaiement: m['mode_paiement'] as String,
        date: DateTime.parse(m['date'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

// ========== UTILITAIRES ==========
class _Cfg {
  final String label, emoji;
  final Color bg, color;
  const _Cfg(this.label, this.emoji, this.bg, this.color);
}

_Cfg cfg(Dette d) {
  if (d.statut == 'solde') return _Cfg('Soldé', '✅', greenLight, green);
  if (d.enRetard) return _Cfg('En retard', '⚠️', redLight, red);
  return _Cfg('En cours', '⏳', amberLight, amber);
}

Color aColor(String nom) {
  if (nom.isEmpty) return green;
  const List<Color> c = [
    green,
    Color(0xFF1D4ED8),
    Color(0xFFA21CAF),
    Color(0xFFD97706),
    Color(0xFFDC2626)
  ];
  return c[nom.codeUnitAt(0) % c.length];
}

String ini(String nom) {
  if (nom.isEmpty) return '?';
  final p = nom.trim().split(' ');
  return p.length >= 2
      ? '${p[0][0]}${p[1][0]}'.toUpperCase()
      : nom.substring(0, nom.length >= 2 ? 2 : 1).toUpperCase();
}