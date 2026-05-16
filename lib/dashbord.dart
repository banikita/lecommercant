import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login.dart';
import 'dettes.dart';
import 'fournisseurs_page.dart';
import 'page_stock.dart';
import 'page_ventes.dart';
import 'page_nouvelle_vente.dart';
import 'profil.dart';
import 'biometrie.dart';
import 'notifications_page.dart';
import 'parametre.dart';
import 'aide.dart';
import 'creanciers_page.dart';
import 'depenses_page.dart';
import 'all_transactions_page.dart';

// ─────────────────────────────────────────
// DESIGN SYSTEM
// ─────────────────────────────────────────
class _DS {
  static const emerald      = Color(0xFF0A5C47);
  static const emeraldMid   = Color(0xFF0D7A5F);
  static const emeraldLight = Color(0xFF10926F);
  static const emeraldGlow  = Color(0xFF1DC58A);
  static const emeraldFaint = Color(0xFFE8F5F0);
  static const emeraldTint  = Color(0xFFC8EBE0);
  static const gold         = Color(0xFFD4940A);
  static const goldLight    = Color(0xFFFFF0C2);
  static const goldMid      = Color(0xFFFABF35);
  static const coral        = Color(0xFFCC3B3B);
  static const coralLight   = Color(0xFFFFF0F0);
  static const sapphire     = Color(0xFF1A5FA8);
  static const sapphireLight= Color(0xFFEBF3FF);
  static const ink          = Color(0xFF0F1A14);
  static const inkMid       = Color(0xFF243028);
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

  static const cardGrad = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D7A5F), Color(0xFF1DC58A)],
  );

  static List<BoxShadow> get shadowSm => [
    BoxShadow(
      color: const Color(0xFF0A5C47).withValues(alpha: 0.08),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static TextStyle display(double size,
          {Color color = ink, FontWeight fw = FontWeight.w800}) =>
      TextStyle(
          fontFamily: 'Roboto',
          fontSize: size,
          fontWeight: fw,
          color: color,
          letterSpacing: -0.3);

  static TextStyle body(double size,
          {Color color = ink, FontWeight fw = FontWeight.w500}) =>
      TextStyle(fontFamily: 'Roboto', fontSize: size, fontWeight: fw, color: color);

  static TextStyle mono(double size,
          {Color color = ink, FontWeight fw = FontWeight.w700}) =>
      TextStyle(fontFamily: 'RobotoMono', fontSize: size, fontWeight: fw, color: color);
}

class DashboardPage extends StatefulWidget {
  final int    commercantId;
  final String nomCommercant;
  final String nomBoutique;
  final String ville;

  const DashboardPage({
    super.key,
    required this.commercantId,
    required this.nomCommercant,
    required this.nomBoutique,
    required this.ville,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin {

  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _transactions = [];
  bool   _loading = true;
  String? _photoUrl;

  bool _sidebarOpen = false;
  late AnimationController _sidebarCtrl;
  late AnimationController _contentCtrl;
  late Animation<double>   _sidebarAnim;
  late Animation<double>   _contentFade;

  int _unreadCount = 0;
  RealtimeChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    _sidebarCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 320));
    _contentCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _sidebarAnim =
        CurvedAnimation(parent: _sidebarCtrl, curve: Curves.easeOutCubic);
    _contentFade = CurvedAnimation(parent: _contentCtrl, curve: Curves.easeOut);
    _chargerDonnees();
    _loadUnreadCount();
    _listenToNotifications();
  }

  @override
  void dispose() {
    _sidebarCtrl.dispose();
    _contentCtrl.dispose();
    _notifChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUnreadCount() async {
    try {
      final response = await _supabase
          .from('notifications')
          .select('id')
          .eq('commercant_id', widget.commercantId)
          .eq('est_lu', false);
      final count = response.length;
      if (mounted && _unreadCount != count) {
        setState(() => _unreadCount = count);
      }
    } catch (e) {
      debugPrint('Erreur chargement compteur notifications: $e');
    }
  }

  void _listenToNotifications() {
    _notifChannel = _supabase
        .channel('notifications-changes-${widget.commercantId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'commercant_id',
            value: widget.commercantId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              setState(() => _unreadCount++);
            } else if (payload.eventType == PostgresChangeEvent.update) {
              final newLu = payload.newRecord['est_lu'];
              final oldLu = payload.oldRecord['est_lu'];
              if (newLu != oldLu) {
                setState(() {
                  if (newLu == true) _unreadCount--;
                  else _unreadCount++;
                });
              }
            } else if (payload.eventType == PostgresChangeEvent.delete) {
              final wasUnread = payload.oldRecord['est_lu'] == false;
              if (wasUnread) setState(() => _unreadCount--);
            }
          },
        )
        .subscribe();
  }

  // ─────────────────────────────────────────
  // CHARGEMENT : toutes les transactions (sans limit, tri global, puis 12 plus récentes)
  // ─────────────────────────────────────────
  Future<void> _chargerDonnees() async {
    if (!mounted) return;
    if (_transactions.isEmpty) setState(() => _loading = true);

    try {
      List<Map<String, dynamic>> toutes = [];

      // 1. Ventes (exclure crédits)
      final ventes = await _supabase
          .from('ventes')
          .select('id, date_vente, nom_client, total_montant, statut_paiement')
          .eq('commercant_id', widget.commercantId)
          .neq('statut_paiement', 'À crédit')
          .order('date_vente', ascending: false);

      final ventesIds = ventes.map<int>((v) => v['id'] as int).toList();
      Map<int, Map<String, dynamic>> ventesProduits = {};
      if (ventesIds.isNotEmpty) {
        final items = await _supabase
            .from('ventes_items')
            .select('vente_id, nom_produit, image_url')
            .inFilter('vente_id', ventesIds);
        for (var item in items) {
          final vId = item['vente_id'] as int;
          if (!ventesProduits.containsKey(vId)) {
            ventesProduits[vId] = {
              'nom_produit': item['nom_produit'],
              'image_url': item['image_url']
            };
          }
        }
      }

      for (final v in ventes) {
        final produitInfo = ventesProduits[v['id']];
        toutes.add({
          'source': 'vente',
          'label': v['nom_client'] ?? '',
          'produit': produitInfo?['nom_produit'] ?? 'Vente',
          'montant': (v['total_montant'] ?? 0).toDouble(),
          'photo_url': produitInfo?['image_url'],
          'date': v['date_vente'],
          'id_ref': v['id'],
          'icone': '💵',
          'couleur': _DS.emeraldMid,
        });
      }

      // 2. Dettes clients (montant initial)
      final dettes = await _supabase
          .from('dettes')
          .select('id, created_at, nom_debiteur, montant_initial, debiteur_id')
          .eq('commercant_id', widget.commercantId)
          .order('created_at', ascending: false);

      final dettesIds = dettes.map<int>((d) => d['id'] as int).toList();
      Map<int, String?> imagesDette = {};
      if (dettesIds.isNotEmpty) {
        final items = await _supabase
            .from('dette_produits')
            .select('dette_id, image_url')
            .inFilter('dette_id', dettesIds);
        for (var item in items) {
          imagesDette[item['dette_id'] as int] = item['image_url'] as String?;
        }
      }

      for (final d in dettes) {
        toutes.add({
          'source': 'dette',
          'label': d['nom_debiteur'] ?? '',
          'produit': 'Dette client',
          'montant': (d['montant_initial'] ?? 0).toDouble(),
          'photo_url': imagesDette[d['id']],
          'date': d['created_at'],
          'id_ref': d['id'],
          'debiteur_id': d['debiteur_id'],
          'icone': '📝',
          'couleur': _DS.gold,
        });
      }

      // 3. Paiements clients (remboursements)
      final paiements = await _supabase
          .from('paiements')
          .select('id, date, montant, dette_id, dettes(nom_debiteur, debiteur_id)')
          .eq('commercant_id', widget.commercantId)
          .order('date', ascending: false);

      final dettesIdPaiement = paiements.map<int>((p) => p['dette_id'] as int).toSet().toList();
      Map<int, String?> imageParDette = {};
      if (dettesIdPaiement.isNotEmpty) {
        final produits = await _supabase
            .from('dette_produits')
            .select('dette_id, image_url')
            .inFilter('dette_id', dettesIdPaiement);
        for (var prod in produits) {
          imageParDette[prod['dette_id'] as int] = prod['image_url'] as String?;
        }
      }

      for (final p in paiements) {
        final detteInfo = p['dettes'] as Map?;
        final nomDebiteur = detteInfo?['nom_debiteur'] ?? 'Client';
        final detteId = p['dette_id'] as int;
        toutes.add({
          'source': 'paiement_client',
          'label': nomDebiteur,
          'produit': 'Remboursement reçu',
          'montant': (p['montant'] ?? 0).toDouble(),
          'photo_url': imageParDette[detteId],
          'date': p['date'],
          'id_ref': p['id'],
          'debiteur_id': detteInfo?['debiteur_id'],
          'icone': '💳',
          'couleur': _DS.sapphire,
        });
      }

      // 4. Paiements créanciers
      final paiementsCreanciers = await _supabase
          .from('depenses')
          .select('id, date_depense, montant, libelle, creanciers(nom)')
          .eq('commercant_id', widget.commercantId)
          .eq('type', 'remboursement_creancier')
          .order('date_depense', ascending: false);

      for (final d in paiementsCreanciers) {
        final creancierNom = (d['creanciers'] as Map?)?['nom'] ?? 'Créancier';
        toutes.add({
          'source': 'paiement_creancier',
          'label': creancierNom,
          'produit': d['libelle'] ?? 'Remboursement',
          'montant': (d['montant'] ?? 0).toDouble(),
          'photo_url': null,
          'date': d['date_depense'],
          'id_ref': d['id'],
          'icone': '🤝',
          'couleur': _DS.coral,
        });
      }

      // 5. Autres dépenses (achats fournisseurs, divers)
      final autresDepenses = await _supabase
          .from('depenses')
          .select('id, date_depense, montant, libelle, type, categorie')
          .eq('commercant_id', widget.commercantId)
          .inFilter('type', ['achat_fournisseur', 'divers'])
          .order('date_depense', ascending: false);

      for (final d in autresDepenses) {
        final type = d['type'];
        String label = type == 'achat_fournisseur' ? 'Fournisseur' : (d['categorie'] ?? 'Divers');
        String produit = d['libelle'] ?? (type == 'achat_fournisseur' ? 'Achat' : 'Dépense');
        String icone = type == 'achat_fournisseur' ? '🛒' : '📉';
        Color couleur = type == 'achat_fournisseur' ? _DS.gold : _DS.slate;
        toutes.add({
          'source': 'depense',
          'label': label,
          'produit': produit,
          'montant': (d['montant'] ?? 0).toDouble(),
          'photo_url': null,
          'date': d['date_depense'],
          'id_ref': d['id'],
          'icone': icone,
          'couleur': couleur,
        });
      }

      // Photo du commerçant
      String? photoUrl;
      try {
        final profil = await _supabase
            .from('commercants')
            .select('photo_url')
            .eq('id', widget.commercantId)
            .single();
        photoUrl = profil['photo_url'] as String?;
      } catch (_) {}

      // Tri chronologique descendant (le plus récent en premier)
      toutes.sort((a, b) {
        final da = DateTime.tryParse(a['date'] as String? ?? '') ?? DateTime(2000);
        final db = DateTime.tryParse(b['date'] as String? ?? '') ?? DateTime(2000);
        return db.compareTo(da);
      });

      // Limiter à 12 pour le tableau de bord
      if (toutes.length > 12) toutes = toutes.sublist(0, 12);

      if (!mounted) return;
      setState(() {
        _transactions = toutes;
        _photoUrl = photoUrl;
        _loading = false;
      });
      _contentCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('Erreur dashboard: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ─────────────────────────────────────────
  // NAVIGATION
  // ─────────────────────────────────────────
  void _goTo(Widget page) {
    Navigator.push(context, _slide(page)).then((_) => _chargerDonnees());
  }

  void _sidebarGoTo(Widget page) {
    _closeSidebar();
    Future.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      Navigator.push(context, _slide(page)).then((_) => _chargerDonnees());
    });
  }

  PageRoute _slide(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, a, __, child) => SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
              .animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 320),
      );

  Future<void> _deconnecter() async {
    _closeSidebar();
    try { await _supabase.auth.signOut(); } catch (_) {}
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LoginPage(
            commercantId:  widget.commercantId,
            nomCommercant: widget.nomCommercant,
            nomBoutique:   widget.nomBoutique,
            ville:         widget.ville,
          ),
          transitionsBuilder: (_, a, __, child) =>
              FadeTransition(opacity: a, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
        (_) => false);
  }

  void _toggleSidebar() {
    HapticFeedback.lightImpact();
    setState(() => _sidebarOpen = !_sidebarOpen);
    _sidebarOpen ? _sidebarCtrl.forward() : _sidebarCtrl.reverse();
  }

  void _closeSidebar() {
    if (_sidebarOpen) {
      setState(() => _sidebarOpen = false);
      _sidebarCtrl.reverse();
    }
  }

  // ─────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────
  String get _initiales {
    final p = widget.nomCommercant.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  String _fmt(double n) => n
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]} ');

  Widget _buildAvatarWidget({required double size}) {
    if (_photoUrl != null && _photoUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: _photoUrl!,
        width: size, height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialesWidget(size),
        errorWidget:  (_, __, ___) => _initialesWidget(size),
      );
    }
    return _initialesWidget(size);
  }

  Widget _initialesWidget(double size) => Container(
        width: size, height: size,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFFABF35), Color(0xFFE8A010)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            _initiales,
            style: TextStyle(
              fontFamily: 'Roboto',
              fontSize: size * 0.35,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF5A3000),
            ),
          ),
        ),
      );

  // ─────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: _DS.headerGrad,
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x260A5C47),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(children: [
        GestureDetector(
          onTap: _toggleSidebar,
          child: AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, __) => Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20), width: 1),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    3,
                    (i) => Padding(
                      padding: EdgeInsets.only(bottom: i < 2 ? 4 : 0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 280),
                        width: i == 1 ? 12 : 18,
                        height: 2,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Bonjour 👋',
                style: _DS.body(12,
                    color: Colors.white.withValues(alpha: 0.65))),
            const SizedBox(height: 2),
            Text(widget.nomCommercant,
                style: _DS.display(17, color: Colors.white)),
          ]),
        ),
        GestureDetector(
          onTap: () => _goTo(ProfilPage(
            commercantId:  widget.commercantId,
            nomCommercant: widget.nomCommercant,
          )),
          child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  color: Colors.white.withValues(alpha: 0.40), width: 2),
              boxShadow: [
                BoxShadow(
                  color: _DS.gold.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(child: _buildAvatarWidget(size: 46)),
          ),
        ),
      ]),
    );
  }

  // ── ACCÈS RAPIDE ──
  Widget _buildQuickActions() {
    final actions = [
      {'label': 'Dettes', 'image': 'assets/images/icons/dettes.png', 'page': DettesPage(commercantId: widget.commercantId)},
      {'label': 'Fournisseurs', 'image': 'assets/images/icons/fournisseurs.png', 'page': FournisseursPage(commercantId: widget.commercantId, nomBoutique: widget.nomBoutique)},
      {'label': 'Créanciers', 'image': 'assets/images/icons/creanciers.png', 'page': CreanciersPage(commercantId: widget.commercantId, nomCommercant: widget.nomCommercant)},
      {'label': 'Dépenses', 'image': 'assets/images/icons/depenses.png', 'page': DepensesPage(commercantId: widget.commercantId)},
      {'label': 'Stock', 'image': 'assets/images/icons/stock.png', 'page': StockPage(commercantId: widget.commercantId)},
      {'label': 'Ventes', 'image': 'assets/images/icons/ventes.png', 'page': VentesPage(commercantId: widget.commercantId)},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.85,
        ),
        itemCount: actions.length,
        itemBuilder: (_, i) {
          final action = actions[i];
          return _QuickActionImage(
            label: action['label'] as String,
            imagePath: action['image'] as String,
            onTap: () => _goTo(action['page'] as Widget),
          );
        },
      ),
    );
  }

  // ── BOUTON NOUVELLE VENTE ──
  Widget _buildNewSaleBtn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          HapticFeedback.mediumImpact();
          _goTo(NouvelleVentePage(
            commercantId: widget.commercantId,
            nomCommercant: widget.nomCommercant,
            nomBoutique: widget.nomBoutique,
          ));
        },
        icon: const Icon(Icons.add, size: 24),
        label: const Text('Nouvelle vente',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _DS.emeraldMid,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  // ── TRANSACTIONS RÉCENTES ──
  Widget _buildTransactions() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
        child: Row(children: [
          Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
                color: _DS.emeraldMid,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 8),
          Text('TRANSACTIONS RÉCENTES',
              style: _DS
                  .body(11, color: _DS.slate, fw: FontWeight.w700)
                  .copyWith(letterSpacing: 1.2)),
          const Spacer(),
          GestureDetector(
            onTap: () => _goTo(AllTransactionsPage(commercantId: widget.commercantId)),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                  color: _DS.emeraldFaint,
                  borderRadius: BorderRadius.circular(20)),
              child: Text('Voir tout',
                  style: _DS.body(11,
                      color: _DS.emeraldMid, fw: FontWeight.w700)),
            ),
          ),
        ]),
      ),
      if (_transactions.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Column(children: [
              const Text('🧾', style: TextStyle(fontSize: 36)),
              const SizedBox(height: 12),
              Text('Aucune transaction récente',
                  style: _DS.body(13, color: _DS.slate)),
            ]),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _transactions.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _TxCard(
            tx: _transactions[i],
            index: i,
            onTap: _buildOnTap(_transactions[i]),
            fmt: _fmt,
          ),
        ),
    ]);
  }

  VoidCallback? _buildOnTap(Map<String, dynamic> tx) {
    final source = tx['source'] as String?;
    if (source == 'vente') {
      return () => _goTo(VentesPage(commercantId: widget.commercantId));
    } else if (source == 'dette') {
      final debiteurId = tx['debiteur_id'];
      if (debiteurId != null) {
        return () => _goTo(DettesPage(commercantId: widget.commercantId, selectedDebiteurId: debiteurId));
      } else {
        return () => _goTo(DettesPage(commercantId: widget.commercantId));
      }
    } else if (source == 'paiement_client') {
      final debiteurId = tx['debiteur_id'];
      if (debiteurId != null) {
        return () => _goTo(DettesPage(commercantId: widget.commercantId, selectedDebiteurId: debiteurId));
      } else {
        return () => _goTo(DettesPage(commercantId: widget.commercantId));
      }
    } else if (source == 'paiement_creancier') {
      final creancierId = tx['id_ref'];
      return () => _goTo(CreanciersPage(
        commercantId: widget.commercantId,
        selectedCreancierId: creancierId,
        nomCommercant: widget.nomCommercant,
      ));
    } else {
      return () => _goTo(DepensesPage(commercantId: widget.commercantId));
    }
  }

  // ── SIDEBAR ──
  Widget _buildSidebar() {
    return Container(
      width: 290,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: _DS.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x1A000000), blurRadius: 30, offset: Offset(4, 0))
        ],
      ),
      child: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
            decoration: const BoxDecoration(gradient: _DS.headerGrad),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 62, height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.40),
                          width: 2.5),
                      boxShadow: [
                        BoxShadow(
                          color: _DS.gold.withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(child: _buildAvatarWidget(size: 62)),
                  ),
                  const SizedBox(height: 12),
                  Text(widget.nomCommercant,
                      style: _DS.display(16, color: Colors.white)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('${widget.nomBoutique} · ${widget.ville}',
                        style: _DS.body(11,
                            color: Colors.white.withValues(alpha: 0.80))),
                  ),
                ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(children: [
                  _SideItem(
                    '👤', 'Mon profil',
                    const Color(0xFFEEEDFE), const Color(0xFF5B55D8),
                    () => _sidebarGoTo(ProfilPage(
                      commercantId:  widget.commercantId,
                      nomCommercant: widget.nomCommercant,
                    )),
                  ),
                  _SideItem('🔒', 'Biométrie & sécurité', _DS.fog, _DS.slate,
                      () => _sidebarGoTo(
                          BiometriePage(commercantId: widget.commercantId))),
                  _SideItem('🔔', 'Notifications', _DS.goldLight, _DS.gold,
                      () => _sidebarGoTo(
                          NotificationsPage(commercantId: widget.commercantId)),
                      badgeCount: _unreadCount,
                  ),
                  _SideItem('📊', 'Rapports & statistiques', _DS.emeraldFaint,
                      _DS.emeraldMid,
                      () => _sidebarGoTo(
                          VentesPage(commercantId: widget.commercantId))),
                  _SideItem('⚙️', 'Paramètres', _DS.fog, _DS.slate,
                      () => _sidebarGoTo(ParametresPage())),
                  _SideItem('❓', 'Aide & support', _DS.sapphireLight,
                      _DS.sapphire,
                      () => _sidebarGoTo(const AidePage())),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    child: Divider(height: 1, color: _DS.mist),
                  ),
                  _SideItem('🚪', 'Se déconnecter', _DS.coralLight, _DS.coral,
                      _deconnecter,
                      isDestructive: true),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _DS.fog,
        body: Stack(children: [
          SafeArea(
            child: GestureDetector(
              onTap: _closeSidebar,
              child: Column(children: [
                _buildHeader(),
                Expanded(
                  child: _loading
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(
                                  color: _DS.emeraldMid, strokeWidth: 2.5),
                              const SizedBox(height: 16),
                              Text('Chargement…',
                                  style: _DS.body(13, color: _DS.slate)),
                            ],
                          ),
                        )
                      : FadeTransition(
                          opacity: _contentFade,
                          child: RefreshIndicator(
                            onRefresh: _chargerDonnees,
                            color: _DS.emeraldMid,
                            strokeWidth: 2.5,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildQuickActions(),
                                  _buildNewSaleBtn(),
                                  _buildTransactions(),
                                  const SizedBox(height: 32),
                                ],
                              ),
                            ),
                          ),
                        ),
                ),
              ]),
            ),
          ),
          // Overlay
          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, __) => _sidebarOpen
                ? GestureDetector(
                    onTap: _closeSidebar,
                    child: Container(
                      color: _DS.ink.withValues(alpha: 0.45 * _sidebarAnim.value),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Sidebar
          AnimatedBuilder(
            animation: _sidebarAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(-290 * (1 - _sidebarAnim.value), 0),
              child: child,
            ),
            child: _buildSidebar(),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// BOUTON ACCÈS RAPIDE
// ─────────────────────────────────────────
class _QuickActionImage extends StatelessWidget {
  final String label;
  final String imagePath;
  final VoidCallback onTap;

  const _QuickActionImage({
    required this.label,
    required this.imagePath,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                imagePath,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.image, size: 28, color: _DS.slate),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _DS.slate,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────
// TRANSACTION CARD
// ─────────────────────────────────────────
class _TxCard extends StatelessWidget {
  final Map<String, dynamic> tx;
  final VoidCallback?        onTap;
  final int                  index;
  final String Function(double) fmt;

  const _TxCard({
    required this.tx,
    this.onTap,
    required this.index,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final label    = tx['label']    as String? ?? '';
    final produit  = tx['produit']  as String? ?? '';
    final montant  = (tx['montant'] as num?)?.toDouble() ?? 0;
    final photoUrl = tx['photo_url'] as String?;
    final icone    = tx['icone']    as String? ?? '📄';
    final couleur  = tx['couleur']  as Color? ?? _DS.slate;
    final source   = tx['source']   as String? ?? '';

    // Signe (+ pour entrées, - pour dépenses)
    String signe = '';
    if (source == 'vente' || source == 'paiement_client') {
      signe = '+';
    } else if (source == 'paiement_creancier' || source == 'depense') {
      signe = '-';
    }

    String badgeTexte = '';
    Color badgeBg = _DS.emeraldFaint;
    Color badgeClr = _DS.emeraldMid;

    switch (source) {
      case 'vente':
        badgeTexte = 'Vente';
        break;
      case 'dette':
        badgeTexte = 'Dette';
        badgeBg = _DS.goldLight;
        badgeClr = _DS.gold;
        break;
      case 'paiement_client':
        badgeTexte = 'Remboursement';
        badgeBg = _DS.sapphireLight;
        badgeClr = _DS.sapphire;
        break;
      case 'paiement_creancier':
        badgeTexte = 'Paiement créancier';
        badgeBg = _DS.coralLight;
        badgeClr = _DS.coral;
        break;
      case 'depense':
        badgeTexte = 'Dépense';
        badgeBg = _DS.mist;
        badgeClr = _DS.slate;
        break;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _DS.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _DS.shadowSm,
          border: Border.all(color: _DS.mist, width: 0.8),
        ),
        child: Row(children: [
          // Image
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(color: couleur.withOpacity(0.1), borderRadius: BorderRadius.circular(13)),
            child: Center(
              child: photoUrl != null && photoUrl.isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: Image.network(photoUrl, width: 46, height: 46, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Text(icone, style: const TextStyle(fontSize: 24))),
                    )
                  : Text(icone, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                Text(produit, style: const TextStyle(fontSize: 12, color: _DS.slate), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(badgeTexte, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeClr)),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$signe${fmt(montant)} F',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: couleur)),
              const SizedBox(height: 6),
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: _DS.emeraldFaint, borderRadius: BorderRadius.circular(8)),
                child: const Center(child: Icon(Icons.chevron_right, size: 18, color: _DS.emeraldMid)),
              ),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────
// SIDEBAR ITEM
// ─────────────────────────────────────────
class _SideItem extends StatefulWidget {
  final String       emoji, label;
  final Color        iconBg, iconColor;
  final VoidCallback onTap;
  final bool         isDestructive;
  final int?         badgeCount;

  const _SideItem(
    this.emoji, this.label, this.iconBg, this.iconColor, this.onTap,
    {this.isDestructive = false, this.badgeCount}
  );

  @override
  State<_SideItem> createState() => _SideItemState();
}

class _SideItemState extends State<_SideItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _hovered = true),
      onTapUp:     (_) {
        setState(() => _hovered = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: _hovered
              ? (widget.isDestructive ? _DS.coralLight : _DS.emeraldFaint)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
                color: widget.iconBg,
                borderRadius: BorderRadius.circular(11)),
            child: Center(
                child: Text(widget.emoji,
                    style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(widget.label,
                style: _DS.body(14,
                    color: widget.isDestructive ? _DS.coral : _DS.inkMid,
                    fw: FontWeight.w600)),
          ),
          if (widget.badgeCount != null && widget.badgeCount! > 0)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${widget.badgeCount}',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          Icon(Icons.chevron_right,
              size: 16,
              color: widget.isDestructive ? _DS.coral : _DS.mist),
        ]),
      ),
    );
  }
}