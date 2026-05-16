import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

final _sb = Supabase.instance.client;

// ─────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────
class _S {
  static const emerald      = Color(0xFF0A5C47);
  static const emeraldMid   = Color(0xFF0D7A5F);
  static const emeraldFaint = Color(0xFFE8F5F0);
  static const emeraldGlow  = Color(0xFF1DC58A);
  static const gold         = Color(0xFFD4940A);
  static const goldLight    = Color(0xFFFFF0C2);
  static const coral        = Color(0xFFCC3B3B);
  static const coralLight   = Color(0xFFFFF0F0);
  static const orange       = Color(0xFFE8720C);
  static const orangeLight  = Color(0xFFFFF3EB);
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

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12, offset: const Offset(0, 3),
    ),
  ];

  static TextStyle label(double sz, {Color c = ink, FontWeight fw = FontWeight.w600}) =>
      TextStyle(fontSize: sz, fontWeight: fw, color: c);
}

// ─────────────────────────────────────────
// MODÈLE
// ─────────────────────────────────────────
class Product {
  final String id;
  String name, category;
  int quantity, minStock;
  double price;
  String? barcode, imageUrl;
  final DateTime addedDate;

  Product({
    required this.id, required this.name, required this.category,
    required this.quantity, required this.price, required this.minStock,
    this.barcode, this.imageUrl, required this.addedDate,
  });

  bool get stockFaible => quantity <= minStock && quantity > 0;
  bool get stockVide   => quantity == 0;
  bool get stockOk     => quantity > minStock;

  factory Product.fromMap(Map<String, dynamic> m) => Product(
    id: m['id'], name: m['name'],
    category: m['category'] ?? 'Alimentaire',
    quantity: (m['quantity'] as int?) ?? 0,
    price:    (m['price']    as num?)?.toDouble() ?? 0,
    minStock: (m['min_stock'] as int?) ?? 5,
    barcode:  m['barcode'], imageUrl: m['image_url'],
    addedDate: DateTime.parse(m['added_date']),
  );

  Map<String, dynamic> toMap(int cid) => {
    'id': id, 'commercant_id': cid, 'name': name, 'category': category,
    'quantity': quantity, 'price': price, 'min_stock': minStock,
    'barcode': barcode, 'image_url': imageUrl,
    'added_date': addedDate.toIso8601String(),
  };
}

// ─────────────────────────────────────────
// PAGE STOCK
// ─────────────────────────────────────────
class StockPage extends StatefulWidget {
  final int  commercantId;
  final bool isSelectionMode;
  const StockPage({super.key, required this.commercantId, this.isSelectionMode = false});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> with TickerProviderStateMixin {

  Uint8List? _imageBytesTemp;
  String?    _imageTempExt;

  late TabController   _tabCtrl;
  final _searchCtrl    = TextEditingController();
  final _searchFocus   = FocusNode();

  List<Product> _products = [];
  bool   _loading      = true;
  String _recherche    = '';
  String _filtreCat    = 'Tous';

  // ✅ FIX sélection : map productId → quantité sélectionnée
  final Map<String, int> _selection = {};

  final List<String> categories = ['Tous','Alimentaire','Boissons','Hygiène','Autre'];

  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _chargerProduits();
    _abonnerRealtime();
    _searchCtrl.addListener(() {
      setState(() => _recherche = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Realtime ──
  void _abonnerRealtime() {
    _channel = _sb.channel('products_changes')
      .onPostgresChanges(
        event: PostgresChangeEvent.all, schema: 'public', table: 'products',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'commercant_id', value: widget.commercantId,
        ),
        callback: (payload) {
          final ev = payload.eventType;
          if (ev == PostgresChangeEvent.insert) {
            final p = Product.fromMap(payload.newRecord);
            if (!_products.any((x) => x.id == p.id))
              setState(() => _products.insert(0, p));
          } else if (ev == PostgresChangeEvent.update) {
            final p = Product.fromMap(payload.newRecord);
            setState(() {
              final i = _products.indexWhere((x) => x.id == p.id);
              if (i != -1) _products[i] = p;
            });
            if (p.stockFaible || p.stockVide) _alerteStock(p);
          } else if (ev == PostgresChangeEvent.delete) {
            final id = payload.oldRecord['id'] as String?;
            if (id != null) setState(() => _products.removeWhere((x) => x.id == id));
          }
        },
      ).subscribe();
  }

  // ── Supabase CRUD ──
  Future<void> _chargerProduits() async {
    setState(() => _loading = true);
    try {
      final data = await _sb.from('products').select()
          .eq('commercant_id', widget.commercantId)
          .order('added_date', ascending: false);
      _products = (data as List).map((e) => Product.fromMap(e)).toList();
    } catch (e) {
      _toast('Erreur chargement : $e', ok: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _ajouterProduit(Product p) async {
    setState(() => _products.insert(0, p));
    try {
      await _sb.from('products').insert(p.toMap(widget.commercantId));
      _toast('✅ ${p.name} ajouté !', ok: true);
    } catch (e) {
      setState(() => _products.removeWhere((x) => x.id == p.id));
      _toast('Erreur : $e', ok: false);
    }
  }

  Future<void> _modifierProduit(Product p) async {
    final i = _products.indexWhere((x) => x.id == p.id);
    final old = i != -1 ? _products[i] : null;
    setState(() { if (i != -1) _products[i] = p; });
    try {
      await _sb.from('products').update(p.toMap(widget.commercantId)).eq('id', p.id);
      _toast('✅ ${p.name} modifié !', ok: true);
    } catch (e) {
      if (old != null) setState(() => _products[i] = old);
      _toast('Erreur : $e', ok: false);
    }
  }

  Future<void> _supprimerProduit(Product p) async {
    final i = _products.indexWhere((x) => x.id == p.id);
    setState(() => _products.removeWhere((x) => x.id == p.id));
    try {
      await _sb.from('products').delete().eq('id', p.id);
      if (p.imageUrl != null) {
        final fn = p.imageUrl!.split('/').last;
        await _sb.storage.from('product-images').remove([fn]);
      }
      _toast('Produit supprimé', ok: true);
    } catch (e) {
      setState(() => _products.insert(i.clamp(0, _products.length), p));
      _toast('Erreur : $e', ok: false);
    }
  }

  Future<void> _ajusterQuantite(Product p, int delta) async {
    final nQte = (p.quantity + delta).clamp(0, 9999);
    final old  = p.quantity;
    final i    = _products.indexWhere((x) => x.id == p.id);
    setState(() { if (i != -1) _products[i].quantity = nQte; });
    if (i != -1 && (_products[i].stockFaible || _products[i].stockVide))
      _alerteStock(_products[i]);
    try {
      await _sb.from('products').update({'quantity': nQte}).eq('id', p.id);
    } catch (e) {
      setState(() { if (i != -1) _products[i].quantity = old; });
      _toast('Erreur : $e', ok: false);
    }
  }

  // ── Upload images ──
  Future<String?> _uploadImage(File f, String pid) async {
    try {
      final ext = f.path.split('.').last.toLowerCase();
      final fn  = 'product_${pid}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final b   = await f.readAsBytes();
      await _sb.storage.from('product-images').uploadBinary(
        fn, b, fileOptions: FileOptions(contentType: 'image/$ext', upsert: true));
      return _sb.storage.from('product-images').getPublicUrl(fn);
    } catch (e) { _toast('Erreur upload : $e', ok: false); return null; }
  }

  Future<String?> _uploadImageBytes(Uint8List b, String pid, String ext) async {
    try {
      final ce = ext.toLowerCase().replaceAll('.', '');
      final fn = 'product_${pid}_${DateTime.now().millisecondsSinceEpoch}.$ce';
      await _sb.storage.from('product-images').uploadBinary(
        fn, b, fileOptions: FileOptions(contentType: 'image/$ce', upsert: true));
      return _sb.storage.from('product-images').getPublicUrl(fn);
    } catch (e) { _toast('Erreur upload : $e', ok: false); return null; }
  }

  Future<File?> _choisirImage() async {
    if (kIsWeb) return await _pickerDepuis(ImageSource.gallery);
    ImageSource? src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2))),
          Text('Ajouter une photo',
              style: _S.label(16, c: _S.emeraldMid, fw: FontWeight.w800)),
          const SizedBox(height: 16),
          _SourceTile(Icons.camera_alt, 'Prendre une photo', _S.emeraldFaint, _S.emeraldMid,
              () => Navigator.pop(context, ImageSource.camera)),
          const SizedBox(height: 10),
          _SourceTile(Icons.photo_library, 'Depuis la galerie',
              const Color(0xFFE3F2FD), Colors.blue,
              () => Navigator.pop(context, ImageSource.gallery)),
          const SizedBox(height: 8),
        ]),
      )),
    );
    if (src == null) return null;
    return await _pickerDepuis(src);
  }

  Future<File?> _pickerDepuis(ImageSource src) async {
    final picked = await ImagePicker().pickImage(
        source: src, maxWidth: 800, maxHeight: 800, imageQuality: 80);
    if (picked == null) return null;
    _imageBytesTemp = await picked.readAsBytes();
    final parts = picked.name.split('.');
    _imageTempExt = parts.length > 1 ? parts.last : 'jpg';
    if (kIsWeb) return null;
    return File(picked.path);
  }

  void _alerteStock(Product p) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(child: Text(p.stockVide
            ? '${p.name} : STOCK VIDE !'
            : '${p.name} : stock faible (${p.quantity} restants)')),
      ]),
      backgroundColor: p.stockVide ? _S.coral : _S.orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 4),
    ));
  }

  // ── Filtres ──
  List<Product> get _filtres => _products.where((p) {
    final matchCat  = _filtreCat == 'Tous' || p.category == _filtreCat;
    final q         = _recherche.trim().toLowerCase();
    final matchSrch = q.isEmpty
        || p.name.toLowerCase().contains(q)
        || (p.barcode ?? '').contains(q)
        || p.category.toLowerCase().contains(q);
    return matchCat && matchSrch;
  }).toList();

  List<Product> get _alertes => _products
      .where((p) => p.stockFaible || p.stockVide)
      .toList()..sort((a, b) => a.quantity.compareTo(b.quantity));

  // ✅ FIX sélection : confirmer et retourner les produits
  void _confirmerSelection() {
  if (_selection.isEmpty) {
    _toast('Sélectionnez au moins un produit', ok: false);
    return;
  }
  final result = <Map<String, dynamic>>[];
  for (final entry in _selection.entries) {
    final prod = _products.firstWhere((p) => p.id == entry.key,
        orElse: () => throw Exception('not found'));
    result.add({
      'id':        prod.id,
      'name':      prod.name,
      'price':     prod.price,
      'category':  prod.category,
      'quantity':  prod.quantity,
      'quantite':  entry.value,
      'image_url': prod.imageUrl, // ✅ ligne ajoutée
    });
  }
  Navigator.pop(context, result);
}

  // ══════════════════════════════════════
  //  BUILD PRINCIPAL
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final nbSelectionnes = _selection.values.fold(0, (s, q) => s + q);

    return Scaffold(
      backgroundColor: _S.fog,
      body: Column(children: [
        _buildHeader(),
        _buildSearchBar(),
        _buildFiltresCategorie(),
        if (_alertes.isNotEmpty && !widget.isSelectionMode)
          _buildBanniereAlertes(),
        // ✅ Bannière de sélection en mode sélection
        if (widget.isSelectionMode)
          _buildBanniereSelection(nbSelectionnes),
        _buildTabBar(),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(
                  color: _S.emeraldMid, strokeWidth: 2.5))
              : TabBarView(
                  controller: _tabCtrl,
                  children: [_buildListeProduits(), _buildOngletAlertes()],
                ),
        ),
      ]),
      // ✅ FAB conditionnel selon mode
      floatingActionButton: widget.isSelectionMode
          ? _buildFABSelection(nbSelectionnes)
          : FloatingActionButton.extended(
              onPressed: () => _ouvrirFormulaire(),
              backgroundColor: _S.emeraldMid,
              foregroundColor: Colors.white,
              elevation: 3,
              icon: const Icon(Icons.add),
              label: const Text('Ajouter',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }

  // ✅ FAB sélection
  Widget _buildFABSelection(int nbSelectionnes) {
    return FloatingActionButton.extended(
      onPressed: _confirmerSelection,
      backgroundColor: nbSelectionnes > 0 ? _S.orange : _S.slate,
      foregroundColor: Colors.white,
      elevation: 4,
      icon: const Icon(Icons.shopping_cart_checkout),
      label: Text(
        nbSelectionnes > 0
            ? 'Ajouter au panier ($nbSelectionnes)'
            : 'Ajouter au panier',
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }

  // ✅ Bannière de sélection
  Widget _buildBanniereSelection(int nbSelectionnes) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _S.emeraldFaint,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _S.emeraldMid.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        const Text('🛒', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Text(
          nbSelectionnes == 0
              ? 'Appuyez sur ➕ pour sélectionner des produits'
              : '$nbSelectionnes article(s) sélectionné(s)',
          style: _S.label(12, c: _S.emeraldMid, fw: FontWeight.w600),
        )),
        if (nbSelectionnes > 0)
          GestureDetector(
            onTap: () => setState(() => _selection.clear()),
            child: Text('Tout effacer',
                style: _S.label(11, c: _S.coral, fw: FontWeight.w700)),
          ),
      ]),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: _S.headerGrad,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            GestureDetector(
              onTap: () => widget.isSelectionMode
                  ? Navigator.pop(context, null)
                  : Navigator.pop(context),
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.isSelectionMode ? 'Choisir des produits' : 'Gestion du stock',
                style: const TextStyle(
                  color: Colors.white, fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: -0.3,
                )),
              Text('${_products.length} produit(s)',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
            ])),
            if (!widget.isSelectionMode) ...[
              IconButton(
                onPressed: _chargerProduits,
                icon: const Icon(Icons.refresh, color: Colors.white),
              ),
              if (_alertes.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _S.coral.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text('⚠️', style: TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Text('${_alertes.length}',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ]),
        ),
      ),
    );
  }

  // ── BARRE DE RECHERCHE ──
  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Row(children: [
        Expanded(
          child: Container(
            height: 44,
            decoration: BoxDecoration(
              color: _S.fog,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _S.mist, width: 1),
            ),
            child: TextField(
              controller:  _searchCtrl,
              focusNode:   _searchFocus,
              autofocus:   false,
              style:       _S.label(14, c: _S.ink),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit…',
                hintStyle: _S.label(14, c: _S.slate, fw: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                prefixIcon: Icon(Icons.search, color: _S.slate, size: 20),
                suffixIcon: _recherche.isNotEmpty
                    ? GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() => _recherche = '');
                        },
                        child: Icon(Icons.close, color: _S.slate, size: 18),
                      )
                    : GestureDetector(
                        onTap: _scannerBarcode,
                        child: Icon(Icons.qr_code_scanner,
                            color: _S.emeraldMid, size: 20),
                      ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ── TAB BAR ──
  Widget _buildTabBar() {
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabCtrl,
        indicatorColor: _S.emeraldMid,
        indicatorWeight: 3,
        labelColor: _S.emeraldMid,
        unselectedLabelColor: _S.slate,
        labelStyle: _S.label(12, fw: FontWeight.w700),
        tabs: [
          Tab(icon: const Icon(Icons.inventory_2, size: 18),
              text: 'Stock (${_filtres.length})'),
          Tab(
            icon: Badge(
              isLabelVisible: _alertes.isNotEmpty,
              label: Text('${_alertes.length}'),
              child: const Icon(Icons.warning_amber, size: 18),
            ),
            text: 'Alertes',
          ),
        ],
      ),
    );
  }

  // ── BANNIÈRE ALERTES ──
  Widget _buildBanniereAlertes() => GestureDetector(
    onTap: () => _tabCtrl.animateTo(1),
    child: Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _S.coralLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _S.coral.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        const Text('⚠️', style: TextStyle(fontSize: 16)),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${_alertes.length} produit(s) en stock faible',
              style: _S.label(12, c: _S.coral, fw: FontWeight.w700)),
          Text(_alertes.map((p) => p.name).take(3).join(', ')
              + (_alertes.length > 3 ? '…' : ''),
              style: _S.label(11, c: _S.coral.withValues(alpha: 0.7),
                  fw: FontWeight.w400)),
        ])),
        Text('Voir →', style: _S.label(12, c: _S.coral, fw: FontWeight.w700)),
      ]),
    ),
  );

  // ── FILTRES CATÉGORIE ──
  Widget _buildFiltresCategorie() => Container(
    color: Colors.white,
    height: 46,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      itemCount: categories.length,
      itemBuilder: (_, i) {
        final sel   = _filtreCat == categories[i];
        final count = categories[i] == 'Tous'
            ? _products.length
            : _products.where((p) => p.category == categories[i]).length;
        return GestureDetector(
          onTap: () => setState(() => _filtreCat = categories[i]),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: sel ? _S.emeraldMid : _S.fog,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: sel ? _S.emeraldMid : _S.mist, width: 1),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              imageCategorie(categories[i], size: 14),
              const SizedBox(width: 5),
              Text('${categories[i]} ($count)',
                  style: _S.label(11,
                      c: sel ? Colors.white : _S.slate,
                      fw: sel ? FontWeight.w700 : FontWeight.w500)),
            ]),
          ),
        );
      },
    ),
  );

  // ─────────────────────────────────────────
  // ONGLET 1 : LISTE PRODUITS
  // ─────────────────────────────────────────
  Widget _buildListeProduits() {
    if (_filtres.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🧺', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 12),
          Text(_recherche.isNotEmpty
              ? 'Aucun résultat pour "$_recherche"'
              : 'Aucun produit dans ce stock',
              style: _S.label(14, c: _S.slate)),
          const SizedBox(height: 16),
          if (_recherche.isEmpty && !widget.isSelectionMode)
            ElevatedButton.icon(
              onPressed: () => _ouvrirFormulaire(),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _S.emeraldMid, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter un produit'),
            ),
        ],
      ));
    }

    return RefreshIndicator(
      color: _S.emeraldMid,
      onRefresh: _chargerProduits,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 10, 12,
            widget.isSelectionMode ? 100 : 80),
        itemCount: _filtres.length,
        itemBuilder: (_, i) => widget.isSelectionMode
            ? _carteSelectionnable(_filtres[i])
            : _carteProduit(_filtres[i]),
      ),
    );
  }

  // ✅ Carte produit en mode sélection
  Widget _carteSelectionnable(Product p) {
    final int qteSelectionnee = _selection[p.id] ?? 0;
    final bool selectionne    = qteSelectionnee > 0;
    final bool stockVide      = p.quantity == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _S.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _S.cardShadow,
        border: Border.all(
          color: selectionne
              ? _S.emeraldMid.withValues(alpha: 0.5)
              : _S.mist,
          width: selectionne ? 2 : 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          // Image
          Stack(children: [
            _buildImageProduit(p),
            if (selectionne)
              Positioned(top: -4, right: -4,
                child: Container(
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                      color: _S.emeraldMid, shape: BoxShape.circle),
                  child: Center(child: Text('$qteSelectionnee',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.w900))),
                )),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: _S.label(14, fw: FontWeight.w800)),
              const SizedBox(height: 2),
              Row(children: [
                imageCategorie(p.category, size: 12),
                const SizedBox(width: 4),
                Text(p.category, style: _S.label(11, c: _S.slate)),
              ]),
              const SizedBox(height: 4),
              Text('${p.price.toStringAsFixed(0)} F · Stock : ${p.quantity}',
                  style: _S.label(12, c: stockVide ? _S.coral : _S.emeraldMid,
                      fw: FontWeight.w700)),
            ],
          )),
          // ✅ Contrôles sélection quantité
          stockVide
              ? Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                      color: _S.coralLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('Vide',
                      style: _S.label(11, c: _S.coral, fw: FontWeight.w700)),
                )
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (selectionne) ...[
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (qteSelectionnee <= 1) {
                            _selection.remove(p.id);
                          } else {
                            _selection[p.id] = qteSelectionnee - 1;
                          }
                        });
                      },
                      child: Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                            color: _S.coralLight,
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.remove,
                            color: _S.coral, size: 16),
                      ),
                    ),
                    SizedBox(
                      width: 32,
                      child: Text('$qteSelectionnee',
                          textAlign: TextAlign.center,
                          style: _S.label(15, fw: FontWeight.w900)),
                    ),
                  ],
                  GestureDetector(
                    onTap: qteSelectionnee < p.quantity
                        ? () => setState(() =>
                            _selection[p.id] = qteSelectionnee + 1)
                        : null,
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                          color: qteSelectionnee < p.quantity
                              ? _S.emeraldFaint : _S.mist,
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.add,
                          color: qteSelectionnee < p.quantity
                              ? _S.emeraldMid : _S.slate,
                          size: 16),
                    ),
                  ),
                ]),
        ]),
      ),
    );
  }

  Widget _carteProduit(Product p) {
    final Color couleur = p.stockVide ? _S.coral
        : p.stockFaible ? _S.orange : _S.emeraldMid;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _S.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: _S.cardShadow,
        border: Border.all(
          color: p.stockVide   ? _S.coral.withValues(alpha: 0.25)
              : p.stockFaible ? _S.orange.withValues(alpha: 0.2)
              : _S.mist,
          width: 0.8,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          _buildImageProduit(p),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(child: Text(p.name,
                    style: _S.label(14, fw: FontWeight.w800))),
                _StockBadge(p: p, couleur: couleur),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                imageCategorie(p.category, size: 12),
                const SizedBox(width: 4),
                Text(p.category, style: _S.label(11, c: _S.slate)),
                if (p.barcode != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.qr_code, size: 11, color: _S.slate),
                  const SizedBox(width: 2),
                  Text(p.barcode!, style: _S.label(10, c: _S.slate)),
                ],
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: _S.emeraldFaint,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${_fmtPrix(p.price)} F',
                      style: _S.label(13, c: _S.emeraldMid, fw: FontWeight.w800)),
                ),
                const Spacer(),
                _QteControls(p: p, couleur: couleur,
                    onAjuster: (d) => _ajusterQuantite(p, d)),
              ]),
              const SizedBox(height: 4),
              Text('Min stock : ${p.minStock} unités',
                  style: _S.label(10, c: _S.slate)),
            ],
          )),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: _S.slate, size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) {
              if (v == 'edit')    _ouvrirFormulaire(existant: p);
              if (v == 'delete')  _confirmerSuppression(p);
              if (v == 'ajuster') _dialogAjusterQuantite(p);
            },
            itemBuilder: (_) => [
              _menuItem('edit',    Icons.edit,           Colors.orange, 'Modifier'),
              _menuItem('ajuster', Icons.tune,           Colors.blue,   'Ajuster stock'),
              _menuItem('delete',  Icons.delete_outline, _S.coral,      'Supprimer'),
            ],
          ),
        ]),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
      String val, IconData icon, Color c, String label) =>
      PopupMenuItem(
        value: val,
        child: Row(children: [
          Icon(icon, color: c, size: 18),
          const SizedBox(width: 10),
          Text(label, style: _S.label(13)),
        ]),
      );

  Widget _buildImageProduit(Product p) {
    final ph = Container(
      width: 64, height: 64,
      decoration: BoxDecoration(
          color: _S.emeraldFaint,
          borderRadius: BorderRadius.circular(12)),
      child: Center(child: imageCategorie(p.category, size: 30)),
    );
    if (p.imageUrl == null || p.imageUrl!.isEmpty) return ph;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: p.imageUrl!, width: 64, height: 64, fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
              color: _S.mist, borderRadius: BorderRadius.circular(12)),
          child: Center(child: SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: _S.emeraldMid))),
        ),
        errorWidget: (_, __, ___) => ph,
      ),
    );
  }

  // ─────────────────────────────────────────
  // ONGLET 2 : ALERTES
  // ─────────────────────────────────────────
  Widget _buildOngletAlertes() {
    if (_alertes.isEmpty) {
      return Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('✅', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 12),
          Text('Tous les stocks sont OK !', style: _S.label(15, c: _S.slate)),
        ],
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: _S.white, borderRadius: BorderRadius.circular(14),
              boxShadow: _S.cardShadow),
          child: Row(children: [
            const Text('⚠️', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${_alertes.length} produit(s) à réapprovisionner',
                  style: _S.label(13, c: _S.coral, fw: FontWeight.w700)),
              Text(
                '${_alertes.where((p) => p.stockVide).length} vide(s) · '
                '${_alertes.where((p) => p.stockFaible && !p.stockVide).length} faible(s)',
                style: _S.label(12, c: _S.slate),
              ),
            ]),
          ]),
        ),
        ..._alertes.map((p) => _carteAlerte(p)),
      ],
    );
  }

  Widget _carteAlerte(Product p) {
    final c = p.stockVide ? _S.coral : _S.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _S.white, borderRadius: BorderRadius.circular(14),
        boxShadow: _S.cardShadow,
        border: Border.all(color: c.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Stack(children: [
            _buildImageProduit(p),
            Positioned(top: 0, right: 0,
              child: Text(p.stockVide ? '🔴' : '🟡',
                  style: const TextStyle(fontSize: 14))),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.name, style: _S.label(14, fw: FontWeight.w800)),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: p.minStock > 0
                      ? (p.quantity / (p.minStock * 2)).clamp(0.0, 1.0) : 0,
                  backgroundColor: _S.mist,
                  valueColor: AlwaysStoppedAnimation<Color>(c),
                  minHeight: 5,
                ),
              ),
              const SizedBox(height: 6),
              Row(children: [
                Text('Stock : ', style: _S.label(12, c: _S.slate)),
                Text('${p.quantity}',
                    style: _S.label(12, c: c, fw: FontWeight.w700)),
                Text(' / min ${p.minStock}', style: _S.label(11, c: _S.slate)),
              ]),
            ],
          )),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _dialogAjusterQuantite(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                  color: _S.emeraldMid, borderRadius: BorderRadius.circular(12)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.add_box, color: Colors.white, size: 20),
                const SizedBox(height: 2),
                Text('Réappro',
                    style: _S.label(9, c: Colors.white, fw: FontWeight.w700)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────
  // FORMULAIRE AJOUT / MODIF
  // ─────────────────────────────────────────
  void _ouvrirFormulaire({Product? existant}) {
    _imageBytesTemp = null;
    _imageTempExt   = null;

    final nomCtrl     = TextEditingController(text: existant?.name);
    final prixCtrl    = TextEditingController(
        text: existant != null ? existant.price.toStringAsFixed(0) : '');
    final qteCtrl     = TextEditingController(
        text: existant != null ? '${existant.quantity}' : '0');
    final minCtrl     = TextEditingController(
        text: existant != null ? '${existant.minStock}' : '5');
    final barcodeCtrl = TextEditingController(text: existant?.barcode);
    String  catSelect   = existant?.category ?? 'Alimentaire';
    String? imageUrl    = existant?.imageUrl;
    File?   imageFich;
    bool    loadingImg  = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setM) => Padding(
        padding: EdgeInsets.only(
          left: 20, right: 20, top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 16),
            Row(children: [
              const Text('📦', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(existant == null ? 'Nouveau produit' : 'Modifier produit',
                  style: _S.label(17, c: _S.emeraldMid, fw: FontWeight.w800)),
            ]),
            const SizedBox(height: 20),

            // Image
            Center(child: GestureDetector(
              onTap: () async {
                _imageBytesTemp = null; _imageTempExt = null;
                final f = await _choisirImage();
                setM(() { if (f != null) imageFich = f; });
              },
              child: Container(
                width: 110, height: 110,
                decoration: BoxDecoration(
                  color: _S.emeraldFaint, borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _S.emeraldMid.withValues(alpha: 0.3), width: 2),
                ),
                child: _imageBytesTemp != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14),
                        child: Image.memory(_imageBytesTemp!, fit: BoxFit.cover))
                    : imageFich != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(14),
                            child: Image.file(imageFich!, fit: BoxFit.cover))
                        : imageUrl != null && imageUrl!.isNotEmpty
                            ? ClipRRect(borderRadius: BorderRadius.circular(14),
                                child: CachedNetworkImage(
                                    imageUrl: imageUrl!, fit: BoxFit.cover))
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  imageCategorie(catSelect),
                                  const SizedBox(height: 6),
                                  Text('Ajouter photo',
                                      style: _S.label(11, c: _S.emeraldMid)),
                                ]),
              ),
            )),
            const SizedBox(height: 16),

            // Catégorie
            Text('🏷️  Catégorie', style: _S.label(13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8,
              children: ['Alimentaire','Boissons','Hygiène','Autre'].map((cat) {
                final sel = catSelect == cat;
                return GestureDetector(
                  onTap: () => setM(() => catSelect = cat),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? _S.emeraldMid : _S.fog,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      imageCategorie(cat, size: 14),
                      const SizedBox(width: 6),
                      Text(cat, style: _S.label(12,
                          c: sel ? Colors.white : _S.ink,
                          fw: sel ? FontWeight.w700 : FontWeight.w500)),
                    ]),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            _champ(nomCtrl, 'Nom du produit *', Icons.label),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _champ(prixCtrl, 'Prix (F)', Icons.payments, nb: true)),
              const SizedBox(width: 10),
              Expanded(child: _champ(qteCtrl, 'Quantité', Icons.inventory, nb: true)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _champ(minCtrl, 'Stock min', Icons.warning_amber, nb: true)),
              const SizedBox(width: 10),
              Expanded(child: _champBarcode(barcodeCtrl, ctx)),
            ]),
            const SizedBox(height: 20),

            SizedBox(width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _S.emeraldMid, foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                icon: loadingImg
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.save),
                label: Text(
                  loadingImg ? 'Upload…'
                      : existant == null ? 'Enregistrer' : 'Sauvegarder',
                  style: _S.label(15, c: Colors.white, fw: FontWeight.w700),
                ),
                onPressed: loadingImg ? null : () async {
                  if (nomCtrl.text.isEmpty || prixCtrl.text.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                        content: Text('Nom et prix obligatoires'),
                        backgroundColor: Colors.red));
                    return;
                  }
                  setM(() => loadingImg = true);
                  final id = existant?.id
                      ?? DateTime.now().millisecondsSinceEpoch.toString();
                  String? finalUrl = imageUrl;
                  if (kIsWeb && _imageBytesTemp != null)
                    finalUrl = await _uploadImageBytes(
                        _imageBytesTemp!, id, _imageTempExt ?? 'jpg');
                  else if (!kIsWeb && imageFich != null)
                    finalUrl = await _uploadImage(imageFich!, id);
                  final p = Product(
                    id: id, name: nomCtrl.text.trim(), category: catSelect,
                    quantity: int.tryParse(qteCtrl.text) ?? 0,
                    price: double.tryParse(prixCtrl.text) ?? 0,
                    minStock: int.tryParse(minCtrl.text) ?? 5,
                    barcode: barcodeCtrl.text.isEmpty ? null : barcodeCtrl.text,
                    imageUrl: finalUrl,
                    addedDate: existant?.addedDate ?? DateTime.now(),
                  );
                  Navigator.pop(ctx);
                  if (existant == null) await _ajouterProduit(p);
                  else                  await _modifierProduit(p);
                },
              ),
            ),
          ],
        )),
      )),
    );
  }

  // ── Dialog ajuster quantité ──
  void _dialogAjusterQuantite(Product p) {
    final ctrl = TextEditingController(text: '${p.quantity}');
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        _buildImageProduit(p), const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(p.name, style: _S.label(14, fw: FontWeight.w800)),
          Text('Stock : ${p.quantity}', style: _S.label(12, c: _S.slate)),
        ])),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Nouvelle quantité :', style: _S.label(14)),
        const SizedBox(height: 12),
        Row(children: [
          GestureDetector(
            onTap: () { final q = int.tryParse(ctrl.text) ?? 0; if (q > 0) ctrl.text = '${q-1}'; },
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: _S.coralLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.remove, color: _S.coral)),
          ),
          const SizedBox(width: 10),
          Expanded(child: TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            textAlign: TextAlign.center,
            style: _S.label(22, fw: FontWeight.w800),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: _S.emeraldMid, width: 2)),
            ),
          )),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () { final q = int.tryParse(ctrl.text) ?? 0; ctrl.text = '${q+1}'; },
            child: Container(width: 40, height: 40,
              decoration: BoxDecoration(color: _S.emeraldFaint,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.add, color: _S.emeraldMid)),
          ),
        ]),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: _S.label(13, c: _S.slate))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _S.emeraldMid, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            final nQte = int.tryParse(ctrl.text) ?? p.quantity;
            Navigator.pop(context);
            await _sb.from('products').update({'quantity': nQte}).eq('id', p.id);
            _toast('✅ Stock mis à jour : $nQte', ok: true);
          },
          child: const Text('Mettre à jour'),
        ),
      ],
    ));
  }

  // ── Scanner ──
  void _scannerBarcode({TextEditingController? barcodeCtrl}) {
    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.65,
        child: Stack(children: [
          MobileScanner(onDetect: (capture) {
            final code = capture.barcodes.first.rawValue;
            if (code == null) return;
            Navigator.pop(context);
            if (barcodeCtrl != null) {
              barcodeCtrl.text = code;
            } else {
              setState(() {
                _recherche = code;
                _searchCtrl.text = code;
              });
              final found = _products.where((p) => p.barcode == code).toList();
              if (found.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Produit non trouvé : $code'),
                  backgroundColor: _S.orange,
                  action: SnackBarAction(label: 'Ajouter',
                      textColor: Colors.white,
                      onPressed: () => _ouvrirFormulaire()),
                ));
              }
            }
          }),
          Center(child: Container(width: 260, height: 160,
            decoration: BoxDecoration(
                border: Border.all(color: _S.emeraldGlow, width: 3),
                borderRadius: BorderRadius.circular(12)),
          )),
          Positioned(bottom: 20, left: 0, right: 0,
            child: Center(child: Text('Pointez vers le code-barres',
                style: _S.label(14,
                    c: Colors.white.withValues(alpha: 0.8))))),
        ]),
      ),
    );
  }

  // ── Confirmation suppression ──
  void _confirmerSuppression(Product p) {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(children: [
        const Text('🗑️', style: TextStyle(fontSize: 22)),
        const SizedBox(width: 8),
        Text('Supprimer', style: _S.label(16, c: _S.coral)),
      ]),
      content: Text('Supprimer "${p.name}" ?\nCette action est irréversible.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: _S.label(13, c: _S.slate))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _S.coral, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () async {
            Navigator.pop(context);
            await _supprimerProduit(p);
          },
          child: const Text('Supprimer'),
        ),
      ],
    ));
  }

  // ── Helpers ──
  Widget imageCategorie(String cat, {double size = 40}) {
    const map = {
      'Alimentaire': 'lib/assets/categories/aliment.jpg',
      'Boissons':    'lib/assets/categories/boisson.jpg',
      'Hygiène':     'lib/assets/categories/hygienne.jpg',
    };
    final path = map[cat] ?? 'lib/assets/categories/produit.png';
    return ClipRRect(
      borderRadius: BorderRadius.circular(size / 3),
      child: Image.asset(path, width: size, height: size, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Text(
            cat == 'Alimentaire' ? '🍞' : cat == 'Boissons' ? '🥤'
                : cat == 'Hygiène' ? '🧴' : '📦',
            style: TextStyle(fontSize: size * 0.6),
          )),
    );
  }

  Widget _champ(TextEditingController c, String label, IconData icon,
      {bool nb = false}) =>
      TextFormField(
        controller: c,
        keyboardType: nb ? TextInputType.number : TextInputType.text,
        inputFormatters: nb ? [FilteringTextInputFormatter.digitsOnly] : null,
        style: _S.label(14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: _S.emeraldMid, size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _S.emeraldMid, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  Widget _champBarcode(TextEditingController c, BuildContext ctx) =>
      TextFormField(
        controller: c,
        style: _S.label(14),
        decoration: InputDecoration(
          labelText: 'Code-barres',
          prefixIcon: Icon(Icons.qr_code, color: _S.emeraldMid, size: 20),
          suffixIcon: IconButton(
            icon: Icon(Icons.qr_code_scanner, color: _S.emeraldMid),
            onPressed: () {
              Navigator.pop(ctx);
              _scannerBarcode(barcodeCtrl: c);
            },
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: _S.emeraldMid, width: 2)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        ),
      );

  void _toast(String msg, {required bool ok}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: ok ? _S.emeraldMid : _S.coral,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _fmtPrix(double p) {
    if (p >= 1000000) return '${(p / 1000000).toStringAsFixed(1)}M';
    if (p >= 1000)    return '${(p / 1000).toStringAsFixed(0)}k';
    return p.toStringAsFixed(0);
  }
}

// ─────────────────────────────────────────
// WIDGETS UTILITAIRES
// ─────────────────────────────────────────
class _StockBadge extends StatelessWidget {
  final Product p;
  final Color   couleur;
  const _StockBadge({required this.p, required this.couleur});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: couleur.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(
        p.stockVide ? Icons.remove_circle
            : p.stockFaible ? Icons.warning : Icons.check_circle,
        size: 10, color: couleur,
      ),
      const SizedBox(width: 3),
      Text(
        p.stockVide ? 'VIDE' : p.stockFaible ? 'Faible' : 'OK',
        style: TextStyle(
            fontSize: 10, color: couleur, fontWeight: FontWeight.w700),
      ),
    ]),
  );
}

class _QteControls extends StatelessWidget {
  final Product  p;
  final Color    couleur;
  final void Function(int) onAjuster;
  const _QteControls(
      {required this.p, required this.couleur, required this.onAjuster});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
        color: _S.fog, borderRadius: BorderRadius.circular(10)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      GestureDetector(
        onTap: () => onAjuster(-1), onLongPress: () => onAjuster(-10),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: p.quantity > 0 ? _S.coralLight : _S.fog,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.remove, size: 15,
              color: p.quantity > 0 ? _S.coral : _S.slate)),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text('${p.quantity}',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: couleur)),
      ),
      GestureDetector(
        onTap: () => onAjuster(1), onLongPress: () => onAjuster(10),
        child: Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: _S.emeraldFaint, borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.add, size: 15, color: _S.emeraldMid)),
      ),
    ]),
  );
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Color    bg, iconColor;
  final VoidCallback onTap;
  const _SourceTile(this.icon, this.title, this.bg, this.iconColor, this.onTap);
  @override
  Widget build(BuildContext context) => ListTile(
    onTap: onTap,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200)),
    leading: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: iconColor, size: 22),
    ),
    title: Text(title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
  );
}
