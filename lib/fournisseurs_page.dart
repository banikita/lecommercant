import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _sb = Supabase.instance.client;

// ─────────────────────────────────────────
// MODÈLES
// ─────────────────────────────────────────
class Fournisseur {
  final String id;
  String nom;
  String telephone;
  String produitPrincipal;
  String ville;
  bool actif;
  double note;
  int nombreAvis;
  bool fiable;
  String modeLivraison;
  double prixMoyen;
  List<ProduitFournisseur> produits;
  List<CommentaireFournisseur> commentaires;

  Fournisseur({
    required this.id,
    required this.nom,
    required this.telephone,
    required this.produitPrincipal,
    required this.ville,
    this.actif = true,
    this.note = 0,
    this.nombreAvis = 0,
    this.fiable = false,
    this.modeLivraison = 'Livraison',
    this.prixMoyen = 0,
    this.produits = const [],
    this.commentaires = const [],
  });

  factory Fournisseur.fromMap(Map<String, dynamic> m) => Fournisseur(
    id:               m['id'],
    nom:              m['nom'],
    telephone:        m['telephone'],
    produitPrincipal: m['produit_principal'] ?? 'Alimentaire',
    ville:            m['ville'] ?? 'Dakar',
    actif:            m['actif'] ?? true,
    note:             (m['note'] as num?)?.toDouble() ?? 0,
    nombreAvis:       (m['nombre_avis'] as int?) ?? 0,
    fiable:           m['fiable'] ?? false,
    modeLivraison:    m['mode_livraison'] ?? 'Livraison',
    prixMoyen:        (m['prix_moyen'] as num?)?.toDouble() ?? 0,
  );

  Map<String, dynamic> toMap(int commercantId) => {
    'id':               id,
    'commercant_id':    commercantId,
    'nom':              nom,
    'telephone':        telephone,
    'produit_principal': produitPrincipal,
    'ville':            ville,
    'actif':            actif,
    'note':             note,
    'nombre_avis':      nombreAvis,
    'fiable':           fiable,
    'mode_livraison':   modeLivraison,
    'prix_moyen':       prixMoyen,
  };
}

class ProduitFournisseur {
  final String id;
  String nom;
  String categorie;
  double prix;
  int stockDisponible;

  ProduitFournisseur({
    required this.id,
    required this.nom,
    required this.categorie,
    required this.prix,
    required this.stockDisponible,
  });

  factory ProduitFournisseur.fromMap(Map<String, dynamic> m) => ProduitFournisseur(
    id:               m['id'],
    nom:              m['nom'],
    categorie:        m['categorie'] ?? 'Alimentaire',
    prix:             (m['prix'] as num?)?.toDouble() ?? 0,
    stockDisponible:  (m['stock_disponible'] as int?) ?? 0,
  );

  Map<String, dynamic> toMap(String fournisseurId) => {
    'id':               id,
    'fournisseur_id':   fournisseurId,
    'nom':              nom,
    'categorie':        categorie,
    'prix':             prix,
    'stock_disponible': stockDisponible,
  };
}

class CommentaireFournisseur {
  final String id;
  final String texte;
  final DateTime creeLe;

  CommentaireFournisseur({
    required this.id,
    required this.texte,
    required this.creeLe,
  });

  factory CommentaireFournisseur.fromMap(Map<String, dynamic> m) =>
      CommentaireFournisseur(
        id:     m['id'],
        texte:  m['texte'],
        creeLe: DateTime.parse(m['cree_le']),
      );
}

class Commande {
  final String id;
  final String fournisseurId;
  final String fournisseurNom;
  final String produitNom;
  final int quantite;
  final double prixTotal;
  final DateTime dateCommande;
  DateTime? dateLivraison;
  String statut;

  Commande({
    required this.id,
    required this.fournisseurId,
    required this.fournisseurNom,
    required this.produitNom,
    required this.quantite,
    required this.prixTotal,
    required this.dateCommande,
    this.dateLivraison,
    this.statut = 'en_attente',
  });

  factory Commande.fromMap(Map<String, dynamic> m) => Commande(
    id:             m['id'],
    fournisseurId:  m['fournisseur_id'],
    fournisseurNom: m['fournisseur_nom'],
    produitNom:     m['produit_nom'],
    quantite:       (m['quantite'] as int?) ?? 1,
    prixTotal:      (m['prix_total'] as num?)?.toDouble() ?? 0,
    dateCommande:   DateTime.parse(m['date_commande']),
    dateLivraison:  m['date_livraison'] != null
        ? DateTime.parse(m['date_livraison'])
        : null,
    statut:         m['statut'] ?? 'en_attente',
  );
}

// ─────────────────────────────────────────
// PAGE PRINCIPALE
// ─────────────────────────────────────────
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
    with TickerProviderStateMixin {

  static const Color green      = Color(0xFF0F6E56);
  static const Color greenLight = Color(0xFFE8F5E9);
  static const Color amber      = Color(0xFFFFC107);

  late TabController _tabCtrl;

  String _filtreCategorie = 'Tous';
  String _filtreVille     = 'Tous';
  String _recherche       = '';

  List<Fournisseur> _fournisseurs = [];
  List<Commande>    _commandes    = [];
  bool _loading = true;

  final List<String> categories = [
    'Tous', 'Alimentaire', 'Boissons', 'Hygiène', 'Autre'
  ];
  final List<String> villes = [
    'Tous', 'Dakar', 'Thiès', 'Saint-Louis', 'Ziguinchor'
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _chargerTout();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  //  SUPABASE — LECTURE
  // ═══════════════════════════════════════

  Future<void> _chargerTout() async {
    setState(() => _loading = true);
    await Future.wait([_chargerFournisseurs(), _chargerCommandes()]);
    setState(() => _loading = false);
  }

  Future<void> _chargerFournisseurs() async {
    try {
      final data = await _sb
          .from('fournisseurs')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('cree_le', ascending: false);

      final liste = <Fournisseur>[];
      for (final row in data as List) {
        final f = Fournisseur.fromMap(row);

        // Charger produits
        final prodData = await _sb
            .from('produits_fournisseur')
            .select()
            .eq('fournisseur_id', f.id);
        f.produits = (prodData as List)
            .map((e) => ProduitFournisseur.fromMap(e))
            .toList();

        // Charger commentaires
        final commData = await _sb
            .from('commentaires_fournisseur')
            .select()
            .eq('fournisseur_id', f.id)
            .order('cree_le', ascending: false);
        f.commentaires = (commData as List)
            .map((e) => CommentaireFournisseur.fromMap(e))
            .toList();

        liste.add(f);
      }
      _fournisseurs = liste;
    } catch (e) {
      _toast('Erreur chargement fournisseurs : $e', success: false);
    }
  }

  Future<void> _chargerCommandes() async {
    try {
      final data = await _sb
          .from('commandes_fournisseur')
          .select()
          .eq('commercant_id', widget.commercantId)
          .order('date_commande', ascending: false);
      _commandes = (data as List).map((e) => Commande.fromMap(e)).toList();
    } catch (e) {
      _toast('Erreur chargement commandes : $e', success: false);
    }
  }

  // ═══════════════════════════════════════
  //  SUPABASE — ÉCRITURE FOURNISSEUR
  // ═══════════════════════════════════════

  Future<void> _ajouterFournisseur(Fournisseur f) async {
    try {
      await _sb.from('fournisseurs').insert(f.toMap(widget.commercantId));
      await _chargerFournisseurs();
      setState(() {});
      _toast('✅ ${f.nom} ajouté !', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  Future<void> _modifierFournisseur(Fournisseur f) async {
    try {
      await _sb
          .from('fournisseurs')
          .update(f.toMap(widget.commercantId))
          .eq('id', f.id);
      await _chargerFournisseurs();
      setState(() {});
      _toast('✅ ${f.nom} modifié !', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  Future<void> _supprimerFournisseur(Fournisseur f) async {
    try {
      // ON DELETE CASCADE supprime produits + commentaires automatiquement
      await _sb.from('fournisseurs').delete().eq('id', f.id);
      await _chargerFournisseurs();
      setState(() {});
      _toast('Fournisseur supprimé', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  // ═══════════════════════════════════════
  //  SUPABASE — ÉCRITURE PRODUIT FOURNISSEUR
  // ═══════════════════════════════════════

  Future<void> _ajouterProduitFournisseur(
      String fournisseurId, ProduitFournisseur p) async {
    try {
      await _sb
          .from('produits_fournisseur')
          .insert(p.toMap(fournisseurId));
      await _chargerFournisseurs();
      setState(() {});
      _toast('✅ Produit ajouté !', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  Future<void> _supprimerProduitFournisseur(String produitId) async {
    try {
      await _sb.from('produits_fournisseur').delete().eq('id', produitId);
      await _chargerFournisseurs();
      setState(() {});
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  // ═══════════════════════════════════════
  //  SUPABASE — NOTE + COMMENTAIRE
  // ═══════════════════════════════════════

  Future<void> _enregistrerNote(
      Fournisseur f, double note, String? commentaire) async {
    try {
      final nouveauxAvis = f.nombreAvis + 1;
      final nouvelleNote = ((f.note * f.nombreAvis) + note) / nouveauxAvis;
      final estFiable    = nouvelleNote >= 4;

      await _sb.from('fournisseurs').update({
        'note':        nouvelleNote,
        'nombre_avis': nouveauxAvis,
        'fiable':      estFiable,
      }).eq('id', f.id);

      if (commentaire != null && commentaire.isNotEmpty) {
        await _sb.from('commentaires_fournisseur').insert({
          'id':             DateTime.now().millisecondsSinceEpoch.toString(),
          'fournisseur_id': f.id,
          'texte':          commentaire,
        });
      }

      await _chargerFournisseurs();
      setState(() {});
      _toast('⭐ Note enregistrée !', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  // ═══════════════════════════════════════
  //  SUPABASE — COMMANDE
  // ═══════════════════════════════════════

  Future<void> _envoyerCommande(Commande c) async {
    try {
      await _sb.from('commandes_fournisseur').insert({
        'id':              c.id,
        'commercant_id':   widget.commercantId,
        'fournisseur_id':  c.fournisseurId,
        'fournisseur_nom': c.fournisseurNom,
        'produit_nom':     c.produitNom,
        'quantite':        c.quantite,
        'prix_total':      c.prixTotal,
        'date_commande':   c.dateCommande.toIso8601String(),
        'date_livraison':  c.dateLivraison?.toIso8601String(),
        'statut':          'en_attente',
      });
      await _chargerCommandes();
      setState(() {});
      _toast('✅ Commande envoyée !', success: true);
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  Future<void> _changerStatutCommande(Commande c, String nouveauStatut) async {
    try {
      await _sb
          .from('commandes_fournisseur')
          .update({'statut': nouveauStatut})
          .eq('id', c.id);
      await _chargerCommandes();
      setState(() {});
    } catch (e) {
      _toast('Erreur : $e', success: false);
    }
  }

  // ─────────────────────────────────────────
  // GETTERS FILTRES
  // ─────────────────────────────────────────
  List<Fournisseur> get _filtres => _fournisseurs.where((f) {
        final matchCat   = _filtreCategorie == 'Tous' ||
            f.produitPrincipal == _filtreCategorie;
        final matchVille = _filtreVille == 'Tous' || f.ville == _filtreVille;
        final matchSearch = _recherche.isEmpty ||
            f.nom.toLowerCase().contains(_recherche.toLowerCase());
        return matchCat && matchVille && matchSearch;
      }).toList();

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: green))
          : Column(children: [
              _buildFiltres(),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildListeFournisseurs(),
                    _buildHistoriqueCommandes(),
                    _buildStats(),
                  ],
                ),
              ),
            ]),
      floatingActionButton:
          !_loading && _tabCtrl.index == 0 ? _buildFAB() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 0,
      title: TextField(
        onChanged: (v) => setState(() => _recherche = v),
        style: const TextStyle(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          hintText: 'Chercher un fournisseur...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          border: InputBorder.none,
          prefixIcon: const Icon(Icons.search, color: Colors.white),
          suffixIcon: _recherche.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: () => setState(() => _recherche = ''))
              : null,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _chargerTout,
          tooltip: 'Rafraîchir',
        ),
      ],
      bottom: TabBar(
        controller: _tabCtrl,
        indicatorColor: Colors.white,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        onTap: (_) => setState(() {}),
        tabs: const [
          Tab(icon: Icon(Icons.people),    text: 'Fournisseurs'),
          Tab(icon: Icon(Icons.history),   text: 'Commandes'),
          Tab(icon: Icon(Icons.bar_chart), text: 'Stats'),
        ],
      ),
    );
  }

  Widget _buildFAB() => FloatingActionButton.extended(
        onPressed: () => _ouvrirFormulaireAjout(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: const Text('Ajouter'),
      );

  // ─────────────────────────────────────────
  // FILTRES
  // ─────────────────────────────────────────
  Widget _buildFiltres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(children: [
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: categories.length,
            itemBuilder: (_, i) {
              final sel = _filtreCategorie == categories[i];
              return GestureDetector(
                onTap: () => setState(() => _filtreCategorie = categories[i]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel ? green : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_emoji(categories[i]),
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(categories[i],
                        style: TextStyle(
                            fontSize: 12,
                            color: sel ? Colors.white : Colors.black87,
                            fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: villes.length,
            itemBuilder: (_, i) {
              final sel = _filtreVille == villes[i];
              return GestureDetector(
                onTap: () => setState(() => _filtreVille = villes[i]),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: sel ? Colors.orange : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(16),
                    border: sel
                        ? null
                        : Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.location_on,
                        size: 12,
                        color: sel ? Colors.white : Colors.grey),
                    const SizedBox(width: 4),
                    Text(villes[i],
                        style: TextStyle(
                            fontSize: 11,
                            color: sel ? Colors.white : Colors.black54)),
                  ]),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 16, top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text('${_filtres.length} fournisseur(s)',
                style: const TextStyle(
                    color: green, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────
  // ONGLET 1 : LISTE FOURNISSEURS
  // ─────────────────────────────────────────
  Widget _buildListeFournisseurs() {
    if (_filtres.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('🤷', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text('Aucun fournisseur',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _ouvrirFormulaireAjout(),
            style: ElevatedButton.styleFrom(
                backgroundColor: green, foregroundColor: Colors.white),
            icon: const Icon(Icons.person_add),
            label: const Text('Ajouter un fournisseur'),
          ),
        ]),
      );
    }

    return RefreshIndicator(
      color: green,
      onRefresh: _chargerTout,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _filtres.length,
        itemBuilder: (_, i) => _carteFournisseur(_filtres[i]),
      ),
    );
  }

  Widget _carteFournisseur(Fournisseur f) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.15)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _ouvrirDetail(f),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Row(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: f.actif ? greenLight : Colors.grey[100],
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(_emoji(f.produitPrincipal),
                      style: const TextStyle(fontSize: 28)),
                ),
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
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    if (f.fiable)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: amber.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('⭐', style: TextStyle(fontSize: 11)),
                              SizedBox(width: 3),
                              Text('Fiable',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF856404),
                                      fontWeight: FontWeight.bold)),
                            ]),
                      ),
                  ]),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.inventory_2,
                        size: 13, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(f.produitPrincipal,
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 10),
                    const Icon(Icons.location_on,
                        size: 13, color: Colors.orange),
                    const SizedBox(width: 2),
                    Text(f.ville,
                        style: const TextStyle(
                            color: Colors.orange, fontSize: 12)),
                  ]),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: f.actif
                      ? green.withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.actif ? Icons.check_circle : Icons.cancel,
                      size: 12, color: f.actif ? green : Colors.red),
                  const SizedBox(width: 4),
                  Text(f.actif ? 'Actif' : 'Inactif',
                      style: TextStyle(
                          fontSize: 11,
                          color: f.actif ? green : Colors.red,
                          fontWeight: FontWeight.bold)),
                ]),
              ),
            ]),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),

            Row(children: [
              _infoRapide(Icons.phone, Colors.blue, f.telephone),
              const SizedBox(width: 12),
              _infoRapide(
                f.modeLivraison == 'Livraison'
                    ? Icons.delivery_dining
                    : Icons.store,
                Colors.purple,
                f.modeLivraison,
              ),
              const SizedBox(width: 12),
              _infoRapide(Icons.payments, green,
                  '${_formatPrix(f.prixMoyen)} F'),
              const Spacer(),
              _noteWidget(f.note, f.nombreAvis),
            ]),

            const SizedBox(height: 12),

            Row(children: [
              Expanded(
                child: _actionBtn(
                  icon: Icons.phone,
                  label: 'Appeler',
                  couleur: Colors.blue,
                  onTap: () => _appeler(f),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.shopping_cart,
                  label: 'Commander',
                  couleur: green,
                  onTap: () => _ouvrirCommande(f),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  icon: Icons.info_outline,
                  label: 'Détails',
                  couleur: Colors.orange,
                  onTap: () => _ouvrirDetail(f),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _infoRapide(IconData icon, Color color, String texte) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 4),
        Text(texte, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _noteWidget(double note, int avis) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        ...List.generate(
            5,
            (i) => Icon(
                  i < note.floor() ? Icons.star : Icons.star_border,
                  size: 14, color: amber,
                )),
        const SizedBox(width: 4),
        Text('($avis)',
            style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ]);

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color couleur,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: couleur.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: couleur.withOpacity(0.3)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: couleur, size: 22),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: couleur,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      );

  // ─────────────────────────────────────────
  // ONGLET 2 : HISTORIQUE COMMANDES
  // ─────────────────────────────────────────
  Widget _buildHistoriqueCommandes() {
    if (_commandes.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Text('📦', style: TextStyle(fontSize: 60)),
          const SizedBox(height: 12),
          const Text('Aucune commande',
              style: TextStyle(fontSize: 16, color: Colors.grey)),
        ]),
      );
    }

    return RefreshIndicator(
      color: green,
      onRefresh: _chargerTout,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _commandes.length,
        itemBuilder: (_, i) => _carteCommande(_commandes[i]),
      ),
    );
  }

  Widget _carteCommande(Commande c) {
    final statuts = {
      'en_attente': {
        'couleur': Colors.orange,
        'texte': 'En attente',
        'emoji': '⏳'
      },
      'livre': {'couleur': green, 'texte': 'Livré', 'emoji': '✅'},
      'annule': {'couleur': Colors.red, 'texte': 'Annulé', 'emoji': '❌'},
    };
    final s = statuts[c.statut] ?? statuts['en_attente']!;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
            color: (s['couleur'] as Color).withOpacity(0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: (s['couleur'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(s['emoji'] as String,
                  style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(c.produitNom,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Row(children: [
                const Icon(Icons.person, size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(c.fournisseurNom,
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ]),
              Row(children: [
                const Icon(Icons.calendar_today,
                    size: 13, color: Colors.grey),
                const SizedBox(width: 4),
                Text(_formatDate(c.dateCommande),
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 12)),
              ]),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${_formatPrix(c.prixTotal)} F',
                style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            Text('x${c.quantite}',
                style:
                    const TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 6),
            // Boutons changer statut
            if (c.statut == 'en_attente')
              Row(children: [
                GestureDetector(
                  onTap: () => _changerStatutCommande(c, 'livre'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('✅',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _changerStatutCommande(c, 'annule'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('❌',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                    color: (s['couleur'] as Color).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(s['texte'] as String,
                    style: TextStyle(
                        fontSize: 11,
                        color: s['couleur'] as Color,
                        fontWeight: FontWeight.bold)),
              ),
          ]),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ONGLET 3 : STATS
  // ─────────────────────────────────────────
  Widget _buildStats() {
    final actifs       = _fournisseurs.where((f) => f.actif).length;
    final totalDepense =
        _commandes.fold(0.0, (s, c) => s + c.prixTotal);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.4,
          children: [
            _statCard('👥', 'Fournisseurs', '${_fournisseurs.length}',
                Colors.blue),
            _statCard('✅', 'Actifs', '$actifs', green),
            _statCard('📦', 'Commandes', '${_commandes.length}',
                Colors.orange),
            _statCard(
                '💰', 'Dépensé', '${_formatPrix(totalDepense)} F',
                Colors.purple),
          ],
        ),
        const SizedBox(height: 24),
        const Text('🏆 Meilleurs fournisseurs',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...([..._fournisseurs]
              ..sort((a, b) => b.note.compareTo(a.note)))
            .take(3)
            .map((f) => _topFournisseurRow(f)),
        const SizedBox(height: 24),
        const Text('📊 Par catégorie',
            style:
                TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...categories.where((c) => c != 'Tous').map((cat) {
          final count = _fournisseurs
              .where((f) => f.produitPrincipal == cat)
              .length;
          if (count == 0) return const SizedBox.shrink();
          return _categorieBar(
              cat, count, count / _fournisseurs.length);
        }),
      ]),
    );
  }

  Widget _statCard(
          String emoji, String label, String val, Color couleur) =>
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: couleur.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28)),
              Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(val,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: couleur)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 12, color: Colors.grey)),
              ]),
            ]),
      );

  Widget _topFournisseurRow(Fournisseur f) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          Text(_emoji(f.produitPrincipal),
              style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(
              child: Text(f.nom,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600))),
          _noteWidget(f.note, f.nombreAvis),
          if (f.fiable) ...[
            const SizedBox(width: 6),
            const Text('🏅', style: TextStyle(fontSize: 16)),
          ],
        ]),
      );

  Widget _categorieBar(String cat, int count, double percent) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(children: [
          Row(children: [
            Text(_emoji(cat), style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Text(cat, style: const TextStyle(fontSize: 13)),
            const Spacer(),
            Text('$count',
                style: const TextStyle(
                    color: Colors.grey, fontSize: 13)),
          ]),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: percent,
              backgroundColor: Colors.grey[200],
              valueColor:
                  const AlwaysStoppedAnimation<Color>(green),
              minHeight: 6,
            ),
          ),
        ]),
      );

  // ─────────────────────────────────────────
  // FORMULAIRE AJOUT / MODIFICATION
  // ─────────────────────────────────────────
  void _ouvrirFormulaireAjout({Fournisseur? existant}) {
    final nomCtrl  = TextEditingController(text: existant?.nom);
    final telCtrl  = TextEditingController(text: existant?.telephone);
    final prixCtrl = TextEditingController(
        text: existant != null
            ? existant.prixMoyen.toStringAsFixed(0)
            : '');
    String catSelect       = existant?.produitPrincipal ?? 'Alimentaire';
    String villeSelect     = existant?.ville ?? 'Dakar';
    String livraisonSelect = existant?.modeLivraison ?? 'Livraison';
    bool   actifSelect     = existant?.actif ?? true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: SingleChildScrollView(
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Text('👤', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 10),
                Text(
                  existant == null
                      ? 'Nouveau fournisseur'
                      : 'Modifier fournisseur',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: green),
                ),
              ]),
              const SizedBox(height: 20),
              _champ(nomCtrl, '👤  Nom du fournisseur', Icons.person),
              const SizedBox(height: 12),
              _champ(telCtrl, '📱  Téléphone / WhatsApp', Icons.phone,
                  isNumber: true),
              const SizedBox(height: 16),

              // Catégorie
              const Text('🛒  Produit principal',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10, runSpacing: 10,
                children: categories
                    .where((c) => c != 'Tous')
                    .map((cat) {
                  final sel = catSelect == cat;
                  return GestureDetector(
                    onTap: () => setModal(() => catSelect = cat),
                    child: Container(
                      width: 78, height: 78,
                      decoration: BoxDecoration(
                        color: sel
                            ? green.withOpacity(0.12)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: sel ? green : Colors.transparent,
                            width: 2),
                      ),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                        Text(_emoji(cat),
                            style: const TextStyle(fontSize: 30)),
                        const SizedBox(height: 4),
                        Text(cat,
                            style: TextStyle(
                                fontSize: 9,
                                color: sel ? green : Colors.grey[700],
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Ville
              const Text('📍  Ville / Quartier',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8, runSpacing: 8,
                children: villes
                    .where((v) => v != 'Tous')
                    .map((v) {
                  final sel = villeSelect == v;
                  return GestureDetector(
                    onTap: () => setModal(() => villeSelect = v),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: sel
                            ? Colors.orange
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                        const Text('📍',
                            style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 4),
                        Text(v,
                            style: TextStyle(
                                fontSize: 12,
                                color: sel
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: sel
                                    ? FontWeight.bold
                                    : FontWeight.normal)),
                      ]),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Livraison
              const Text('🚚  Mode de livraison',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(children: [
                _toggleLivraison('🚚', 'Livraison',
                    livraisonSelect == 'Livraison',
                    () => setModal(() => livraisonSelect = 'Livraison')),
                const SizedBox(width: 10),
                _toggleLivraison('🏪', 'Retrait',
                    livraisonSelect == 'Retrait',
                    () => setModal(() => livraisonSelect = 'Retrait')),
                const SizedBox(width: 10),
                _toggleLivraison('🤝', 'Les deux',
                    livraisonSelect == 'Les deux',
                    () => setModal(
                        () => livraisonSelect = 'Les deux')),
              ]),
              const SizedBox(height: 16),

              // Statut actif
              Row(children: [
                const Text('🟢  Fournisseur actif',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                const Spacer(),
                Switch(
                  value: actifSelect,
                  activeColor: green,
                  onChanged: (v) => setModal(() => actifSelect = v),
                ),
              ]),
              const SizedBox(height: 12),

              _champ(prixCtrl, '💰  Prix moyen (optionnel)',
                  Icons.attach_money,
                  isNumber: true),
              const SizedBox(height: 20),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.save),
                  label: Text(
                    existant == null
                        ? 'Enregistrer'
                        : 'Sauvegarder',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  onPressed: () async {
                    if (nomCtrl.text.isEmpty || telCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Remplissez nom et téléphone'),
                              backgroundColor: Colors.red));
                      return;
                    }
                    Navigator.pop(ctx);
                    if (existant == null) {
                      final f = Fournisseur(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        nom:              nomCtrl.text,
                        telephone:        telCtrl.text,
                        produitPrincipal: catSelect,
                        ville:            villeSelect,
                        modeLivraison:    livraisonSelect,
                        prixMoyen: double.tryParse(prixCtrl.text) ?? 0,
                        actif: actifSelect,
                      );
                      await _ajouterFournisseur(f);
                    } else {
                      existant.nom              = nomCtrl.text;
                      existant.telephone        = telCtrl.text;
                      existant.produitPrincipal = catSelect;
                      existant.ville            = villeSelect;
                      existant.modeLivraison    = livraisonSelect;
                      existant.prixMoyen =
                          double.tryParse(prixCtrl.text) ?? 0;
                      existant.actif = actifSelect;
                      await _modifierFournisseur(existant);
                    }
                  },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _toggleLivraison(
          String emoji, String label, bool sel, VoidCallback onTap) =>
      Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? green.withOpacity(0.1) : Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: sel ? green : Colors.transparent, width: 2),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: sel ? green : Colors.grey[600],
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal)),
            ]),
          ),
        ),
      );

  // ─────────────────────────────────────────
  // DÉTAIL FOURNISSEUR
  // ─────────────────────────────────────────
  void _ouvrirDetail(Fournisseur f) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, sc) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: sc,
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),

              // En-tête
              Row(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: greenLight,
                      borderRadius: BorderRadius.circular(16)),
                  child: Center(
                      child: Text(_emoji(f.produitPrincipal),
                          style: const TextStyle(fontSize: 32))),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(f.nom,
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Row(children: [
                      const Icon(Icons.location_on,
                          size: 14, color: Colors.orange),
                      Text(f.ville,
                          style: const TextStyle(
                              color: Colors.orange, fontSize: 13)),
                      const SizedBox(width: 10),
                      Icon(Icons.circle,
                          size: 10,
                          color: f.actif ? green : Colors.red),
                      const SizedBox(width: 4),
                      Text(f.actif ? 'Actif' : 'Inactif',
                          style: TextStyle(
                              color: f.actif ? green : Colors.red,
                              fontSize: 12)),
                    ]),
                  ]),
                ),
                if (f.fiable)
                  const Text('🏅', style: TextStyle(fontSize: 28)),
              ]),

              const SizedBox(height: 16),

              // Note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: amber.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  const Text('⭐', style: TextStyle(fontSize: 28)),
                  const SizedBox(width: 12),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text('${f.note.toStringAsFixed(1)}/5',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: amber)),
                    Text('${f.nombreAvis} avis',
                        style: const TextStyle(
                            color: Colors.grey, fontSize: 12)),
                  ]),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _ouvrirNote(f);
                    },
                    style: ElevatedButton.styleFrom(
                        backgroundColor: amber,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8)),
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Noter',
                        style: TextStyle(fontSize: 13)),
                  ),
                ]),
              ),

              const SizedBox(height: 16),

              // Actions
              Row(children: [
                Expanded(
                    child: _actionBtn(
                        icon: Icons.phone,
                        label: 'Appeler',
                        couleur: Colors.blue,
                        onTap: () => _appeler(f))),
                const SizedBox(width: 10),
                Expanded(
                    child: _actionBtn(
                        icon: Icons.edit,
                        label: 'Modifier',
                        couleur: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          _ouvrirFormulaireAjout(existant: f);
                        })),
                const SizedBox(width: 10),
                Expanded(
                    child: _actionBtn(
                        icon: Icons.delete,
                        label: 'Supprimer',
                        couleur: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          _confirmerSuppression(f);
                        })),
              ]),

              const SizedBox(height: 20),
              const Divider(),

              // Produits
              Row(children: [
                const Text('🛒 Produits disponibles',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _ajouterProduitDialog(f);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                        color: greenLight,
                        borderRadius: BorderRadius.circular(8)),
                    child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                      Icon(Icons.add, color: green, size: 16),
                      SizedBox(width: 4),
                      Text('Ajouter',
                          style: TextStyle(
                              color: green,
                              fontSize: 12,
                              fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ),
              ]),
              const SizedBox(height: 12),

              if (f.produits.isEmpty)
                const Center(
                    child: Text('Aucun produit enregistré',
                        style: TextStyle(color: Colors.grey)))
              else
                ...f.produits
                    .map((p) => _carteProduitDetail(p, f)),

              const SizedBox(height: 20),

              // Commentaires
              const Text('💬 Commentaires',
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (f.commentaires.isEmpty)
                const Text('Aucun commentaire',
                    style: TextStyle(color: Colors.grey))
              else
                ...f.commentaires.map((c) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                          color: greenLight,
                          borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        const Text('💬',
                            style: TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(c.texte,
                                style: const TextStyle(
                                    fontSize: 13))),
                        Text(
                          _formatDate(c.creeLe),
                          style: const TextStyle(
                              fontSize: 10, color: Colors.grey),
                        ),
                      ]),
                    )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _carteProduitDetail(ProduitFournisseur p, Fournisseur f) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey.withOpacity(0.2)),
        ),
        child: Row(children: [
          Text(_emoji(p.categorie),
              style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(p.nom,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700)),
              Row(children: [
                const Icon(Icons.inventory,
                    size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Stock : ${p.stockDisponible}',
                    style: const TextStyle(
                        color: Colors.grey, fontSize: 11)),
              ]),
            ]),
          ),
          Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
            Text('${_formatPrix(p.prix)} F',
                style: const TextStyle(
                    color: green,
                    fontWeight: FontWeight.w800,
                    fontSize: 15)),
            const SizedBox(height: 4),
            Row(children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _ouvrirCommande(f, produitSelectionne: p);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(6)),
                  child: const Text('🛒',
                      style: TextStyle(fontSize: 14)),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: () => _supprimerProduitFournisseur(p.id),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6)),
                  child: const Icon(Icons.delete,
                      size: 14, color: Colors.red),
                ),
              ),
            ]),
          ]),
        ]),
      );

  // ─────────────────────────────────────────
  // AJOUTER PRODUIT FOURNISSEUR
  // ─────────────────────────────────────────
  void _ajouterProduitDialog(Fournisseur f) {
    final nomCtrl   = TextEditingController();
    final prixCtrl  = TextEditingController();
    final stockCtrl = TextEditingController(text: '0');
    String cat = f.produitPrincipal;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              const Text('📦', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Text('Ajouter un produit',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: green)),
            ]),
            const SizedBox(height: 16),
            _champ(nomCtrl, 'Nom du produit *', Icons.label),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                  child: _champ(
                      prixCtrl, 'Prix *', Icons.attach_money,
                      isNumber: true)),
              const SizedBox(width: 10),
              Expanded(
                  child: _champ(stockCtrl, 'Stock disponible',
                      Icons.inventory,
                      isNumber: true)),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: green,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12))),
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
                onPressed: () async {
                  if (nomCtrl.text.isEmpty ||
                      prixCtrl.text.isEmpty) return;
                  final p = ProduitFournisseur(
                    id: DateTime.now()
                        .millisecondsSinceEpoch
                        .toString(),
                    nom: nomCtrl.text,
                    categorie: cat,
                    prix: double.tryParse(prixCtrl.text) ?? 0,
                    stockDisponible:
                        int.tryParse(stockCtrl.text) ?? 0,
                  );
                  Navigator.pop(ctx);
                  await _ajouterProduitFournisseur(f.id, p);
                },
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // PASSER COMMANDE
  // ─────────────────────────────────────────
  void _ouvrirCommande(Fournisseur f,
      {ProduitFournisseur? produitSelectionne}) {
    if (f.produits.isEmpty) {
      _toast('Ce fournisseur n\'a pas de produits', success: false);
      return;
    }
    ProduitFournisseur? choisi =
        produitSelectionne ?? f.produits.first;
    final qteCtrl = TextEditingController(text: '1');
    DateTime dateLiv =
        DateTime.now().add(const Duration(days: 3));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) {
          final qte = int.tryParse(qteCtrl.text) ?? 1;
          final total = (choisi?.prix ?? 0) * qte;

          return Padding(
            padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom:
                    MediaQuery.of(ctx).viewInsets.bottom + 20),
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Center(
                    child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius:
                                BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(children: [
                  const Text('🛒',
                      style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text('Commander chez ${f.nom}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: green))),
                ]),
                const SizedBox(height: 16),

                const Text('📦  Choisir le produit',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ...f.produits.map((p) => GestureDetector(
                      onTap: () => setM(() => choisi = p),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: choisi?.id == p.id
                              ? green.withOpacity(0.1)
                              : Colors.grey[50],
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color: choisi?.id == p.id
                                  ? green
                                  : Colors.grey
                                      .withOpacity(0.2),
                              width:
                                  choisi?.id == p.id ? 2 : 1),
                        ),
                        child: Row(children: [
                          Text(_emoji(p.categorie),
                              style:
                                  const TextStyle(fontSize: 22)),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(p.nom,
                                  style: const TextStyle(
                                      fontWeight:
                                          FontWeight.w600))),
                          Text('${_formatPrix(p.prix)} F',
                              style: const TextStyle(
                                  color: green,
                                  fontWeight:
                                      FontWeight.bold)),
                        ]),
                      ),
                    )),

                const SizedBox(height: 12),
                const Text('🔢  Quantité',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Row(children: [
                  GestureDetector(
                    onTap: () {
                      final q =
                          int.tryParse(qteCtrl.text) ?? 1;
                      if (q > 1)
                        setM(() => qteCtrl.text = '${q - 1}');
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: const Icon(Icons.remove, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: qteCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20,
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
                                color: green, width: 2)),
                        contentPadding:
                            const EdgeInsets.symmetric(
                                vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      final q =
                          int.tryParse(qteCtrl.text) ?? 1;
                      setM(() => qteCtrl.text = '${q + 1}');
                    },
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                          color: green,
                          borderRadius:
                              BorderRadius.circular(10)),
                      child: const Icon(Icons.add,
                          color: Colors.white, size: 22),
                    ),
                  ),
                ]),

                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: greenLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    const Text('💰',
                        style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                      const Text('Prix total',
                          style: TextStyle(
                              color: Colors.grey, fontSize: 12)),
                      Text('${_formatPrix(total)} FCFA',
                          style: const TextStyle(
                              color: green,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                    ]),
                  ]),
                ),

                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: dateLiv,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now()
                          .add(const Duration(days: 90)),
                      builder: (_, child) => Theme(
                        data: Theme.of(ctx).copyWith(
                            colorScheme:
                                const ColorScheme.light(
                                    primary: green)),
                        child: child!,
                      ),
                    );
                    if (date != null)
                      setM(() => dateLiv = date);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(children: [
                      const Text('📅',
                          style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 10),
                      Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                        const Text('Date de livraison',
                            style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12)),
                        Text(_formatDate(dateLiv),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15)),
                      ]),
                      const Spacer(),
                      const Icon(Icons.edit_calendar,
                          color: green),
                    ]),
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                    ),
                    icon: const Text('📦',
                        style: TextStyle(fontSize: 20)),
                    label: const Text('Envoyer la commande',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    onPressed: () async {
                      if (choisi == null) return;
                      final qte =
                          int.tryParse(qteCtrl.text) ?? 1;
                      final commande = Commande(
                        id: DateTime.now()
                            .millisecondsSinceEpoch
                            .toString(),
                        fournisseurId:  f.id,
                        fournisseurNom: f.nom,
                        produitNom:     choisi!.nom,
                        quantite:       qte,
                        prixTotal:      choisi!.prix * qte,
                        dateCommande:   DateTime.now(),
                        dateLivraison:  dateLiv,
                      );
                      Navigator.pop(ctx);
                      await _envoyerCommande(commande);
                    },
                  ),
                ),
              ]),
            ),
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────
  // NOTER UN FOURNISSEUR
  // ─────────────────────────────────────────
  void _ouvrirNote(Fournisseur f) {
    double noteChoisie = 0;
    final commentCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20,
              bottom:
                  MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius:
                            BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            const Text('⭐ Noter ce fournisseur',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                5,
                (i) => GestureDetector(
                  onTap: () => setM(() => noteChoisie = i + 1.0),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6),
                    child: Icon(
                      i < noteChoisie
                          ? Icons.star
                          : Icons.star_border,
                      size: 42, color: amber,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text(
              noteChoisie == 5
                  ? '🎉 Excellent !'
                  : noteChoisie >= 4
                      ? '😊 Très bien'
                      : noteChoisie >= 3
                          ? '👍 Bien'
                          : noteChoisie >= 2
                              ? '😐 Moyen'
                              : '👎 Mauvais',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: commentCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: '💬 Laisser un commentaire...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: green, width: 2)),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: amber,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: noteChoisie == 0
                    ? null
                    : () async {
                        Navigator.pop(ctx);
                        await _enregistrerNote(
                            f,
                            noteChoisie,
                            commentCtrl.text.isNotEmpty
                                ? commentCtrl.text
                                : null);
                      },
                child: const Text('Enregistrer la note',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // SUPPRIMER FOURNISSEUR
  // ─────────────────────────────────────────
  void _confirmerSuppression(Fournisseur f) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Text('🗑️', style: TextStyle(fontSize: 24)),
          SizedBox(width: 8),
          Text('Supprimer',
              style: TextStyle(color: Colors.red, fontSize: 17)),
        ]),
        content: Text(
            'Supprimer "${f.nom}" ?\nCette action est irréversible.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
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

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  void _appeler(Fournisseur f) {
    _toast('📞 Appel vers ${f.telephone}', success: true);
    // TODO: url_launcher → tel:+221${f.telephone}
  }

  String _emoji(String cat) {
    switch (cat) {
      case 'Alimentaire': return '🍚';
      case 'Boissons':    return '🥤';
      case 'Hygiène':     return '🧼';
      default:            return '📦';
    }
  }

  Widget _champ(TextEditingController ctrl, String label,
      IconData icon, {bool isNumber = false}) =>
      TextFormField(
        controller: ctrl,
        keyboardType:
            isNumber ? TextInputType.number : TextInputType.text,
        inputFormatters: isNumber
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: green, size: 20),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: green, width: 2)),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 14),
        ),
      );

  void _toast(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? green : Colors.red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatPrix(double p) {
    if (p >= 1000000)
      return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000) return '${(p / 1000).toStringAsFixed(0)}k';
    return p.toStringAsFixed(0);
  }
}
