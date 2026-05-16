// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
//  FOURNISSEURS PAGE — Version Proximité + Comparaison
//  CORRECTIONS :
//  1. TabAlignment.fill remplacé par TabAlignment.start (isScrollable: true)
//  2. Overflow bottom sheets corrigé avec SingleChildScrollView
//  3. Column mainAxisSize.min dans tous les bottom sheets
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

import 'dart:math' show asin, cos, pi, sin, sqrt;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

// ══════════════════════════════════════════════════
//  COULEURS
// ══════════════════════════════════════════════════
class C {
  static const green      = Color(0xFF0F6E56);
  static const greenLight = Color(0xFFE1F5EE);
  static const greenDark  = Color(0xFF085041);
  static const amber      = Color(0xFFBA7517);
  static const amberLight = Color(0xFFFAEEDA);
  static const blue       = Color(0xFF185FA5);
  static const blueLight  = Color(0xFFE6F1FB);
  static const red        = Color(0xFFA32D2D);
  static const redLight   = Color(0xFFFCEBEB);
  static const orange     = Color(0xFFF97316);
  static const bg         = Color(0xFFF4F6F4);
  static const card       = Colors.white;
}

// ══════════════════════════════════════════════════
//  COORDONNÉES VILLES SÉNÉGAL (fallback si pas de GPS)
// ══════════════════════════════════════════════════
const Map<String, List<double>> _villesCoordsSnl = {
  'Dakar':       [14.6937, -17.4441],
  'Thiès':       [14.7886, -16.9260],
  'Saint-Louis': [16.0179, -16.4896],
  'Ziguinchor':  [12.5605, -16.2719],
  'Kaolack':     [14.1520, -16.0726],
  'Touba':       [14.8636, -15.8836],
  'Mbour':       [14.3788, -16.9627],
  'Diourbel':    [14.6492, -16.2317],
  'Rufisque':    [14.7155, -17.2728],
  'Pikine':      [14.7500, -17.3900],
};

// ══════════════════════════════════════════════════
//  MODÈLES
// ══════════════════════════════════════════════════

class Fournisseur {
  final String id;
  String nom;
  String telephone;
  String ville;
  String categorie;
  bool actif;
  double note;
  int nombreAvis;
  bool fiable;
  double? latitude;
  double? longitude;
  int rayonLivraison;
  bool visibleAnnuaire;
  List<Produit> produits;
  double? distanceKm;

  Fournisseur({
    required this.id,
    required this.nom,
    required this.telephone,
    this.ville = 'Dakar',
    this.categorie = 'Alimentaire',
    this.actif = true,
    this.note = 0,
    this.nombreAvis = 0,
    this.fiable = false,
    this.latitude,
    this.longitude,
    this.rayonLivraison = 10,
    this.visibleAnnuaire = true,
    this.produits = const [],
  });

  factory Fournisseur.fromMap(Map<String, dynamic> m) => Fournisseur(
    id:              m['id'],
    nom:             m['nom'] ?? 'Sans nom',
    telephone:       m['telephone'],
    ville:           m['ville'] ?? 'Dakar',
    categorie:       m['categorie'] ?? 'Alimentaire',
    actif:           m['actif'] ?? true,
    note:            (m['note'] as num?)?.toDouble() ?? 0,
    nombreAvis:      (m['nombre_avis'] as int?) ?? 0,
    fiable:          m['fiable'] ?? false,
    latitude:        (m['latitude'] as num?)?.toDouble(),
    longitude:       (m['longitude'] as num?)?.toDouble(),
    rayonLivraison:  (m['rayon_livraison'] as int?) ?? 10,
    visibleAnnuaire: m['visible_annuaire'] ?? true,
  );

  Map<String, dynamic> toMap(int commercantId) => {
    'id':               id,
    'commercant_id':    commercantId,
    'nom':              nom,
    'telephone':        telephone,
    'ville':            ville,
    'categorie':        categorie,
    'actif':            actif,
    'latitude':         latitude,
    'longitude':        longitude,
    'rayon_livraison':  rayonLivraison,
    'visible_annuaire': visibleAnnuaire,
  };

  bool get aPosition => latitude != null && longitude != null;
  int  get stockTotal => produits.fold(0, (s, p) => s + p.stock);
}

class Produit {
  final String id;
  String nom;
  String description;
  String categorie;
  double prix;
  String unite;
  int stock;

  Produit({
    required this.id,
    required this.nom,
    this.description = '',
    this.categorie = 'Alimentaire',
    required this.prix,
    this.unite = 'pièce',
    this.stock = 0,
  });

  factory Produit.fromMap(Map<String, dynamic> m) => Produit(
    id:          m['id'],
    nom:         m['nom'],
    description: m['description'] ?? '',
    categorie:   m['categorie'] ?? 'Alimentaire',
    prix:        (m['prix'] as num?)?.toDouble() ?? 0,
    unite:       m['unite'] ?? 'pièce',
    stock:       (m['stock'] as int?) ?? 0,
  );

  Map<String, dynamic> toMap(String fournisseurId) => {
    'id':             id,
    'fournisseur_id': fournisseurId,
    'nom':            nom,
    'description':    description,
    'categorie':      categorie,
    'prix':           prix,
    'unite':          unite,
    'stock':          stock,
  };
}

class Commande {
  final String id;
  final String fournisseurId;
  final String fournisseurNom;
  final String produitId;
  final String produitNom;
  final int quantite;
  final double prixUnitaire;
  final double prixTotal;
  final String unite;
  String statut;
  final DateTime dateCommande;

  Commande({
    required this.id,
    required this.fournisseurId,
    required this.fournisseurNom,
    required this.produitId,
    required this.produitNom,
    required this.quantite,
    required this.prixUnitaire,
    required this.prixTotal,
    required this.unite,
    this.statut = 'en_attente',
    required this.dateCommande,
  });

  factory Commande.fromMap(Map<String, dynamic> m) => Commande(
    id:             m['id'],
    fournisseurId:  m['fournisseur_id'] ?? '',
    fournisseurNom: m['fournisseur_nom'] ?? '',
    produitId:      m['produit_id'] ?? '',
    produitNom:     m['produit_nom'] ?? '',
    quantite:       (m['quantite'] as int?) ?? 1,
    prixUnitaire:   (m['prix_unitaire'] as num?)?.toDouble() ?? 0,
    prixTotal:      (m['prix_total'] as num?)?.toDouble() ?? 0,
    unite:          m['unite'] ?? 'pièce',
    statut:         m['statut'] ?? 'en_attente',
    dateCommande:   DateTime.parse(m['date_commande']),
  );
}

// ══════════════════════════════════════════════════
//  PAGE PRINCIPALE
// ══════════════════════════════════════════════════
class FournisseursPage extends StatefulWidget {
  final int    commercantId;
  final String nomBoutique;

  const FournisseursPage({
    super.key,
    required this.commercantId,
    required this.nomBoutique,
  });

  @override
  State<FournisseursPage> createState() => _FournisseursPageState();
}

class _FournisseursPageState extends State<FournisseursPage>
    with SingleTickerProviderStateMixin {

  late TabController _tabs;
  List<Fournisseur> _fournisseurs = [];
  List<Commande>    _commandes    = [];
  bool   _loading          = true;
  bool   _gpsLoading       = false;
  String _recherche        = '';
  String _filtreCategorie  = 'Tous';

  double? _myLat;
  double? _myLng;
  double  _rayonFiltreKm   = 10.0;
  bool    _trierParDistance = false;

  static const List<String> _categories = [
    'Tous','Alimentaire','Boissons','Hygiène','Autre'
  ];
  static const List<String> _unites = [
    'pièce','kg','g','litre','ml','sac','carton','boîte','palette','lot'
  ];
  static const List<double> _rayons = [1, 3, 5, 10, 20, 50];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _chargerTout();
    _obtenirPosition();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  // ──────────────────────────────────────────────
  //  GPS
  // ──────────────────────────────────────────────

  Future<void> _obtenirPosition() async {
    setState(() => _gpsLoading = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) { setState(() => _gpsLoading = false); return; }

      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) {
          setState(() => _gpsLoading = false); return;
        }
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() => _gpsLoading = false); return;
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      setState(() {
        _myLat = pos.latitude;
        _myLng = pos.longitude;
        _gpsLoading = false;
        _calculerDistances();
      });
    } catch (_) {
      setState(() => _gpsLoading = false);
    }
  }

  double _haversine(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
        sin(dLon / 2) * sin(dLon / 2);
    return R * 2 * asin(sqrt(a));
  }

  void _calculerDistances() {
    if (_myLat == null || _myLng == null) return;
    for (final f in _fournisseurs) {
      if (f.aPosition) {
        f.distanceKm = _haversine(_myLat!, _myLng!, f.latitude!, f.longitude!);
      } else {
        final coords = _villesCoordsSnl[f.ville];
        if (coords != null) {
          f.distanceKm = _haversine(_myLat!, _myLng!, coords[0], coords[1]);
        }
      }
    }
  }

  // ──────────────────────────────────────────────
  //  CHARGEMENT SUPABASE
  // ──────────────────────────────────────────────

  Future<void> _chargerTout() async {
    setState(() => _loading = true);
    await Future.wait([_chargerFournisseurs(), _chargerCommandes()]);
    _calculerDistances();
    setState(() => _loading = false);
  }

  Future<void> _chargerFournisseurs() async {
    try {
      final rows = await _sb
          .from('fournisseurs')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('cree_le', ascending: false);

      final liste = <Fournisseur>[];
      for (final r in rows as List) {
        final f = Fournisseur.fromMap(r);
        final prods = await _sb
            .from('produits_fournisseur')
            .select()
            .eq('fournisseur_id', f.id)
            .order('nom');
        f.produits = (prods as List).map((p) => Produit.fromMap(p)).toList();
        liste.add(f);
      }
      _fournisseurs = liste;
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  Future<void> _chargerCommandes() async {
    try {
      final rows = await _sb
          .from('commandes_fournisseur')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('date_commande', ascending: false);
      _commandes = (rows as List).map((r) => Commande.fromMap(r)).toList();
    } catch (e) {
      _snack('Erreur commandes : $e', ok: false);
    }
  }

  // ──────────────────────────────────────────────
  //  ÉCRITURE SUPABASE — FOURNISSEUR
  // ──────────────────────────────────────────────

  Future<void> _ajouterFournisseur({
    required String telephone,
    String nom = '',
    String ville = 'Dakar',
    String categorie = 'Alimentaire',
    double? latitude,
    double? longitude,
    int rayonLivraison = 10,
  }) async {
    try {
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      final nomFinal = nom.isEmpty ? 'Fournisseur $telephone' : nom;

      double? lat = latitude;
      double? lng = longitude;
      if (lat == null && _villesCoordsSnl.containsKey(ville)) {
        lat = _villesCoordsSnl[ville]![0];
        lng = _villesCoordsSnl[ville]![1];
      }

      await _sb.from('fournisseurs').insert({
        'id':               id,
        'commercant_id':    widget.commercantId,
        'nom':              nomFinal,
        'telephone':        telephone,
        'ville':            ville,
        'categorie':        categorie,
        'actif':            true,
        'latitude':         lat,
        'longitude':        lng,
        'rayon_livraison':  rayonLivraison,
        'visible_annuaire': true,
      });
      await _chargerFournisseurs();
      _calculerDistances();
      setState(() {});
      _snack('✅ $nomFinal ajouté !');
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  Future<void> _supprimerFournisseur(Fournisseur f) async {
    try {
      await _sb.from('fournisseurs').delete().eq('id', f.id);
      await _chargerFournisseurs();
      setState(() {});
      _snack('Fournisseur supprimé');
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  // ──────────────────────────────────────────────
  //  ÉCRITURE SUPABASE — PRODUIT
  // ──────────────────────────────────────────────

  Future<void> _ajouterProduit(String fournisseurId, Produit p) async {
    try {
      await _sb.from('produits_fournisseur').insert(p.toMap(fournisseurId));
      await _chargerFournisseurs();
      setState(() {});
      _snack('✅ ${p.nom} ajouté !');
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  Future<void> _modifierStock(Produit p, int nouveauStock) async {
    try {
      await _sb.from('produits_fournisseur')
          .update({'stock': nouveauStock})
          .eq('id', p.id);
      await _chargerFournisseurs();
      setState(() {});
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  Future<void> _supprimerProduit(String produitId) async {
    try {
      await _sb.from('produits_fournisseur').delete().eq('id', produitId);
      await _chargerFournisseurs();
      setState(() {});
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  // ──────────────────────────────────────────────
  //  COMMANDE
  // ──────────────────────────────────────────────

  Future<void> _commander(Fournisseur f, Produit p, int quantite) async {
    try {
      final total = p.prix * quantite;
      await _sb.from('commandes_fournisseur').insert({
        'id':              DateTime.now().millisecondsSinceEpoch.toString(),
        'commercant_id':   widget.commercantId,
        'fournisseur_id':  f.id,
        'fournisseur_nom': f.nom,
        'produit_id':      p.id,
        'produit_nom':     p.nom,
        'quantite':        quantite,
        'prix_unitaire':   p.prix,
        'prix_total':      total,
        'unite':           p.unite,
        'statut':          'en_attente',
        'date_commande':   DateTime.now().toIso8601String(),
      });
      final newStock = (p.stock - quantite).clamp(0, 99999);
      await _modifierStock(p, newStock);
      await _chargerCommandes();
      setState(() {});
      _snack('✅ Commande envoyée — ${_fmt(total)} FCFA');
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  Future<void> _changerStatut(Commande c, String statut) async {
    try {
      await _sb.from('commandes_fournisseur')
          .update({'statut': statut})
          .eq('id', c.id);
      await _chargerCommandes();
      setState(() {});
    } catch (e) {
      _snack('Erreur : $e', ok: false);
    }
  }

  // ──────────────────────────────────────────────
  //  LISTES FILTRÉES
  // ──────────────────────────────────────────────

  List<Fournisseur> get _filtres => _fournisseurs.where((f) {
    final matchCat    = _filtreCategorie == 'Tous' || f.categorie == _filtreCategorie;
    final matchSearch = _recherche.isEmpty ||
        f.nom.toLowerCase().contains(_recherche.toLowerCase()) ||
        f.telephone.contains(_recherche);
    return matchCat && matchSearch;
  }).toList();

  List<Fournisseur> _filtresProximite({bool filtrerRayon = false}) {
    var liste = _filtres.toList();
    if (filtrerRayon && _myLat != null) {
      liste = liste.where((f) =>
          f.distanceKm == null || f.distanceKm! <= _rayonFiltreKm).toList();
    }
    liste.sort((a, b) {
      if (a.distanceKm == null && b.distanceKm == null) return 0;
      if (a.distanceKm == null) return 1;
      if (b.distanceKm == null) return -1;
      return a.distanceKm!.compareTo(b.distanceKm!);
    });
    return liste;
  }

  List<MapEntry<Fournisseur, Produit>> get _tousProduits {
    final liste  = <MapEntry<Fournisseur, Produit>>[];
    final source = _trierParDistance ? _filtresProximite() : _filtres;
    for (final f in source) {
      for (final p in f.produits) {
        if (_recherche.isEmpty ||
            p.nom.toLowerCase().contains(_recherche.toLowerCase())) {
          liste.add(MapEntry(f, p));
        }
      }
    }
    return liste;
  }

  Map<String, List<MapEntry<Fournisseur, Produit>>> get _produitsGroupes {
    final map = <String, List<MapEntry<Fournisseur, Produit>>>{};
    for (final entry in _tousProduits) {
      final key = entry.value.nom.toLowerCase().trim();
      map.putIfAbsent(key, () => []).add(entry);
    }
    return Map.fromEntries(map.entries.where((e) => e.value.length > 1));
  }

  // ══════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: _appBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.green))
          : Column(children: [
              _barreRecherche(),
              _barreCategories(),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _vueProximite(),
                    _vueCatalogue(),
                    _vueFournisseurs(),
                    _vueCommandes(),
                  ],
                ),
              ),
            ]),
      floatingActionButton: _fab(),
    );
  }

  // ─────────────────────────────────────
  //  APP BAR — CORRECTION : isScrollable: true + TabAlignment.start
  // ─────────────────────────────────────
  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: C.green,
    foregroundColor: Colors.white,
    elevation: 0,
    titleSpacing: 12,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Fournisseurs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        if (_myLat != null)
          const Row(children: [
            Icon(Icons.my_location, size: 10, color: Colors.white70),
            SizedBox(width: 3),
            Text('GPS actif',
                style: TextStyle(fontSize: 10, color: Colors.white70)),
          ])
        else if (_gpsLoading)
          const Text('Localisation…',
              style: TextStyle(fontSize: 10, color: Colors.white54))
        else
          GestureDetector(
            onTap: _obtenirPosition,
            child: const Row(children: [
              Icon(Icons.location_off, size: 10, color: Colors.white54),
              SizedBox(width: 3),
              Text('Activer GPS',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white54,
                      decoration: TextDecoration.underline,
                      decorationColor: Colors.white54)),
            ]),
          ),
      ],
    ),
    actions: [
      IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _chargerTout,
          tooltip: 'Rafraîchir'),
    ],
    bottom: TabBar(
      controller: _tabs,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white54,
      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      // ✅ CORRECTION 1 : isScrollable: true est compatible avec TabAlignment.start
      // TabAlignment.fill est UNIQUEMENT valide avec isScrollable: false
      isScrollable: false,
      tabAlignment: TabAlignment.fill,
      tabs: [
        Tab(
          icon: const Icon(Icons.near_me_rounded, size: 19),
          text: 'Proximité',
          iconMargin: const EdgeInsets.only(bottom: 2),
        ),
        Tab(
          icon: const Icon(Icons.grid_view_rounded, size: 19),
          text: 'Catalogue',
          iconMargin: const EdgeInsets.only(bottom: 2),
        ),
        Tab(
          icon: Badge(
            label: Text('${_fournisseurs.length}',
                style: const TextStyle(fontSize: 9)),
            isLabelVisible: _fournisseurs.isNotEmpty,
            child: const Icon(Icons.people, size: 19),
          ),
          text: 'Fournisseurs',
          iconMargin: const EdgeInsets.only(bottom: 2),
        ),
        Tab(
          icon: Badge(
            label: Text(
                '${_commandes.where((c) => c.statut == 'en_attente').length}',
                style: const TextStyle(fontSize: 9)),
            isLabelVisible: _commandes.any((c) => c.statut == 'en_attente'),
            child: const Icon(Icons.receipt_long, size: 19),
          ),
          text: 'Commandes',
          iconMargin: const EdgeInsets.only(bottom: 2),
        ),
      ],
    ),
  );

  // ─────────────────────────────────────
  //  BARRE DE RECHERCHE
  // ─────────────────────────────────────
  Widget _barreRecherche() => Container(
    color: C.green,
    padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _recherche = v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Rechercher fournisseur, produit…',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const Icon(Icons.search, color: Colors.white70, size: 20),
          suffixIcon: _recherche.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white70, size: 18),
                  onPressed: () => setState(() => _recherche = ''))
              : null,
        ),
      ),
    ),
  );

  // ─────────────────────────────────────
  //  BARRE CATÉGORIES
  // ─────────────────────────────────────
  Widget _barreCategories() => Container(
    color: Colors.white,
    height: 42,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      itemCount: _categories.length,
      itemBuilder: (_, i) {
        final sel = _filtreCategorie == _categories[i];
        return GestureDetector(
          onTap: () => setState(() => _filtreCategorie = _categories[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 7),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? C.green : C.bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: sel ? C.green : Colors.grey.shade300, width: 0.8),
            ),
            child: Text(_categories[i],
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w700 : FontWeight.normal,
                    color: sel ? Colors.white : Colors.black87)),
          ),
        );
      },
    ),
  );

  // ══════════════════════════════════════════════════
  //  VUE 1 : PROXIMITÉ
  // ══════════════════════════════════════════════════
  Widget _vueProximite() {
    final liste = _filtresProximite(filtrerRayon: true);

    return RefreshIndicator(
      color: C.green,
      onRefresh: _chargerTout,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _bandeauRayon()),
          if (_produitsGroupes.isNotEmpty)
            SliverToBoxAdapter(child: _bandeauComparaison()),
          if (_myLat == null && !_gpsLoading)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.amberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: C.amber.withOpacity(0.4)),
                ),
                child: Row(children: [
                  const Text('📍', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('GPS non activé',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: C.amber,
                                fontSize: 13)),
                        const Text(
                            'Distances estimées selon la ville du fournisseur',
                            style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _obtenirPosition,
                    child: const Text('Activer',
                        style: TextStyle(
                            color: C.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            ),
          if (liste.isEmpty)
            SliverFillRemaining(
              child: _empty(
                emoji: '🗺️',
                titre: 'Aucun fournisseur dans ce rayon',
                sous: 'Élargissez le rayon ou ajoutez un fournisseur',
                boutonLabel: '+ Ajouter un fournisseur',
                onBouton: () {
                  _tabs.animateTo(2);
                  _ouvrirAjoutFournisseur();
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _carteFournisseurProximite(liste[i]),
                  childCount: liste.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _bandeauRayon() => Container(
    margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.withOpacity(0.15)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.radar, color: C.green, size: 18),
          const SizedBox(width: 8),
          Text('Rayon de recherche : ${_rayonFiltreKm.toStringAsFixed(0)} km',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: C.greenDark)),
          const Spacer(),
          if (_gpsLoading)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: C.green))
          else if (_myLat != null)
            const Row(children: [
              Icon(Icons.my_location, color: C.green, size: 14),
              SizedBox(width: 4),
              Text('GPS actif',
                  style: TextStyle(color: C.green, fontSize: 11)),
            ]),
        ]),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: C.green,
            inactiveTrackColor: C.greenLight,
            thumbColor: C.green,
            overlayColor: C.green.withOpacity(0.1),
            trackHeight: 4,
          ),
          child: Slider(
            value: _rayonFiltreKm,
            min: 1,
            max: 50,
            divisions: 10,
            onChanged: (v) => setState(() => _rayonFiltreKm = v),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _rayons.map((r) => GestureDetector(
            onTap: () => setState(() => _rayonFiltreKm = r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _rayonFiltreKm == r ? C.green : C.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${r.toStringAsFixed(0)}km',
                  style: TextStyle(
                      fontSize: 10,
                      color: _rayonFiltreKm == r ? Colors.white : Colors.grey,
                      fontWeight: FontWeight.w600)),
            ),
          )).toList(),
        ),
      ],
    ),
  );

  Widget _bandeauComparaison() => GestureDetector(
    onTap: _ouvrirComparaison,
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF185FA5), Color(0xFF0F4E8C)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10)),
          child: const Text('⚖️', style: TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            const Text('Comparer les prix',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14)),
            Text(
                '${_produitsGroupes.length} produit(s) disponible(s) chez plusieurs fournisseurs',
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ),
        const Icon(Icons.chevron_right, color: Colors.white70),
      ]),
    ),
  );

  Widget _carteFournisseurProximite(Fournisseur f) {
    final distance = f.distanceKm;
    final proche   = distance != null && distance <= 5;
    final nbProd   = f.produits.length;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: proche
                ? C.green.withOpacity(0.3)
                : Colors.grey.withOpacity(0.15)),
        boxShadow: proche
            ? [BoxShadow(
                color: C.green.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 2))]
            : null,
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: proche ? C.greenLight : C.bg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Center(
                  child: Text(_emojiCat(f.categorie),
                      style: const TextStyle(fontSize: 28))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Row(children: [
                  Expanded(
                    child: Text(f.nom,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  if (f.fiable) ...[
                    const Text('🏅', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 2),
                  ],
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.phone, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(f.telephone,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.location_on, size: 12, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(f.ville,
                      style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              if (distance != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: proche ? C.greenLight : C.bg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: proche
                            ? C.green.withOpacity(0.4)
                            : Colors.grey.shade300,
                        width: 0.8),
                  ),
                  child: Column(children: [
                    Icon(Icons.near_me,
                        size: 14, color: proche ? C.green : Colors.grey),
                    Text(
                      distance < 1
                          ? '${(distance * 1000).toStringAsFixed(0)}m'
                          : '${distance.toStringAsFixed(1)}km',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: proche ? C.green : Colors.black87),
                    ),
                    if (proche)
                      const Text('Proche',
                          style: TextStyle(
                              fontSize: 9,
                              color: C.green,
                              fontWeight: FontWeight.bold)),
                  ]),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                      color: C.bg, borderRadius: BorderRadius.circular(8)),
                  child: const Text('? km',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ],
              const SizedBox(height: 6),
              Text('$nbProd produit(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ]),
          ]),
        ),
        if (f.produits.isNotEmpty) ...[
          const Divider(height: 1, indent: 14, endIndent: 14),
          const SizedBox(height: 8),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: f.produits.length,
              itemBuilder: (_, i) => _miniProduitCard(f, f.produits[i]),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: C.bg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: const Center(
                child: Text('Aucun produit enregistré',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 12),
          child: Row(children: [
            Expanded(
              child: _btnOutline(Icons.phone, 'Appeler', Colors.blue,
                  () => _snack('📞 ${f.telephone}')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _btnOutline(
                  Icons.shopping_cart_outlined, 'Voir produits', C.green,
                  () => _ouvrirGestionProduits(f)),
            ),
          ]),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  //  COMPARAISON PRIX
  // ══════════════════════════════════════════════════
  void _ouvrirComparaison() {
    final groupes = _produitsGroupes;
    if (groupes.isEmpty) { _snack('Aucun produit commun', ok: false); return; }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (ctx, sc) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(children: [
            _handle(),
            const SizedBox(height: 14),
            const Row(children: [
              Text('⚖️', style: TextStyle(fontSize: 24)),
              SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Comparaison des prix',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: C.blue)),
                Text('Même produit, plusieurs fournisseurs',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ]),
            ]),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: sc,
                children: groupes.entries.map((e) {
                  final entries = e.value;
                  entries.sort(
                      (a, b) => a.value.prix.compareTo(b.value.prix));
                  final meilleurPrix = entries.first.value.prix;
                  return _carteComparaison(entries, meilleurPrix);
                }).toList(),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _carteComparaison(
      List<MapEntry<Fournisseur, Produit>> entries, double meilleurPrix) {
    final nomProduit = entries.first.value.nom;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(children: [
              Text(_emojiCat(entries.first.value.categorie),
                  style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nomProduit,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 15)),
                    Text('${entries.length} fournisseurs · trié par prix',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          ...entries.asMap().entries.map((e) {
            final idx    = e.key;
            final f      = e.value.key;
            final p      = e.value.value;
            final isBest = p.prix == meilleurPrix;
            final surplus =
                ((p.prix - meilleurPrix) / meilleurPrix * 100);

            return Container(
              color: isBest
                  ? C.greenLight.withOpacity(0.5)
                  : Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: isBest ? C.green : C.bg,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(isBest ? '🥇' : '${idx + 1}',
                          style: TextStyle(
                              fontSize: isBest ? 14 : 11,
                              color: isBest ? Colors.white : Colors.grey,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(f.nom,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isBest ? C.greenDark : Colors.black87)),
                        Row(children: [
                          if (f.distanceKm != null) ...[
                            const Icon(Icons.near_me,
                                size: 10, color: Colors.grey),
                            const SizedBox(width: 3),
                            Text(
                              f.distanceKm! < 1
                                  ? '${(f.distanceKm! * 1000).toStringAsFixed(0)}m'
                                  : '${f.distanceKm!.toStringAsFixed(1)}km',
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 10)),
                            const SizedBox(width: 8),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: p.stock > 0 ? C.greenLight : C.redLight,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                                p.stock > 0
                                    ? 'Stock: ${p.stock}'
                                    : 'Épuisé',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: p.stock > 0
                                        ? C.greenDark
                                        : C.red,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${_fmt(p.prix)} F',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: isBest ? C.green : Colors.black87)),
                      Text('/${p.unite}',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 10)),
                      if (!isBest && surplus > 0)
                        Text('+${surplus.toStringAsFixed(0)}%',
                            style: const TextStyle(
                                color: C.red,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  if (p.stock > 0)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        _ouvrirCommande(f, p);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isBest ? C.green : C.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: isBest
                                  ? C.green
                                  : Colors.grey.shade300,
                              width: 0.8),
                        ),
                        child: Text('Commander',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: isBest
                                    ? Colors.white
                                    : Colors.black87)),
                      ),
                    ),
                ]),
              ),
            );
          }),
          if (entries.length >= 2) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(children: [
                const Text('💡', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Économie potentielle : ${_fmt(entries.last.value.prix - meilleurPrix)} FCFA/unité'
                    ' (${((entries.last.value.prix - meilleurPrix) / entries.last.value.prix * 100).toStringAsFixed(0)}%)',
                    style: const TextStyle(
                        color: C.greenDark,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  VUE 2 : CATALOGUE
  // ══════════════════════════════════════════════════
  Widget _vueCatalogue() {
    final tousProduits = _tousProduits;

    if (_fournisseurs.isEmpty) {
      return _empty(
        emoji: '🏪',
        titre: 'Aucun fournisseur',
        sous: 'Ajoutez un fournisseur dans l\'onglet "Fournisseurs"',
        boutonLabel: 'Ajouter un fournisseur',
        onBouton: () {
          _tabs.animateTo(2);
          _ouvrirAjoutFournisseur();
        },
      );
    }
    if (tousProduits.isEmpty) {
      return _empty(
        emoji: '📦',
        titre: 'Aucun produit',
        sous: 'Vos fournisseurs n\'ont pas encore de produits enregistrés',
      );
    }

    return RefreshIndicator(
      color: C.green,
      onRefresh: _chargerTout,
      child: Column(children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
              color: C.greenLight, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            const Text('📦', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text('${tousProduits.length} produit(s)',
                style: const TextStyle(
                    color: C.greenDark,
                    fontWeight: FontWeight.w700,
                    fontSize: 13)),
            const Spacer(),
            if (_myLat != null)
              GestureDetector(
                onTap: () =>
                    setState(() => _trierParDistance = !_trierParDistance),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _trierParDistance ? C.green : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: _trierParDistance
                            ? C.green
                            : Colors.grey.shade300,
                        width: 0.8),
                  ),
                  child: Row(children: [
                    Icon(Icons.near_me,
                        size: 12,
                        color: _trierParDistance ? Colors.white : Colors.grey),
                    const SizedBox(width: 4),
                    Text('Par distance',
                        style: TextStyle(
                            fontSize: 11,
                            color: _trierParDistance
                                ? Colors.white
                                : Colors.grey,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
          ]),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.70,
            ),
            itemCount: tousProduits.length,
            itemBuilder: (_, i) {
              final entry = tousProduits[i];
              return _carteProduitJumia(entry.key, entry.value);
            },
          ),
        ),
      ]),
    );
  }

  Widget _carteProduitJumia(Fournisseur f, Produit p) {
    final enStock = p.stock > 0;
    return GestureDetector(
      onTap: enStock ? () => _ouvrirCommande(f, p) : null,
      child: Container(
        decoration: BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: enStock
                  ? Colors.grey.withOpacity(0.15)
                  : Colors.red.withOpacity(0.2)),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Stack(children: [
            Container(
              width: double.infinity,
              height: 108,
              decoration: BoxDecoration(
                color: enStock ? C.greenLight : C.bg,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Center(
                  child: Text(_emojiCat(p.categorie),
                      style: const TextStyle(fontSize: 50))),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: enStock ? C.green : C.red,
                    borderRadius: BorderRadius.circular(7)),
                child: Text(enStock ? 'Stock: ${p.stock}' : 'Épuisé',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(6)),
                    child: Text(f.nom.split(' ').first,
                        style: const TextStyle(
                            fontSize: 9,
                            color: C.green,
                            fontWeight: FontWeight.bold)),
                  ),
                  if (f.distanceKm != null) ...[
                    const SizedBox(height: 3),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(5)),
                      child: Text(
                        f.distanceKm! < 1
                            ? '${(f.distanceKm! * 1000).toStringAsFixed(0)}m'
                            : '${f.distanceKm!.toStringAsFixed(1)}km',
                        style: const TextStyle(
                            fontSize: 9, color: Colors.white)),
                    ),
                  ],
                ],
              ),
            ),
          ]),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(p.nom,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: Color(0xFF1A1A1A))),
                const SizedBox(height: 2),
                Text('1 ${p.unite}',
                    style:
                        const TextStyle(fontSize: 10, color: Colors.grey)),
                const Spacer(),
                Text('${_fmt(p.prix)} F',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: C.green)),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: enStock ? () => _ouvrirCommande(f, p) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 7),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      disabledBackgroundColor: Colors.grey.shade200,
                    ),
                    child: Text(
                      enStock ? 'Commander' : 'Indisponible',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  VUE 3 : LISTE FOURNISSEURS
  // ══════════════════════════════════════════════════
  Widget _vueFournisseurs() {
    if (_filtres.isEmpty) {
      return _empty(
        emoji: '🤝',
        titre: 'Aucun fournisseur',
        sous: 'Ajoutez un fournisseur avec son numéro de téléphone',
        boutonLabel: '+ Ajouter un fournisseur',
        onBouton: _ouvrirAjoutFournisseur,
      );
    }
    return RefreshIndicator(
      color: C.green,
      onRefresh: _chargerTout,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtres.length,
        itemBuilder: (_, i) => _carteFournisseurListe(_filtres[i]),
      ),
    );
  }

  Widget _carteFournisseurListe(Fournisseur f) {
    final nbProduits = f.produits.length;
    final stockTotal = f.stockTotal;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(children: [
        ListTile(
          contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
                color: C.greenLight, borderRadius: BorderRadius.circular(13)),
            child: Center(
                child: Text(_emojiCat(f.categorie),
                    style: const TextStyle(fontSize: 26))),
          ),
          title: Text(f.nom,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 15)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.phone, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(f.telephone,
                    style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (f.fiable) ...[
                  const SizedBox(width: 8),
                  const Text('🏅', style: TextStyle(fontSize: 12)),
                ],
              ]),
              if (f.distanceKm != null)
                Row(children: [
                  const Icon(Icons.near_me, size: 11, color: C.green),
                  const SizedBox(width: 3),
                  Text(
                    f.distanceKm! < 1
                        ? '${(f.distanceKm! * 1000).toStringAsFixed(0)}m'
                        : '${f.distanceKm!.toStringAsFixed(1)}km',
                    style: const TextStyle(
                        color: C.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w600)),
                ]),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: f.actif ? C.greenLight : C.redLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(f.actif ? 'Actif' : 'Inactif',
                    style: TextStyle(
                        fontSize: 10,
                        color: f.actif ? C.greenDark : C.red,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text('$nbProduits produit(s)',
                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: C.bg, borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            _miniStat('📦', '$nbProduits', 'Produits'),
            _divider(),
            _miniStat('🔢', '$stockTotal', 'Stock total'),
            _divider(),
            _miniStat('⭐', '${f.note.toStringAsFixed(1)}',
                '${f.nombreAvis} avis'),
          ]),
        ),
        const SizedBox(height: 8),
        if (f.produits.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [
              const Text('Produits',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey)),
              const Spacer(),
              GestureDetector(
                onTap: () => _ouvrirGestionProduits(f),
                child: const Text('Gérer →',
                    style: TextStyle(
                        fontSize: 12,
                        color: C.green,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 88,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: f.produits.length,
              itemBuilder: (_, i) => _miniProduitCard(f, f.produits[i]),
            ),
          ),
        ] else
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
            child: GestureDetector(
              onTap: () => _ouvrirAjoutProduit(f),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border.all(color: C.green, width: 1.5),
                  borderRadius: BorderRadius.circular(10),
                  color: C.greenLight,
                ),
                child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.add, color: C.green, size: 16),
                  SizedBox(width: 6),
                  Text('Ajouter les produits & prix',
                      style: TextStyle(
                          color: C.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
          child: Row(children: [
            Expanded(
              child: _btnOutline(Icons.phone, 'Appeler', Colors.blue,
                  () => _snack('📞 ${f.telephone}')),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _btnOutline(Icons.add_shopping_cart, 'Produits', C.green,
                  () => _ouvrirAjoutProduit(f)),
            ),
            const SizedBox(width: 8),
            _btnIcon(Icons.delete_outline, Colors.red,
                () => _confirmerSuppression(f)),
          ]),
        ),
      ]),
    );
  }

  Widget _miniProduitCard(Fournisseur f, Produit p) {
    final enStock = p.stock > 0;
    return GestureDetector(
      onTap: enStock ? () => _ouvrirCommande(f, p) : null,
      child: Container(
        width: 118,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: enStock ? Colors.white : C.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: enStock
                  ? C.green.withOpacity(0.3)
                  : Colors.grey.shade300,
              width: 0.8),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text(p.nom,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600)),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('${_fmt(p.prix)} F',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: C.green)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: enStock ? C.greenLight : C.redLight,
                  borderRadius: BorderRadius.circular(5)),
              child: Text(enStock ? '${p.stock}' : '0',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: enStock ? C.greenDark : C.red)),
            ),
          ]),
          Text('/ ${p.unite}',
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  VUE 4 : COMMANDES
  // ══════════════════════════════════════════════════
  Widget _vueCommandes() {
    if (_commandes.isEmpty) {
      return _empty(
          emoji: '🧾',
          titre: 'Aucune commande',
          sous: 'Passez une commande depuis le catalogue');
    }
    final enAttente =
        _commandes.where((c) => c.statut == 'en_attente').toList();
    final autres = _commandes.where((c) => c.statut != 'en_attente').toList();

    return RefreshIndicator(
      color: C.green,
      onRefresh: _chargerTout,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (enAttente.isNotEmpty) ...[
            _sectionTitre('⏳ En attente (${enAttente.length})'),
            ...enAttente.map(_carteCommande),
            const SizedBox(height: 8),
          ],
          if (autres.isNotEmpty) ...[
            _sectionTitre('📋 Historique'),
            ...autres.map(_carteCommande),
          ],
        ],
      ),
    );
  }

  Widget _carteCommande(Commande c) {
    const map = {
      'en_attente': (Color(0xFFFAEEDA), Color(0xFFBA7517), '⏳', 'En attente'),
      'livre':      (Color(0xFFE1F5EE), Color(0xFF085041), '✅', 'Livré'),
      'annule':     (Color(0xFFFCEBEB), Color(0xFFA32D2D), '❌', 'Annulé'),
    };
    final s = map[c.statut] ?? map['en_attente']!;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.$1.withOpacity(0.8), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: s.$1, borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(s.$3, style: const TextStyle(fontSize: 22))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(c.produitNom,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text('${c.fournisseurNom}  ·  x${c.quantite} ${c.unite}',
                    style: const TextStyle(color: Colors.grey, fontSize: 11)),
                Text(_formatDate(c.dateCommande),
                    style: const TextStyle(color: Colors.grey, fontSize: 10)),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${_fmt(c.prixTotal)} F',
                  style: const TextStyle(
                      color: C.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 15)),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: s.$1, borderRadius: BorderRadius.circular(8)),
                child: Text(s.$4,
                    style: TextStyle(
                        fontSize: 10,
                        color: s.$2,
                        fontWeight: FontWeight.bold)),
              ),
            ]),
          ]),
          if (c.statut == 'en_attente') ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: _btnOutline(Icons.check_circle_outline, '✅ Livré',
                    C.green, () => _changerStatut(c, 'livre')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _btnOutline(Icons.cancel_outlined, '❌ Annuler', C.red,
                    () => _changerStatut(c, 'annule')),
              ),
            ]),
          ],
        ]),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  FORMULAIRE — AJOUTER FOURNISSEUR
  //  CORRECTION : SingleChildScrollView wrapping Column
  // ══════════════════════════════════════════════════
  void _ouvrirAjoutFournisseur() {
    final telCtrl = TextEditingController();
    final nomCtrl = TextEditingController();
    String villeSelect     = 'Dakar';
    String categorieSelect = 'Alimentaire';
    bool   useGPS          = _myLat != null;
    int    rayon           = 10;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          // ✅ CORRECTION 2 : padding bottom pour éviter overflow clavier
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(),
                const SizedBox(height: 16),
                const Row(children: [
                  Text('📱', style: TextStyle(fontSize: 26)),
                  SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Ajouter un fournisseur',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: C.green)),
                    Text('Juste le numéro de téléphone suffit !',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ]),
                ]),
                const SizedBox(height: 18),
                TextFormField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  autofocus: true,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: '📱  Numéro de téléphone *',
                    hintText: '77 XXX XX XX',
                    prefixIcon:
                        const Icon(Icons.phone, color: C.green, size: 22),
                    filled: true,
                    fillColor: C.greenLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: C.green, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                _champ(nomCtrl, '👤  Nom (optionnel)', Icons.person),
                const SizedBox(height: 14),
                const Text('🛒  Type de produits',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children:
                      _categories.where((c) => c != 'Tous').map((cat) {
                    final sel = categorieSelect == cat;
                    return GestureDetector(
                      onTap: () => setM(() => categorieSelect = cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? C.green : C.bg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  sel ? C.green : Colors.grey.shade300,
                              width: 0.8),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text(_emojiCat(cat),
                              style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(cat,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: sel ? Colors.white : Colors.black87,
                                  fontWeight: sel
                                      ? FontWeight.bold
                                      : FontWeight.normal)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                const Text('📍  Ville',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: villeSelect,
                      isExpanded: true,
                      items: _villesCoordsSnl.keys
                          .map((v) => DropdownMenuItem(
                              value: v,
                              child: Text(v,
                                  style:
                                      const TextStyle(fontSize: 14))))
                          .toList(),
                      onChanged: (v) => setM(() {
                        villeSelect = v ?? 'Dakar';
                        useGPS = false;
                      }),
                    ),
                  ),
                ),
                if (_myLat != null) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => setM(() => useGPS = !useGPS),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: useGPS ? C.greenLight : C.bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: useGPS ? C.green : Colors.grey.shade300,
                            width: useGPS ? 1.5 : 0.8),
                      ),
                      child: Row(children: [
                        Icon(Icons.my_location,
                            color: useGPS ? C.green : Colors.grey, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Utiliser ma position GPS exacte',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                      color: useGPS
                                          ? C.greenDark
                                          : Colors.black87)),
                              const Text(
                                  'Pour une distance précise dans la liste Proximité',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 11)),
                            ],
                          ),
                        ),
                        Switch(
                          value: useGPS,
                          activeColor: C.green,
                          onChanged: (v) => setM(() => useGPS = v),
                        ),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(children: [
                  const Text('🚴  Rayon livraison :',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  Text('$rayon km',
                      style: const TextStyle(
                          color: C.green,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ]),
                SliderTheme(
                  data: SliderTheme.of(ctx).copyWith(
                    activeTrackColor: C.green,
                    inactiveTrackColor: C.greenLight,
                    thumbColor: C.green,
                    trackHeight: 4,
                  ),
                  child: Slider(
                    value: rayon.toDouble(),
                    min: 1,
                    max: 50,
                    divisions: 10,
                    onChanged: (v) => setM(() => rayon = v.round()),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Enregistrer le fournisseur',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      if (telCtrl.text.trim().isEmpty) {
                        ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text(
                              '⚠️ Le numéro de téléphone est obligatoire'),
                          backgroundColor: C.red,
                        ));
                        return;
                      }
                      Navigator.pop(ctx);
                      await _ajouterFournisseur(
                        telephone:      telCtrl.text.trim(),
                        nom:            nomCtrl.text.trim(),
                        ville:          villeSelect,
                        categorie:      categorieSelect,
                        latitude:
                            useGPS && _myLat != null ? _myLat : null,
                        longitude:
                            useGPS && _myLng != null ? _myLng : null,
                        rayonLivraison: rayon,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  FORMULAIRE — AJOUTER PRODUIT
  //  CORRECTION : SingleChildScrollView wrapping Column
  // ══════════════════════════════════════════════════
  void _ouvrirAjoutProduit(Fournisseur f) {
    final nomCtrl   = TextEditingController();
    final descCtrl  = TextEditingController();
    final prixCtrl  = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    String unite     = 'pièce';
    String categorie = f.categorie;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          // ✅ CORRECTION 2 : padding bottom séparé du scroll
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(),
                const SizedBox(height: 16),
                Row(children: [
                  Text(_emojiCat(f.categorie),
                      style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('Nouveau produit',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: C.green)),
                      Text('Fournisseur : ${f.nom}',
                          style: const TextStyle(
                              fontSize: 12, color: Colors.grey)),
                    ]),
                  ),
                ]),
                const SizedBox(height: 18),
                _champ(nomCtrl, '📦  Nom du produit *', Icons.label),
                const SizedBox(height: 10),
                _champ(descCtrl, '📝  Description (optionnel)', Icons.notes),
                const SizedBox(height: 10),
                TextFormField(
                  controller: prixCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: C.green),
                  onChanged: (_) => setM(() {}),
                  decoration: InputDecoration(
                    labelText: '💰  Prix de vente *',
                    suffixText: 'FCFA',
                    suffixStyle: const TextStyle(
                        color: C.green, fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.attach_money,
                        color: C.green, size: 22),
                    filled: true,
                    fillColor: C.greenLight,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide:
                            const BorderSide(color: C.green, width: 2)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                  ),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('📏 Unité',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: unite,
                            isExpanded: true,
                            items: _unites
                                .map((u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u,
                                        style: const TextStyle(
                                            fontSize: 13))))
                                .toList(),
                            onChanged: (v) =>
                                setM(() => unite = v ?? 'pièce'),
                          ),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      const Text('🔢 Stock dispo.',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      Row(children: [
                        _qteBtn(Icons.remove, () {
                          final v =
                              int.tryParse(stockCtrl.text) ?? 0;
                          if (v > 0)
                            setM(() => stockCtrl.text = '${v - 1}');
                        }),
                        Expanded(
                          child: TextFormField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                            onChanged: (_) => setM(() {}),
                            decoration: InputDecoration(
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                  borderSide: const BorderSide(
                                      color: C.green, width: 2)),
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      vertical: 10),
                            ),
                          ),
                        ),
                        _qteBtn(Icons.add, () {
                          final v =
                              int.tryParse(stockCtrl.text) ?? 0;
                          setM(() => stockCtrl.text = '${v + 1}');
                        }, isAdd: true),
                      ]),
                    ]),
                  ),
                ]),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.save),
                    label: const Text('Enregistrer ce produit',
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      if (nomCtrl.text.isEmpty ||
                          prixCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(ctx)
                            .showSnackBar(const SnackBar(
                          content: Text(
                              '⚠️ Nom et Prix sont obligatoires'),
                          backgroundColor: C.red,
                        ));
                        return;
                      }
                      final p = Produit(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        nom:         nomCtrl.text.trim(),
                        description: descCtrl.text.trim(),
                        categorie:   categorie,
                        prix: double.tryParse(prixCtrl.text) ?? 0,
                        unite:       unite,
                        stock:
                            int.tryParse(stockCtrl.text) ?? 0,
                      );
                      Navigator.pop(ctx);
                      await _ajouterProduit(f.id, p);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  GESTION PRODUITS D'UN FOURNISSEUR
  // ══════════════════════════════════════════════════
  void _ouvrirGestionProduits(Fournisseur f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => DraggableScrollableSheet(
          initialChildSize: 0.9,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, sc) => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(children: [
              _handle(),
              const SizedBox(height: 14),
              Row(children: [
                Text(_emojiCat(f.categorie),
                    style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Produits de ${f.nom}',
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: C.green)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _ouvrirAjoutProduit(f);
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: C.green,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8)),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter',
                      style: TextStyle(fontSize: 12)),
                ),
              ]),
              const SizedBox(height: 10),
              if (f.produits.isEmpty)
                Expanded(
                  child: _empty(
                    emoji: '📦',
                    titre: 'Aucun produit',
                    sous: 'Ajoutez les produits de ce fournisseur',
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    controller: sc,
                    itemCount: f.produits.length,
                    itemBuilder: (_, i) =>
                        _ligneGestionProduit(f, f.produits[i], setM),
                  ),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _ligneGestionProduit(
      Fournisseur f, Produit p, StateSetter setM) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Row(children: [
        Text(_emojiCat(p.categorie), style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Text(p.nom,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 14)),
            Text('${_fmt(p.prix)} F / ${p.unite}',
                style: const TextStyle(
                    color: C.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
        Row(children: [
          _qteBtn(Icons.remove, () async {
            final ns = (p.stock - 1).clamp(0, 99999);
            await _modifierStock(p, ns);
            setM(() {});
          }),
          Container(
              width: 42,
              alignment: Alignment.center,
              child: Text('${p.stock}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold))),
          _qteBtn(Icons.add, () async {
            await _modifierStock(p, p.stock + 1);
            setM(() {});
          }, isAdd: true),
        ]),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () async {
            await _supprimerProduit(p.id);
            setM(() {});
          },
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: C.redLight,
                borderRadius: BorderRadius.circular(8)),
            child:
                const Icon(Icons.delete_outline, size: 16, color: C.red),
          ),
        ),
      ]),
    );
  }

  // ══════════════════════════════════════════════════
  //  COMMANDER UN PRODUIT
  //  CORRECTION : SingleChildScrollView pour éviter overflow
  // ══════════════════════════════════════════════════
  void _ouvrirCommande(Fournisseur f, Produit p) {
    int quantite = 1;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final total = p.prix * quantite;
          // ✅ CORRECTION 3 : SingleChildScrollView au lieu de Column nue
          return Padding(
            padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _handle(),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                        color: C.greenLight,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12)),
                        child: Center(
                            child: Text(_emojiCat(p.categorie),
                                style: const TextStyle(fontSize: 34))),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                          Text(p.nom,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16)),
                          const SizedBox(height: 3),
                          Text('${_fmt(p.prix)} FCFA / ${p.unite}',
                              style: const TextStyle(
                                  color: C.green,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 18)),
                          const SizedBox(height: 3),
                          Row(children: [
                            const Icon(Icons.storefront,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 4),
                            Text(f.nom,
                                style: const TextStyle(
                                    color: Colors.grey, fontSize: 11)),
                            if (f.distanceKm != null) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.near_me,
                                  size: 11, color: C.green),
                              const SizedBox(width: 2),
                              Text(
                                f.distanceKm! < 1
                                    ? '${(f.distanceKm! * 1000).toStringAsFixed(0)}m'
                                    : '${f.distanceKm!.toStringAsFixed(1)}km',
                                style: const TextStyle(
                                    color: C.green,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            ],
                          ]),
                        ]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Quantité',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    _qteBtn(Icons.remove, () {
                      if (quantite > 1) setM(() => quantite--);
                    }),
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: C.green, width: 1.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('$quantite ${p.unite}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                    _qteBtn(Icons.add, () {
                      if (quantite < p.stock) setM(() => quantite++);
                    }, isAdd: true),
                  ]),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: C.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        const Text('Total à payer',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 12)),
                        Text('${_fmt(total)} FCFA',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.w900)),
                      ]),
                      Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                        Text('$quantite × ${_fmt(p.prix)} F',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                        Text('/ ${p.unite}',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.orange,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.shopping_cart),
                      label: const Text('Confirmer la commande',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      onPressed: p.stock > 0
                          ? () async {
                              Navigator.pop(ctx);
                              await _commander(f, p, quantite);
                            }
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────
  //  SUPPRIMER FOURNISSEUR
  // ─────────────────────────────────────
  void _confirmerSuppression(Fournisseur f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Text('🗑️', style: TextStyle(fontSize: 22)),
          SizedBox(width: 8),
          Text('Supprimer',
              style: TextStyle(color: C.red, fontSize: 16)),
        ]),
        content: Text('Supprimer "${f.nom}" et tous ses produits ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: C.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await _supprimerFournisseur(f);
            },
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  //  WIDGETS RÉUTILISABLES
  // ══════════════════════════════════════════════════

  Widget _fab() {
    final idx = _tabs.index;
    if (idx == 2) {
      return FloatingActionButton.extended(
        onPressed: _ouvrirAjoutFournisseur,
        backgroundColor: C.green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter',
            style: TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    if (idx == 0 && _produitsGroupes.isNotEmpty) {
      return FloatingActionButton.extended(
        onPressed: _ouvrirComparaison,
        backgroundColor: C.blue,
        foregroundColor: Colors.white,
        icon: const Text('⚖️', style: TextStyle(fontSize: 18)),
        label: const Text('Comparer',
            style: TextStyle(fontWeight: FontWeight.w700)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _handle() => Center(
    child: Container(
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: Colors.grey.shade300,
          borderRadius: BorderRadius.circular(2)),
    ),
  );

  Widget _miniStat(String emoji, String val, String lbl) => Expanded(
    child: Column(children: [
      Text('$emoji $val',
          style:
              const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
      Text(lbl,
          style: const TextStyle(color: Colors.grey, fontSize: 10)),
    ]),
  );

  Widget _divider() =>
      Container(width: 0.5, height: 30, color: Colors.grey.shade300);

  Widget _sectionTitre(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t,
        style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: C.greenDark)),
  );

  Widget _qteBtn(IconData icon, VoidCallback onTap,
          {bool isAdd = false}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isAdd ? C.green : C.bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isAdd ? C.green : Colors.grey.shade300,
                width: 0.8),
          ),
          child: Icon(icon,
              size: 18,
              color: isAdd ? Colors.white : Colors.black87),
        ),
      );

  Widget _btnOutline(IconData icon, String label, Color color,
          VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      );

  Widget _btnIcon(IconData icon, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      );

  Widget _champ(TextEditingController ctrl, String label, IconData icon,
          {bool isNumber = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType: isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters:
            isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: C.green, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: C.green, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  Widget _empty({
    required String emoji,
    required String titre,
    required String sous,
    String? boutonLabel,
    VoidCallback? onBouton,
  }) =>
      Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
            Text(emoji, style: const TextStyle(fontSize: 64)),
            const SizedBox(height: 14),
            Text(titre,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(sous,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
            if (boutonLabel != null && onBouton != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onBouton,
                style: ElevatedButton.styleFrom(
                    backgroundColor: C.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                child: Text(boutonLabel),
              ),
            ],
          ]),
        ),
      );

  // ─────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────

  String _emojiCat(String cat) {
    switch (cat) {
      case 'Alimentaire': return '🍚';
      case 'Boissons':    return '🥤';
      case 'Hygiène':     return '🧼';
      default:            return '📦';
    }
  }

  String _fmt(double p) {
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000)    return '${(p / 1000).toStringAsFixed(0)}k';
    return p.toStringAsFixed(0);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  void _snack(String msg, {bool ok = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? C.green : C.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}
