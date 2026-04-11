import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestion Stock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F6E56)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const StockPage(),
    );
  }
}

// ─────────────────────────────────────────
// MODÈLE PRODUIT
// ─────────────────────────────────────────
class Product {
  final String id;
  String name;
  String category;
  int quantity;
  double price;
  int minStock;
  DateTime addedDate;
  String? barcode;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.quantity,
    required this.price,
    required this.minStock,
    required this.addedDate,
    this.barcode,
  });

  bool get isLowStock => quantity <= minStock;
}

// ─────────────────────────────────────────
// PAGE SCANNER
// ─────────────────────────────────────────
class ScannerPage extends StatefulWidget {
  final Function(String) onScanned;
  const ScannerPage({super.key, required this.onScanned});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController();
  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_hasScanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue != null) {
      _hasScanned = true;
      HapticFeedback.mediumImpact();
      widget.onScanned(barcode!.rawValue!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F6E56);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: green,
        foregroundColor: Colors.white,
        title: const Text('Scanner un produit',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              setState(() => _torchOn = !_torchOn);
              _controller.toggleTorch();
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: _controller.switchCamera,
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Column(
            children: [
              Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
              Row(
                children: [
                  Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
                  Container(
                    width: 260, height: 260,
                    decoration: BoxDecoration(
                      border: Border.all(color: green, width: 3),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
                ],
              ),
              Expanded(child: Container(color: Colors.black.withOpacity(0.5))),
            ],
          ),
          const Center(child: _ScanLine()),
          Positioned(
            bottom: 60, left: 0, right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Placez le code-barres dans le cadre',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                  label: const Text('Annuler',
                      style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _position;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _position = Tween<double>(begin: -120, end: 120)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _position,
      builder: (_, __) => Transform.translate(
        offset: Offset(0, _position.value),
        child: Container(width: 260, height: 2, color: const Color(0xFF0F6E56)),
      ),
    );
  }
}

// ─────────────────────────────────────────
// PAGE PRINCIPALE STOCK
// ─────────────────────────────────────────
class StockPage extends StatefulWidget {
  const StockPage({super.key});

  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  static const Color green = Color(0xFF0F6E56);
  static const Color greenLight = Color(0xFFE8F5E9);

  String _searchQuery = '';
  String _selectedCategory = 'Tous';
  int _currentIndex = 0;

  final List<String> categories = [
    'Tous', 'Alimentaire', 'Boissons', 'Hygiène', 'Autre'
  ];

  List<Product> products = [
    Product(id: '001', name: 'Riz Basmati 5kg',    category: 'Alimentaire', quantity: 3,  price: 4500, minStock: 5,  addedDate: DateTime.now().subtract(const Duration(days: 10)), barcode: '1234567890'),
    Product(id: '002', name: 'Huile Végétale 1L',  category: 'Alimentaire', quantity: 12, price: 1200, minStock: 8,  addedDate: DateTime.now().subtract(const Duration(days: 5))),
    Product(id: '003', name: 'Eau Minérale 1.5L',  category: 'Boissons',    quantity: 2,  price: 500,  minStock: 10, addedDate: DateTime.now().subtract(const Duration(days: 2))),
    Product(id: '004', name: 'Savon Liquide',       category: 'Hygiène',     quantity: 7,  price: 800,  minStock: 5,  addedDate: DateTime.now().subtract(const Duration(days: 15))),
    Product(id: '005', name: 'Jus de Mangue 33cl',  category: 'Boissons',    quantity: 1,  price: 350,  minStock: 6,  addedDate: DateTime.now().subtract(const Duration(days: 1))),
  ];

  List<Product> get filteredProducts => products.where((p) {
        final matchSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (p.barcode?.contains(_searchQuery) ?? false);
        final matchCat = _selectedCategory == 'Tous' || p.category == _selectedCategory;
        return matchSearch && matchCat;
      }).toList();

  List<Product> get lowStockProducts => products.where((p) => p.isLowStock).toList();
  double get totalValue => products.fold(0, (s, p) => s + (p.price * p.quantity));
  int get lowStockCount => lowStockProducts.length;
  Map<String, int> get categoryCount {
    final map = <String, int>{};
    for (var p in products) map[p.category] = (map[p.category] ?? 0) + 1;
    return map;
  }

  // ── SCANNER ──
  void _openScanner({TextEditingController? prefill}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScannerPage(
          onScanned: (code) {
            if (prefill != null) {
              prefill.text = code;
            } else {
              setState(() {
                _searchQuery = code;
                _currentIndex = 0;
              });
              final found = products.where((p) => p.barcode == code).toList();
              if (found.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: Colors.orange,
                  content: Text('Produit non trouvé : $code'),
                  action: SnackBarAction(
                    label: 'Ajouter',
                    textColor: Colors.white,
                    onPressed: () => _showAddProductDialog(barcode: code),
                  ),
                ));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: green,
                  content: Text('✓ Trouvé : ${found.first.name}'),
                ));
              }
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: _buildAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [_buildStockList(), _buildStats(), _buildAlerts()],
      ),
      bottomNavigationBar: _buildBottomNav(),
      floatingActionButton: _currentIndex == 0 ? _buildFAB() : null,
    );
  }

  // ── APP BAR ──
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: green,
      foregroundColor: Colors.white,
      elevation: 0,
      title: _currentIndex == 0
          ? TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Rechercher un produit...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                border: InputBorder.none,
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
            )
          : const Text('Gestion de Stock',
              style: TextStyle(fontWeight: FontWeight.bold)),
      actions: [
        if (_currentIndex == 0)
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _openScanner(),
          ),
        Stack(
          children: [
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () => setState(() => _currentIndex = 2),
            ),
            if (lowStockCount > 0)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                      color: Colors.red, shape: BoxShape.circle),
                  child: Text('$lowStockCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10)),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── BOTTOM NAV ──
  Widget _buildBottomNav() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (i) => setState(() => _currentIndex = i),
      selectedItemColor: green,
      unselectedItemColor: Colors.grey,
      items: [
        BottomNavigationBarItem(
          icon: _navImage('lib/assets/categories/aliment.jpg', Icons.inventory_2),
          label: 'Stock',
        ),
        BottomNavigationBarItem(
          icon: _navImage('lib/assets/categories/stats.jpg', Icons.bar_chart),
          label: 'Statistiques',
        ),
        BottomNavigationBarItem(
          icon: Badge(
            isLabelVisible: lowStockCount > 0,
            label: Text('$lowStockCount'),
            child: _navImage('lib/assets/categories/alerte.webp', Icons.warning_amber),
          ),
          label: 'Alertes',
        ),
      ],
    );
  }

  Widget _navImage(String path, IconData fallback) {
    return Image.asset(path, width: 24, height: 24,
        errorBuilder: (_, __, ___) => Icon(fallback, size: 24));
  }

  // ── FAB ──
  Widget _buildFAB() {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      FloatingActionButton(
        heroTag: 'scan_fab',
        mini: true,
        backgroundColor: Colors.white,
        foregroundColor: green,
        onPressed: () => _openScanner(),
        child: const Icon(Icons.qr_code_scanner),
      ),
      const SizedBox(height: 8),
      FloatingActionButton.extended(
        heroTag: 'add_fab',
        onPressed: () => _showAddProductDialog(),
        backgroundColor: green,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    ]);
  }

  // ─────────────────────────────────────────
  // ONGLET 1 : LISTE
  // ─────────────────────────────────────────
  Widget _buildStockList() {
    return Column(children: [

      // ── BARRE CATÉGORIES CORRIGÉE (ROW au lieu de COLUMN) ──
      Container(
        color: green,
        height: 56,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          itemCount: categories.length,
          itemBuilder: (context, i) {
            final selected = _selectedCategory == categories[i];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = categories[i]),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected ? Colors.white : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                // ✅ ROW : image à gauche + texte à droite = pas d'overflow
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (categories[i] == 'Tous')
                      Icon(Icons.grid_view,
                          size: 18,
                          color: selected ? green : Colors.white)
                    else
                      SizedBox(
                        width: 22, height: 22,
                        child: _categoryImageWidget(categories[i], 22, selected),
                      ),
                    const SizedBox(width: 6),
                    Text(
                      categories[i],
                      style: TextStyle(
                        fontSize: 11,
                        color: selected ? green : Colors.white,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),

      // Résumé
      Container(
        color: greenLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(children: [
          const Icon(Icons.inventory, size: 16, color: green),
          const SizedBox(width: 6),
          Text('${filteredProducts.length} produit(s)',
              style: const TextStyle(
                  color: green, fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          if (_searchQuery.isNotEmpty)
            GestureDetector(
              onTap: () => setState(() => _searchQuery = ''),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8)),
                child: Row(children: [
                  Text('"$_searchQuery"',
                      style: const TextStyle(color: green, fontSize: 12)),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 12, color: green),
                ]),
              ),
            ),
        ]),
      ),

      Expanded(
        child: filteredProducts.isEmpty
            ? Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('Aucun produit trouvé',
                      style:
                          TextStyle(color: Colors.grey[600], fontSize: 16)),
                ]))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: filteredProducts.length,
                itemBuilder: (_, i) =>
                    _buildProductCard(filteredProducts[i]),
              ),
      ),
    ]);
  }

  // ── CARTE PRODUIT ──
  Widget _buildProductCard(Product p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: p.isLowStock
              ? Colors.red.withOpacity(0.4)
              : Colors.grey.withOpacity(0.15),
          width: p.isLowStock ? 1.5 : 0.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 52, height: 52,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: p.isLowStock ? Colors.red[50] : greenLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: p.isLowStock
              ? Image.asset('lib/assets/categories/stock_bas.jpg',
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.warning_amber, color: Colors.red, size: 28))
              : _categoryImageWidget(p.category, 28, false),
        ),
        title: Row(children: [
          Expanded(
              child: Text(p.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15))),
          if (p.isLowStock)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8)),
              child: const Text('Stock bas',
                  style: TextStyle(
                      color: Colors.red,
                      fontSize: 11,
                      fontWeight: FontWeight.bold)),
            ),
        ]),
        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 4),
          Row(children: [
            _categoryImageWidget(p.category, 14, false),
            const SizedBox(width: 4),
            Text(p.category, style: const TextStyle(color: green, fontSize: 12)),
            const SizedBox(width: 12),
            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
            const SizedBox(width: 4),
            Text(_formatDate(p.addedDate),
                style: TextStyle(color: Colors.grey[500], fontSize: 12)),
            if (p.barcode != null) ...[
              const SizedBox(width: 12),
              const Icon(Icons.qr_code, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(p.barcode!,
                    style: const TextStyle(color: Colors.grey, fontSize: 11),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Row(children: [
            Text('Qté : ', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            Text('${p.quantity}',
                style: TextStyle(
                  color: p.isLowStock ? Colors.red : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                )),
            Text(' / min ${p.minStock}',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
            const Spacer(),
            Text('${_formatPrice(p.price)} FCFA',
                style: const TextStyle(
                    color: green, fontWeight: FontWeight.bold, fontSize: 14)),
          ]),
        ]),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onSelected: (value) {
            if (value == 'edit') _showEditDialog(p);
            if (value == 'delete') _confirmDelete(p);
            if (value == 'add_stock') _showAddStockDialog(p);
          },
          itemBuilder: (_) => [
            PopupMenuItem(
                value: 'add_stock',
                child: Row(children: [
                  _categoryImageWidget(p.category, 18, false),
                  const SizedBox(width: 8),
                  const Text('Ajouter stock'),
                ])),
            const PopupMenuItem(
                value: 'edit',
                child: Row(children: [
                  Icon(Icons.edit, color: Colors.blue, size: 18),
                  SizedBox(width: 8),
                  Text('Modifier'),
                ])),
            const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete, color: Colors.red, size: 18),
                  SizedBox(width: 8),
                  Text('Supprimer'),
                ])),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  // ONGLET 2 : STATISTIQUES
  // ─────────────────────────────────────────
  Widget _buildStats() {
    final topProducts = [...products]
      ..sort((a, b) => (b.price * b.quantity).compareTo(a.price * a.quantity));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: [
            _statCard('Produits', '${products.length}', Icons.inventory_2, green),
            _statCard('Valeur totale', '${_formatPrice(totalValue)} F',
                Icons.account_balance_wallet, Colors.blue),
            _statCard('Stock bas', '$lowStockCount', Icons.warning_amber, Colors.orange),
            _statCard('Catégories', '${categoryCount.length}', Icons.category, Colors.purple),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Répartition par catégorie',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 12),
        ...categoryCount.entries.map((e) => _categoryBar(e.key, e.value, products.length)),
        const SizedBox(height: 24),
        const Text('Top produits (valeur stock)',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 12),
        ...topProducts.take(5).map((p) => _topProductRow(p)),
        const SizedBox(height: 24),
        const Text('Ajouts récents',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: green)),
        const SizedBox(height: 12),
        ...([...products]..sort((a, b) => b.addedDate.compareTo(a.addedDate)))
            .take(3)
            .map((p) => _recentProductRow(p)),
      ]),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(
            color: color.withOpacity(0.1), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 22),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(value,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold, color: color)),
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ]),
          ]),
    );
  }

  Widget _categoryBar(String category, int count, int total) {
    final percent = total > 0 ? count / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(children: [
        Row(children: [
          _categoryImageWidget(category, 16, false),
          const SizedBox(width: 8),
          Text(category, style: const TextStyle(fontSize: 13)),
          const Spacer(),
          Text('$count produit(s)',
              style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(green),
            minHeight: 6,
          ),
        ),
      ]),
    );
  }

  Widget _topProductRow(Product p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _categoryImageWidget(p.category, 20, false),
          const SizedBox(width: 10),
          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
          Text('${_formatPrice(p.price * p.quantity)} F',
              style: const TextStyle(
                  color: green, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
      );

  Widget _recentProductRow(Product p) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [
          _categoryImageWidget(p.category, 20, false),
          const SizedBox(width: 10),
          Expanded(child: Text(p.name, style: const TextStyle(fontSize: 13))),
          Text(_formatDate(p.addedDate),
              style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ]),
      );

  // ─────────────────────────────────────────
  // ONGLET 3 : ALERTES
  // ─────────────────────────────────────────
  Widget _buildAlerts() {
    if (lowStockProducts.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_outline, size: 72, color: green),
          const SizedBox(height: 16),
          const Text('Aucune alerte !',
              style: TextStyle(
                  fontSize: 18, color: green, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Tous vos stocks sont suffisants.',
              style: TextStyle(color: Colors.grey[600])),
        ]),
      );
    }
    return Column(children: [
      Container(
        width: double.infinity,
        color: Colors.red[50],
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          const Icon(Icons.warning_amber, color: Colors.red, size: 20),
          const SizedBox(width: 8),
          Text('${lowStockProducts.length} produit(s) en stock insuffisant',
              style: const TextStyle(
                  color: Colors.red, fontWeight: FontWeight.bold)),
        ]),
      ),
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: lowStockProducts.length,
          itemBuilder: (_, i) {
            final p = lowStockProducts[i];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.red, width: 1),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 52, height: 52,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12)),
                    child: _categoryImageWidget(p.category, 32, false),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name,
                              style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('${p.category} • ${_formatDate(p.addedDate)}',
                              style: TextStyle(
                                  color: Colors.grey[600], fontSize: 12)),
                          const SizedBox(height: 6),
                          Row(children: [
                            _alertBadge('Actuel : ${p.quantity}', Colors.red),
                            const SizedBox(width: 8),
                            _alertBadge('Min : ${p.minStock}', Colors.orange),
                          ]),
                        ]),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: green, size: 28),
                    onPressed: () => _showAddStockDialog(p),
                  ),
                ]),
              ),
            );
          },
        ),
      ),
    ]);
  }

  Widget _alertBadge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      );

  // ─────────────────────────────────────────
  // DIALOGUES
  // ─────────────────────────────────────────
  void _showAddProductDialog({String? barcode}) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    final minCtrl = TextEditingController(text: '5');
    final barcodeCtrl = TextEditingController(text: barcode ?? '');
    String selectedCat = 'Alimentaire';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  Row(children: [
                    const Icon(Icons.add_box, color: green),
                    const SizedBox(width: 10),
                    const Text('Nouveau produit',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: green)),
                  ]),
                  const SizedBox(height: 16),
                  _inputField(nameCtrl, 'Nom du produit *', Icons.label),
                  const SizedBox(height: 12),

                  // Sélecteur catégorie avec images
                  const Text('Catégorie',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories.where((c) => c != 'Tous').map((cat) {
                      final sel = selectedCat == cat;
                      return GestureDetector(
                        onTap: () => setModal(() => selectedCat = cat),
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: sel ? green.withOpacity(0.12) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sel ? green : Colors.transparent, width: 2),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _categoryImageWidget(cat, 32, sel),
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

                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _inputField(
                        qtyCtrl, 'Quantité *', Icons.numbers, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _inputField(
                        minCtrl, 'Stock min', Icons.low_priority, isNumber: true)),
                  ]),
                  const SizedBox(height: 10),
                  _inputField(priceCtrl, 'Prix (FCFA) *', Icons.attach_money,
                      isNumber: true),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _inputField(
                        barcodeCtrl, 'Code-barres (optionnel)', Icons.qr_code)),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: greenLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: green.withOpacity(0.3)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: green),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openScanner(prefill: barcodeCtrl);
                        },
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Enregistrer',
                          style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        if (nameCtrl.text.isEmpty ||
                            qtyCtrl.text.isEmpty ||
                            priceCtrl.text.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                              content: Text('Remplissez les champs (*)'),
                              backgroundColor: Colors.red));
                          return;
                        }
                        setState(() {
                          products.add(Product(
                            id: DateTime.now().millisecondsSinceEpoch.toString(),
                            name: nameCtrl.text,
                            category: selectedCat,
                            quantity: int.tryParse(qtyCtrl.text) ?? 0,
                            price: double.tryParse(priceCtrl.text) ?? 0,
                            minStock: int.tryParse(minCtrl.text) ?? 5,
                            addedDate: DateTime.now(),
                            barcode: barcodeCtrl.text.isNotEmpty
                                ? barcodeCtrl.text
                                : null,
                          ));
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: green,
                            content: Text('${nameCtrl.text} ajouté !')));
                      },
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Product p) {
    final nameCtrl = TextEditingController(text: p.name);
    final qtyCtrl = TextEditingController(text: p.quantity.toString());
    final priceCtrl = TextEditingController(text: p.price.toStringAsFixed(0));
    final minCtrl = TextEditingController(text: p.minStock.toString());
    String selectedCat = p.category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
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
                  Row(children: [
                    const Icon(Icons.edit, color: green),
                    const SizedBox(width: 10),
                    const Text('Modifier produit',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: green)),
                  ]),
                  const SizedBox(height: 16),
                  _inputField(nameCtrl, 'Nom du produit', Icons.label),
                  const SizedBox(height: 12),
                  const Text('Catégorie',
                      style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: categories.where((c) => c != 'Tous').map((cat) {
                      final sel = selectedCat == cat;
                      return GestureDetector(
                        onTap: () => setModal(() => selectedCat = cat),
                        child: Container(
                          width: 72, height: 72,
                          decoration: BoxDecoration(
                            color: sel ? green.withOpacity(0.12) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: sel ? green : Colors.transparent, width: 2),
                          ),
                          child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _categoryImageWidget(cat, 32, sel),
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
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _inputField(
                        qtyCtrl, 'Quantité', Icons.numbers, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(child: _inputField(
                        minCtrl, 'Stock min', Icons.low_priority, isNumber: true)),
                  ]),
                  const SizedBox(height: 10),
                  _inputField(priceCtrl, 'Prix (FCFA)', Icons.attach_money,
                      isNumber: true),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.save),
                      label: const Text('Sauvegarder',
                          style: TextStyle(fontSize: 16)),
                      onPressed: () {
                        setState(() {
                          p.name = nameCtrl.text;
                          p.category = selectedCat;
                          p.quantity = int.tryParse(qtyCtrl.text) ?? p.quantity;
                          p.price = double.tryParse(priceCtrl.text) ?? p.price;
                          p.minStock = int.tryParse(minCtrl.text) ?? p.minStock;
                        });
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            backgroundColor: green,
                            content: Text('${p.name} modifié !')));
                      },
                    ),
                  ),
                ]),
          ),
        ),
      ),
    );
  }

  void _showAddStockDialog(Product p) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          _categoryImageWidget(p.category, 24, false),
          const SizedBox(width: 8),
          const Text('Ajouter stock', style: TextStyle(color: green)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${p.name}\nStock actuel : ${p.quantity}',
              style: const TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          _inputField(ctrl, 'Quantité à ajouter', Icons.add, isNumber: true),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: green, foregroundColor: Colors.white),
            onPressed: () {
              final add = int.tryParse(ctrl.text) ?? 0;
              if (add > 0) {
                setState(() => p.quantity += add);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    backgroundColor: green,
                    content: Text('+$add ajouté à ${p.name}')));
              }
            },
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(Product p) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Supprimer produit',
            style: TextStyle(color: Colors.red)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _categoryImageWidget(p.category, 48, false),
          const SizedBox(height: 12),
          Text('Supprimer "${p.name}" ?\nCette action est irréversible.'),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => products.remove(p));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  backgroundColor: Colors.red,
                  content: Text('Produit supprimé')));
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
  Widget _categoryImageWidget(String category, double size, bool selected) {
    final paths = {
      'Alimentaire': 'lib/assets/categories/aliment.jpg',
      'Boissons':    'lib/assets/categories/boisson.jpg',
      'Hygiène':     'lib/assets/categories/hygienne.jpg',
      'Autre':       'lib/assets/categories/autre.jpg',
    };
    final emojis = {
      'Alimentaire': '🍚',
      'Boissons':    '🥤',
      'Hygiène':     '🧼',
      'Autre':       '📦',
    };
    final path = paths[category];
    if (path == null) {
      return Text(emojis[category] ?? '📦',
          style: TextStyle(fontSize: size * 0.85));
    }
    return Image.asset(path,
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (_, __, ___) =>
            Text(emojis[category] ?? '📦',
                style: TextStyle(fontSize: size * 0.85)));
  }

  Widget _inputField(TextEditingController ctrl, String label, IconData icon,
      {bool isNumber = false}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      inputFormatters:
          isNumber ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: green, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: green, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatPrice(double price) {
    if (price >= 1000000) return '${(price / 1000000).toStringAsFixed(1)}M';
    if (price >= 1000) return '${(price / 1000).toStringAsFixed(0)}k';
    return price.toStringAsFixed(0);
  }
}