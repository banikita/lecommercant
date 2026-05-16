import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'page_stock.dart' as stock_view;
import 'scanner_page.dart' as global_scanner;
import 'package:url_launcher/url_launcher.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────────────────────────────────────────
class _DS {
  static const emerald      = Color(0xFF0A5C47);
  static const emeraldMid   = Color(0xFF0D7A5F);
  static const emeraldFaint = Color(0xFFE8F5F0);
  static const gold         = Color(0xFFD4940A);
  static const goldLight    = Color(0xFFFFF0C2);
  static const coral        = Color(0xFFCC3B3B);
  static const coralLight   = Color(0xFFFFF0F0);
  static const orange       = Color(0xFFE8720C);
  static const orangeLight  = Color(0xFFFFF3EB);
  static const sky          = Color(0xFF1565C0);
  static const skyLight     = Color(0xFFE3F2FD);
  static const ink          = Color(0xFF0F1A14);
  static const slate        = Color(0xFF6B7A72);
  static const fog          = Color(0xFFF3F6F4);
  static const mist         = Color(0xFFE8EDE9);
  static const white        = Color(0xFFFFFFFF);

  static const headerGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A5C47), Color(0xFF0D7A5F), Color(0xFF0F926F)],
    stops: [0.0, 0.55, 1.0],
  );

  static List<BoxShadow> get shadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.07),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static TextStyle label(double sz,
      {Color c = ink, FontWeight fw = FontWeight.w600}) =>
      TextStyle(fontSize: sz, fontWeight: fw, color: c);
}

// ─────────────────────────────────────────────────────────────────────────────
// MODÈLE LIGNE PANIER
// ─────────────────────────────────────────────────────────────────────────────
class _LignePanier {
  final String productId;
  final String nom;
  final String categorie;
  final String? imageUrl;
  final double prixUnitaire;
  final int    quantite;
  final int    stockMax;

  const _LignePanier({
    required this.productId,
    required this.nom,
    required this.categorie,
    this.imageUrl,
    required this.prixUnitaire,
    required this.quantite,
    this.stockMax = 9999,
  });

  double get sousTotal => prixUnitaire * quantite;

  _LignePanier copyWith({int? quantite}) => _LignePanier(
    productId: productId, nom: nom, categorie: categorie, imageUrl: imageUrl,
    prixUnitaire: prixUnitaire, stockMax: stockMax,
    quantite: quantite ?? this.quantite,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIG MODE PAIEMENT — avec logo optionnel
// ─────────────────────────────────────────────────────────────────────────────
class _ModeConfig {
  final String key, emoji, label;
  final Color color, bgColor;
  final String? logoAsset;

  const _ModeConfig(
    this.key,
    this.emoji,
    this.color,
    this.bgColor,
    this.label, {
    this.logoAsset,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// PAGE PRINCIPALE
// ─────────────────────────────────────────────────────────────────────────────
class NouvelleVentePage extends StatefulWidget {
  final int commercantId;
  final String? nomCommercant;
  final String? nomBoutique;

  const NouvelleVentePage({
    super.key,
    required this.commercantId,
    this.nomCommercant,
    this.nomBoutique,
  });

  @override
  State<NouvelleVentePage> createState() => _NouvelleVentePageState();
}

class _NouvelleVentePageState extends State<NouvelleVentePage>
    with TickerProviderStateMixin {

  final supabase = Supabase.instance.client;
  final List<_LignePanier> _panier = [];
  String _modePaiement = 'Payé';
  final _nomClientCtrl = TextEditingController();
  bool _enregistrement = false;

  late AnimationController _totalAnimCtrl;
  late Animation<double>   _totalScaleAnim;

  static const _modes = [
    _ModeConfig(
      'Payé', '💵', Colors.green, Color(0xFFF1FFF5), 'Cash',
      logoAsset: 'lib/assets/categories/cash.jpeg',
    ),
    _ModeConfig(
      'Wave', '🌊', _DS.sky, _DS.skyLight, 'Wave',
      logoAsset: 'lib/assets/categories/wave.png',
    ),
    _ModeConfig(
      'Orange Money', '🟠', _DS.orange, _DS.orangeLight, 'OM',
      logoAsset: 'lib/assets/categories/om.jpg',
    ),
    _ModeConfig(
      'À crédit', '📒', _DS.coral, _DS.coralLight, 'Crédit',
      logoAsset: 'lib/assets/categories/credit.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _totalAnimCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _totalScaleAnim = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 40),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _totalAnimCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _nomClientCtrl.dispose();
    _totalAnimCtrl.dispose();
    super.dispose();
  }

  double get _total      => _panier.fold(0.0, (s, l) => s + l.sousTotal);
  int    get _nbArticles => _panier.fold(0, (s, l) => s + l.quantite);

  // ── SCAN ──────────────────────────────────────────────────────────────────
  Future<void> _scannerProduit() async {
    final String? code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const global_scanner.ScannerPage()),
    );
    if (code == null || !mounted) return;
    await _ajouterParBarcode(code);
  }

  Future<void> _ajouterParBarcode(String barcode) async {
    try {
      final result = await supabase
          .from('products').select()
          .eq('barcode', barcode)
          .eq('commercant_id', widget.commercantId)
          .maybeSingle();

      if (result == null) {
        _toast('Produit introuvable pour ce code', erreur: true); return;
      }
      final stock = (result['quantity'] as int?) ?? 0;
      if (stock <= 0) {
        _toast('Stock vide pour ${result['name']}', erreur: true); return;
      }
      _ajouterAuPanier(result, 1);
      HapticFeedback.mediumImpact();
    } catch (e) {
      _toast('Erreur scan : $e', erreur: true);
    }
  }

  // ── STOCK — sélection produit ─────────────────────────────────────────────
  Future<void> _ouvrirStock() async {
    final result = await Navigator.push<List<Map<String, dynamic>>>(
      context,
      MaterialPageRoute(
        builder: (_) => stock_view.StockPage(
          commercantId: widget.commercantId,
          isSelectionMode: true,
        ),
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;
    for (final item in result) {
      _ajouterAuPanier({
        'id':        item['id']       ?? '',
        'name':      item['name']     ?? item['nom'] ?? '',
        'price':     item['price']    ?? item['prix'] ?? 0,
        'category':  item['category'] ?? 'Autre',
        'quantity':  item['quantity'] ?? 9999,
        'image_url': item['imageUrl'],
      }, (item['quantite'] as int?) ?? 1);
    }
    _toast('${result.length} produit(s) ajouté(s) au panier');
  }

  void _ajouterAuPanier(Map<String, dynamic> produit, int quantite) {
    setState(() {
      final idx = _panier.indexWhere(
          (l) => l.productId == produit['id'].toString());
      if (idx >= 0) {
        final newQty = (_panier[idx].quantite + quantite)
            .clamp(1, _panier[idx].stockMax);
        _panier[idx] = _panier[idx].copyWith(quantite: newQty);
      } else {
        _panier.add(_LignePanier(
          productId:    produit['id'].toString(),
          nom:          produit['name'] as String,
          categorie:    produit['category'] as String? ?? 'Autre',
          prixUnitaire: (produit['price'] as num).toDouble(),
          quantite:     quantite,
          stockMax:     (produit['quantity'] as int?) ?? 9999,
          imageUrl:     produit['image_url'] as String?,
        ));
      }
    });
    _totalAnimCtrl.forward(from: 0);
  }

  void _changerQuantite(int index, int delta) {
    setState(() {
      final newQty = _panier[index].quantite + delta;
      if (newQty <= 0) {
        _panier.removeAt(index);
      } else {
        _panier[index] = _panier[index].copyWith(
            quantite: newQty.clamp(1, _panier[index].stockMax));
      }
    });
    if (delta > 0) _totalAnimCtrl.forward(from: 0);
  }

  // ── MAPPING STATUT PAIEMENT ───────────────────────────────────────────────
  String get _statutPourBD {
    switch (_modePaiement) {
      case 'À crédit': return 'À crédit';
      default:         return 'Payé';
    }
  }

  // ── ENREGISTREMENT (avec notification à l'autre commerçant) ──────────────
  Future<void> _confirmerEtEnregistrer() async {
    if (_panier.isEmpty) {
      _toast('Ajoutez au moins un produit', erreur: true); return;
    }
    if (_modePaiement == 'À crédit' && _nomClientCtrl.text.trim().isEmpty) {
      _toast('Entrez le nom du client pour le crédit', erreur: true); return;
    }

    setState(() => _enregistrement = true);
    try {
      final now = DateTime.now().toIso8601String();

      final Map<String, dynamic> venteData = {
        'commercant_id':   widget.commercantId,
        'total_montant':   _total,
        'statut_paiement': _statutPourBD,
        'nom_client':      _nomClientCtrl.text.trim().isEmpty
            ? null : _nomClientCtrl.text.trim(),
        'date_vente':      now,
        'mode_paiement':   _modePaiement,
      };

      final venteRes = await supabase
          .from('ventes')
          .insert(venteData)
          .select()
          .single();

      final int venteId = venteRes['id'] as int;

      for (final ligne in _panier) {
        await supabase.from('ventes_items').insert({
          'vente_id':      venteId,
          'product_id':    ligne.productId,
          'nom_produit':   ligne.nom,
          'categorie':     ligne.categorie,
          'quantite':      ligne.quantite,
          'prix_unitaire': ligne.prixUnitaire,
          'sous_total':    ligne.sousTotal,
          'image_url':     ligne.imageUrl,
        });

        final stock = await supabase
            .from('products').select('quantity')
            .eq('id', ligne.productId).maybeSingle();
        if (stock != null) {
          final newQty =
              ((stock['quantity'] as int) - ligne.quantite).clamp(0, 9999);
          await supabase.from('products')
              .update({'quantity': newQty}).eq('id', ligne.productId);
        }
      }

      if (_modePaiement == 'À crédit') {
        final nomClient = _nomClientCtrl.text.trim();

        var debiteurRes = await supabase
            .from('debiteurs')
            .select()
            .eq('commercant_id', widget.commercantId)
            .eq('nom', nomClient)
            .maybeSingle();

        int debiteurId;
        if (debiteurRes == null) {
          final newDebiteur = await supabase.from('debiteurs').insert({
            'commercant_id': widget.commercantId,
            'nom':           nomClient,
            'created_at':    now,
            'updated_at':    now,
          }).select().single();
          debiteurId = newDebiteur['id'] as int;
        } else {
          debiteurId = debiteurRes['id'] as int;
        }

        // 🔥 Ajout d'une échéance par défaut (30 jours)
        final echeance = DateTime.now().add(const Duration(days: 30)).toIso8601String().split('T').first;

        final detteRes = await supabase.from('dettes').insert({
          'commercant_id':     widget.commercantId,
          'nom_debiteur':      nomClient,
          'debiteur_id':       debiteurId,
          'montant_initial':   _total,
          'montant_rembourse': 0,
          'statut':            'en_cours',
          'echeance':          echeance,   // ← échéance par défaut
          'created_at':        now,
          'updated_at':        now,
        }).select().single();

        final int detteId = detteRes['id'] as int;

        for (final ligne in _panier) {
          await supabase.from('dette_produits').insert({
            'dette_id':      detteId,
            'product_id':    ligne.productId,
            'product_name':  ligne.nom,
            'quantite':      ligne.quantite,
            'prix_unitaire': ligne.prixUnitaire,
            'image_url':     ligne.imageUrl,   // ✅ image sauvegardée
          });
        }

        // ── Notification (à conserver ou commenter)
        final autreCommercant = await supabase
            .from('commercants')
            .select('id')
            .eq('nom', nomClient)
            .maybeSingle();

        if (autreCommercant != null && autreCommercant['id'] != widget.commercantId) {
          await supabase.from('notifications').insert({
            'commercant_id': autreCommercant['id'],
            'titre': 'Invitation créancier',
            'message': '${widget.nomCommercant ?? "Un commerçant"} vous a ajouté comme débiteur. Souhaitez-vous l’ajouter comme créancier ?',
            'est_lu': false,
            'created_at': now,
          });
        }
      }

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      _afficherSucces();
    } catch (e) {
      debugPrint("Erreur vente: $e");
      _toast('Erreur : $e', erreur: true);
    } finally {
      if (mounted) setState(() => _enregistrement = false);
    }
  }

  void _afficherSucces() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 72, height: 72,
              decoration: const BoxDecoration(
                  color: _DS.emeraldFaint, shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded,
                  color: _DS.emeraldMid, size: 44),
            ),
            const SizedBox(height: 16),
            Text('Vente enregistrée !',
                style: _DS.label(18, c: _DS.ink, fw: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${_fmt(_total)} F CFA · $_modePaiement',
                style: _DS.label(14, c: _DS.slate)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _DS.emeraldMid,
                  foregroundColor: _DS.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Terminé',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                setState(() {
                  _panier.clear();
                  _nomClientCtrl.clear();
                  _modePaiement = 'Payé';
                });
              },
              child: Text('Nouvelle vente',
                  style: _DS.label(14,
                      c: _DS.emeraldMid, fw: FontWeight.w700)),
            ),
          ]),
        ),
      ),
    );
  }

  // ── HELPERS ───────────────────────────────────────────────────────────────
  void _toast(String msg, {bool erreur = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              fontWeight: FontWeight.w600, color: _DS.white)),
      backgroundColor: erreur ? _DS.coral : _DS.emeraldMid,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _fmt(double n) => n.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');

  /// Image de catégorie (fallback)
  Widget _catImage(String cat, {double size = 40}) {
    const map = {
      'Alimentaire': 'lib/assets/categories/aliment.jpg',
      'Boissons':    'lib/assets/categories/boisson.jpg',
      'Hygiène':     'lib/assets/categories/hygienne.jpg',
    };
    final path = map[cat] ?? 'lib/assets/categories/produit.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 3),
      child: Image.asset(path,
          width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            cat == 'Alimentaire'
                ? '🍞'
                : cat == 'Boissons'
                    ? '🥤'
                    : cat == 'Hygiène'
                        ? '🧴'
                        : '📦',
            style: TextStyle(fontSize: size * 0.55),
          )),
    );
  }

  /// Image du produit (URL réseau) — fallback sur image de catégorie
  Widget _productImage(_LignePanier ligne, {double size = 56}) {
    if (ligne.imageUrl != null && ligne.imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          ligne.imageUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (_, child, progress) {
            if (progress == null) return child;
            return Container(
              width: size,
              height: size,
              color: _DS.emeraldFaint,
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
          errorBuilder: (_, __, ___) => _catImage(ligne.categorie, size: size),
        ),
      );
    }
    return _catImage(ligne.categorie, size: size);
  }

  // ── BUILD PRINCIPAL ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _DS.fog,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildBarreActions(),
          Expanded(
            child: _panier.isEmpty
                ? _buildPanierVide()
                : _buildListePanier(),
          ),
          _buildModePaiement(),
          _buildFooter(),
        ]),
      ),
    );
  }

  // ── HEADER ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: _DS.headerGrad),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nouvelle Vente',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    )),
                Text(
                  _panier.isEmpty
                      ? 'Panier vide'
                      : '$_nbArticles article${_nbArticles > 1 ? 's' : ''}',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 12),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _scannerProduit,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.qr_code_scanner,
                    color: Colors.white, size: 18),
                SizedBox(width: 6),
                Text('Scanner',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ── BARRE D'ACTIONS ───────────────────────────────────────────────────────
  Widget _buildBarreActions() {
    return Container(
      decoration: const BoxDecoration(gradient: _DS.headerGrad),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: SizedBox(
        height: 52,
        child: Row(children: [
          Expanded(
            flex: 5,
            child: _ActionButton(
              onTap: _scannerProduit,
              color: _DS.orange,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('📷', style: TextStyle(fontSize: 18)),
                  SizedBox(width: 8),
                  Text('SCANNER UN PRODUIT',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 0.3)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: _ActionButton(
              onTap: _ouvrirStock,
              color: Colors.white.withValues(alpha: 0.15),
              border: Border.all(color: Colors.white30),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🧺', style: TextStyle(fontSize: 16)),
                  SizedBox(height: 2),
                  Text('MON STOCK',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5)),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── PANIER VIDE ───────────────────────────────────────────────────────────
  Widget _buildPanierVide() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 24),
        Container(
          width: 90, height: 90,
          decoration:
              const BoxDecoration(color: _DS.mist, shape: BoxShape.circle),
          child: const Center(
              child: Text('🛒', style: TextStyle(fontSize: 44))),
        ),
        const SizedBox(height: 16),
        Text('Panier vide',
            style: _DS.label(20, c: _DS.ink, fw: FontWeight.w800)),
        const SizedBox(height: 6),
        Text('Scannez un article ou choisissez\ndans votre stock',
            textAlign: TextAlign.center,
            style: _DS.label(13, c: _DS.slate, fw: FontWeight.w400)),
        const SizedBox(height: 28),
        GestureDetector(
          onTap: _scannerProduit,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [_DS.orange, Color(0xFFF09000)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: _DS.orange.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6)),
              ],
            ),
            child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.qr_code_scanner,
                      color: Colors.white, size: 22),
                  SizedBox(width: 10),
                  Text('Scanner un produit',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14)),
                ]),
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _ouvrirStock,
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: _DS.emeraldFaint,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: _DS.emeraldMid.withValues(alpha: 0.3)),
            ),
            child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: _DS.emeraldMid, size: 20),
                  const SizedBox(width: 8),
                  Text('Choisir dans le stock',
                      style: _DS.label(14,
                          c: _DS.emeraldMid, fw: FontWeight.w700)),
                ]),
          ),
        ),
        const SizedBox(height: 16),
      ]),
    );
  }

  // ── LISTE PANIER ──────────────────────────────────────────────────────────
  Widget _buildListePanier() {
    return Column(children: [
      Container(
        color: _DS.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
                color: _DS.emeraldFaint,
                borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.shopping_cart_outlined,
                  color: _DS.emeraldMid, size: 14),
              const SizedBox(width: 4),
              Text(
                  '$_nbArticles article${_nbArticles > 1 ? 's' : ''}',
                  style: _DS.label(12,
                      c: _DS.emeraldMid, fw: FontWeight.w700)),
            ]),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => setState(() => _panier.clear()),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: _DS.coralLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.delete_outline,
                    color: _DS.coral, size: 14),
                const SizedBox(width: 4),
                Text('Vider',
                    style: _DS.label(12,
                        c: _DS.coral, fw: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          itemCount: _panier.length,
          itemBuilder: (_, i) => _buildLignePanier(i),
        ),
      ),
    ]);
  }

  Widget _buildLignePanier(int i) {
    final ligne = _panier[i];
    return Dismissible(
      key: ValueKey(ligne.productId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
            color: _DS.coral,
            borderRadius: BorderRadius.circular(16)),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete_outline,
            color: Colors.white, size: 24),
      ),
      onDismissed: (_) => setState(() => _panier.removeAt(i)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _DS.shadowSm,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            _productImage(ligne, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ligne.nom,
                      style:
                          _DS.label(13, c: _DS.ink, fw: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text('${_fmt(ligne.prixUnitaire)} F / unité',
                      style: _DS.label(11,
                          c: _DS.slate, fw: FontWeight.w500)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: _DS.emeraldFaint,
                        borderRadius: BorderRadius.circular(8)),
                    child: Text('${_fmt(ligne.sousTotal)} F',
                        style: _DS.label(12,
                            c: _DS.emeraldMid, fw: FontWeight.w900)),
                  ),
                ],
              ),
            ),
            _QtyControl(
              value: ligne.quantite,
              max: ligne.stockMax,
              onMinus: () => _changerQuantite(i, -1),
              onPlus: () => _changerQuantite(i, 1),
            ),
          ]),
        ),
      ),
    );
  }

  // ── MODE PAIEMENT ─────────────────────────────────────────────────────────
  Widget _buildModePaiement() {
    return Container(
      color: _DS.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                    color: _DS.emeraldMid,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 6),
            Text('Paiement',
                style: _DS.label(13, c: _DS.ink, fw: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),

          Row(
            children: _modes.map((m) {
              final bool sel = _modePaiement == m.key;
              return Expanded(
                child: GestureDetector(
                  onTap: () async {
                    setState(() => _modePaiement = m.key);
                    if (m.key == 'Wave') {
                      final uri = Uri.parse('wave://');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri,
                            mode: LaunchMode.externalApplication);
                      }
                    } else if (m.key == 'Orange Money') {
                      final uri = Uri.parse('tel:#144#');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    height: 56,
                    decoration: BoxDecoration(
                      color: sel ? m.bgColor : _DS.fog,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: sel ? m.color : _DS.mist,
                          width: sel ? 2 : 1),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                  color: m.color.withValues(alpha: 0.15),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2))
                            ]
                          : [],
                    ),
                    child: m.logoAsset != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(sel ? 10 : 11),
                            child: Image.asset(
                              m.logoAsset!,
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Text(m.emoji,
                                    style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(m.emoji,
                                  style: const TextStyle(fontSize: 22)),
                              const SizedBox(height: 2),
                              Text(
                                m.label,
                                style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: sel
                                        ? FontWeight.w800
                                        : FontWeight.w500,
                                    color: sel ? m.color : _DS.slate),
                              ),
                            ],
                          ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (_modePaiement == 'À crédit') ...[
            const SizedBox(height: 10),
            TextField(
              controller: _nomClientCtrl,
              decoration: InputDecoration(
                hintText: 'Nom complet du client',
                hintStyle: _DS.label(13,
                    c: _DS.slate, fw: FontWeight.w400),
                prefixIcon: const Icon(Icons.person_outline,
                    color: _DS.coral, size: 20),
                filled: true,
                fillColor: _DS.coralLight,
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: _DS.coral, width: 2)),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── FOOTER ────────────────────────────────────────────────────────────────
  Widget _buildFooter() {
    final Map<String, Color> modeClr = {
      'Payé':         Colors.green.shade700,
      'Wave':         _DS.sky,
      'Orange Money': _DS.orange,
      'À crédit':     _DS.coral,
    };
    final accentColor = modeClr[_modePaiement] ?? _DS.emeraldMid;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: _DS.white,
        border: Border(top: BorderSide(color: _DS.mist, width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(
                '$_nbArticles article${_nbArticles > 1 ? 's' : ''}',
                style: _DS.label(13, c: _DS.slate)),
            Row(children: [
              Text('TOTAL  ',
                  style:
                      _DS.label(14, c: _DS.ink, fw: FontWeight.w700)),
              AnimatedBuilder(
                animation: _totalScaleAnim,
                builder: (_, child) => Transform.scale(
                    scale: _totalScaleAnim.value, child: child),
                child: Text('${_fmt(_total)} F',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: accentColor,
                        letterSpacing: -0.5)),
              ),
            ]),
          ]),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: (_panier.isEmpty || _enregistrement)
                ? null
                : _confirmerEtEnregistrer,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 15),
              decoration: BoxDecoration(
                gradient: _panier.isEmpty
                    ? null
                    : const LinearGradient(
                        colors: [_DS.emerald, _DS.emeraldMid],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                color: _panier.isEmpty ? _DS.mist : null,
                borderRadius: BorderRadius.circular(14),
                boxShadow: _panier.isEmpty
                    ? []
                    : [
                        BoxShadow(
                            color:
                                _DS.emeraldMid.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
              ),
              child: Center(
                child: _enregistrement
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_circle_outline,
                              color: _panier.isEmpty
                                  ? _DS.slate
                                  : Colors.white,
                              size: 20),
                          const SizedBox(width: 8),
                          Text(
                            _total > 0
                                ? 'CONFIRMER — ${_fmt(_total)} F CFA'
                                : 'CONFIRMER LA VENTE',
                            style: TextStyle(
                                color: _panier.isEmpty
                                    ? _DS.slate
                                    : Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.2),
                          ),
                        ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────────────────────────────────────────
class _ActionButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final BoxBorder? border;
  final Widget child;

  const _ActionButton({
    required this.onTap,
    required this.color,
    required this.child,
    this.border,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          transform: Matrix4.diagonal3Values(
              _pressed ? 0.96 : 1.0, _pressed ? 0.96 : 1.0, 1.0),
          height: double.infinity,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(12),
            border: widget.border,
          ),
          child: Center(child: widget.child),
        ),
      );
}

class _QtyControl extends StatelessWidget {
  final int value, max;
  final VoidCallback onMinus, onPlus;

  const _QtyControl({
    required this.value,
    required this.max,
    required this.onMinus,
    required this.onPlus,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: _DS.fog,
            borderRadius: BorderRadius.circular(10)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          GestureDetector(
            onTap: onMinus,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: _DS.coralLight,
                  borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(Icons.remove, color: _DS.coral, size: 16),
            ),
          ),
          SizedBox(
            width: 34,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: _DS.label(16, c: _DS.ink, fw: FontWeight.w900)),
          ),
          GestureDetector(
            onTap: value < max ? onPlus : null,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                  color: value < max ? _DS.emeraldFaint : _DS.mist,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.add,
                  color: value < max ? _DS.emeraldMid : _DS.slate,
                  size: 16),
            ),
          ),
        ]),
      );
}