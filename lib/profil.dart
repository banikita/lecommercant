import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

final _sb = Supabase.instance.client;

// ─────────────────────────────────────────
// MODÈLE — colonnes exactes de la table commercants
// id | prenom | nom | telephone | nom_boutique | ville | pin_hash | photo_url | created_at
// ─────────────────────────────────────────
class Commercant {
  final int     id;
  String        prenom;
  String        nom;
  String?       telephone;
  String?       nomBoutique;
  String?       ville;
  String?       photoUrl;
  final String? pinHash;
  final DateTime? createdAt;

  Commercant({
    required this.id,
    required this.prenom,
    required this.nom,
    this.telephone,
    this.nomBoutique,
    this.ville,
    this.photoUrl,
    this.pinHash,
    this.createdAt,
  });

  factory Commercant.fromMap(Map<String, dynamic> m) => Commercant(
    id:          m['id'] as int,
    prenom:      (m['prenom'] ?? '').toString(),
    nom:         (m['nom']    ?? '').toString(),
    telephone:   m['telephone']?.toString(),
    nomBoutique: m['nom_boutique']?.toString(),
    ville:       m['ville']?.toString(),
    photoUrl:    m['photo_url']?.toString(),
    pinHash:     m['pin_hash']?.toString(),
    createdAt:   m['created_at'] != null
        ? DateTime.tryParse(m['created_at'].toString())
        : null,
  );

  String get nomComplet => '$prenom $nom'.trim();
  String get initiale   => prenom.isNotEmpty ? prenom[0].toUpperCase()
                         : nom.isNotEmpty    ? nom[0].toUpperCase()
                         : 'C';
}

// ─────────────────────────────────────────
// PAGE PROFIL
// ─────────────────────────────────────────
class ProfilPage extends StatefulWidget {
  final int    commercantId;
  final String nomCommercant;

  const ProfilPage({
    super.key,
    required this.commercantId,
    required this.nomCommercant,
  });

  @override
  State<ProfilPage> createState() => _ProfilPageState();
}

class _ProfilPageState extends State<ProfilPage> {
  static const Color kGreen      = Color(0xFF1A4A3A);
  static const Color kGreenMid   = Color(0xFF22614D);
  static const Color kGreenLight = Color(0xFF2D7A61);
  static const Color kAccent     = Color(0xFFE8A04A);
  static const Color kBg         = Color(0xFFF5F5F0);
  static const Color kWhite      = Colors.white;
  static const Color kMuted      = Color(0xFF6B7280);
  static const Color kBorder     = Color(0xFFE2E8F0);
  static const Color kDanger     = Color(0xFFE53E3E);
  static const Color kSuccess    = Color(0xFF38A169);

  Commercant? _c;
  bool _loading = true;
  bool _editing = false;
  bool _saving  = false;
  bool _saved   = false;

  late TextEditingController _prenomCtrl;
  late TextEditingController _nomCtrl;
  late TextEditingController _telCtrl;
  late TextEditingController _boutiqueCtrl;
  late TextEditingController _villeCtrl;

  Uint8List? _imageBytes;
  String?    _imageExt;

  int _totalProduits = 0;
  int _stockFaibles  = 0;

  @override
  void initState() {
    super.initState();
    _prenomCtrl   = TextEditingController();
    _nomCtrl      = TextEditingController();
    _telCtrl      = TextEditingController();
    _boutiqueCtrl = TextEditingController();
    _villeCtrl    = TextEditingController();
    _charger();
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telCtrl.dispose();
    _boutiqueCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════
  //  CHARGEMENT
  // ═══════════════════════════════════════
  Future<void> _charger() async {
    setState(() => _loading = true);
    try {
      final data = await _sb
          .from('commercants')
          .select()
          .eq('id', widget.commercantId)
          .single();

      _c = Commercant.fromMap(data);
      _prenomCtrl.text   = _c!.prenom;
      _nomCtrl.text      = _c!.nom;
      _telCtrl.text      = _c!.telephone     ?? '';
      _boutiqueCtrl.text = _c!.nomBoutique   ?? '';
      _villeCtrl.text    = _c!.ville         ?? '';

      // Stats produits
      final produits = await _sb
          .from('products')
          .select('quantity, min_stock')
          .eq('commercant_id', widget.commercantId);

      _totalProduits = produits.length;
      _stockFaibles  = (produits as List).where((p) {
        final q  = (p['quantity']  as int?) ?? 0;
        final ms = (p['min_stock'] as int?) ?? 5;
        return q <= ms;
      }).length;

    } catch (e) {
      _toast('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ═══════════════════════════════════════
  //  SAUVEGARDER
  // ═══════════════════════════════════════
  Future<void> _sauvegarder() async {
    if (_prenomCtrl.text.trim().isEmpty) {
      _toast('Le prénom est obligatoire', success: false);
      return;
    }
    setState(() => _saving = true);
    try {
      String? photoUrl = _c?.photoUrl;
      if (_imageBytes != null) photoUrl = await _uploadPhoto();

      await _sb.from('commercants').update({
        'prenom':       _prenomCtrl.text.trim(),
        'nom':          _nomCtrl.text.trim(),
        'telephone':    _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim(),
        'nom_boutique': _boutiqueCtrl.text.trim().isEmpty ? null : _boutiqueCtrl.text.trim(),
        'ville':        _villeCtrl.text.trim().isEmpty ? null : _villeCtrl.text.trim(),
        'photo_url':    photoUrl,
      }).eq('id', widget.commercantId);

      setState(() {
        _c!.prenom      = _prenomCtrl.text.trim();
        _c!.nom         = _nomCtrl.text.trim();
        _c!.telephone   = _telCtrl.text.trim().isEmpty ? null : _telCtrl.text.trim();
        _c!.nomBoutique = _boutiqueCtrl.text.trim().isEmpty ? null : _boutiqueCtrl.text.trim();
        _c!.ville       = _villeCtrl.text.trim().isEmpty ? null : _villeCtrl.text.trim();
        _c!.photoUrl    = photoUrl;
        _editing        = false;
        _saved          = true;
        _imageBytes     = null;
      });

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _saved = false);
      });
    } catch (e) {
      _toast('Erreur : $e', success: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════════════════════════
  //  PHOTO
  // ═══════════════════════════════════════
  Future<void> _choisirPhoto() async {
    ImageSource? source;
    if (!kIsWeb) {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: kWhite,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2))),
              const Text('Photo de profil',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kGreen)),
              const SizedBox(height: 16),
              ListTile(
                onTap: () => Navigator.pop(context, ImageSource.camera),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                leading: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.camera_alt, color: Colors.orange)),
                title: const Text('Prendre une photo',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 10),
              ListTile(
                onTap: () => Navigator.pop(context, ImageSource.gallery),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200)),
                leading: Container(padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.photo_library, color: Colors.blue)),
                title: const Text('Galerie', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ]),
          ),
        ),
      );
    } else {
      source = ImageSource.gallery;
    }
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: source, maxWidth: 400, maxHeight: 400, imageQuality: 85);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    final parts = picked.name.split('.');
    setState(() {
      _imageBytes = bytes;
      _imageExt   = parts.length > 1 ? parts.last : 'jpg';
    });
  }

  Future<String?> _uploadPhoto() async {
    try {
      final ext      = _imageExt ?? 'jpg';
      final fileName = 'profil_${widget.commercantId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await _sb.storage.from('profil-photos').uploadBinary(
        fileName, _imageBytes!,
        fileOptions: FileOptions(contentType: 'image/$ext', upsert: true),
      );
      return _sb.storage.from('profil-photos').getPublicUrl(fileName);
    } catch (e) {
      _toast('Erreur photo : $e', success: false);
      return _c?.photoUrl;
    }
  }

  void _annulerEdition() {
    setState(() {
      _editing        = false;
      _imageBytes     = null;
      _prenomCtrl.text   = _c?.prenom      ?? '';
      _nomCtrl.text      = _c?.nom         ?? '';
      _telCtrl.text      = _c?.telephone   ?? '';
      _boutiqueCtrl.text = _c?.nomBoutique ?? '';
      _villeCtrl.text    = _c?.ville       ?? '';
    });
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kGreen))
          : Column(children: [
              _buildHeader(),
              if (_saved)
                Container(
                  width: double.infinity, color: kSuccess,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: const Text('✓ Profil mis à jour avec succès',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              Expanded(
                child: RefreshIndicator(
                  color: kGreen,
                  onRefresh: _charger,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _buildStats(),
                      const SizedBox(height: 16),
                      _sectionLabel('INFORMATIONS PERSONNELLES'),
                      _card([
                        _field('Prénom',        Icons.badge_outlined,    _prenomCtrl),
                        _field('Nom',           Icons.person_outline,    _nomCtrl),
                        _field('Téléphone',     Icons.phone_outlined,    _telCtrl,
                            type: TextInputType.phone),
                        _field('Nom boutique',  Icons.store_outlined,    _boutiqueCtrl),
                        _field('Ville',         Icons.location_on_outlined, _villeCtrl),
                        _fieldStatic('Membre depuis', Icons.calendar_today_outlined,
                            _c?.createdAt != null ? _formatDate(_c!.createdAt!) : 'N/A'),
                      ]),
                      if (_editing) ...[
                        const SizedBox(height: 16),
                        _buildBoutons(),
                      ],
                      const SizedBox(height: 40),
                    ]),
                  ),
                ),
              ),
            ]),
    );
  }

  // ── HEADER ──
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
          colors: [kGreen, kGreenMid],
          begin: Alignment.topLeft, end: Alignment.bottomRight),
    ),
    child: SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
          child: Row(children: [
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 20),
            ),
            const Expanded(
              child: Text('Mon Profil',
                  style: TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            if (_editing)
              IconButton(
                onPressed: _annulerEdition,
                icon: const Icon(Icons.close, color: kWhite, size: 20),
              ),
            TextButton.icon(
              onPressed: _editing
                  ? (_saving ? null : _sauvegarder)
                  : () => setState(() => _editing = true),
              style: TextButton.styleFrom(
                backgroundColor: _editing ? kAccent : Colors.white24,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              icon: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
                  : Icon(_editing ? Icons.save_outlined : Icons.edit_outlined,
                      color: kWhite, size: 16),
              label: Text(
                _saving ? 'Sauvegarde...' : (_editing ? 'Sauver' : 'Modifier'),
                style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Avatar
        GestureDetector(
          onTap: _editing ? _choisirPhoto : null,
          child: Stack(children: [
            CircleAvatar(
              radius: 44,
              backgroundColor: kAccent,
              child: _buildAvatar(),
            ),
            if (_editing)
              Positioned(
                bottom: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: kWhite, shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4)],
                  ),
                  child: const Icon(Icons.camera_alt, color: kGreen, size: 16),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 10),

        // Nom complet
        Text(
          _c?.nomComplet ?? widget.nomCommercant,
          style: const TextStyle(color: kWhite, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 4),

        // Boutique + ville
        if (_c?.nomBoutique != null || _c?.ville != null)
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.store_outlined, color: Colors.white60, size: 12),
            const SizedBox(width: 4),
            Text(
              [_c?.nomBoutique, _c?.ville]
                  .where((v) => v != null && v.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ]),
        const SizedBox(height: 6),

        // Badge ID
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('ID #${widget.commercantId}',
              style: const TextStyle(color: Colors.white70, fontSize: 11)),
        ),
        const SizedBox(height: 20),
      ]),
    ),
  );

  Widget _buildAvatar() {
    if (_imageBytes != null) {
      return ClipOval(child: Image.memory(_imageBytes!, fit: BoxFit.cover, width: 88, height: 88));
    }
    if (_c?.photoUrl != null && _c!.photoUrl!.isNotEmpty) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _c!.photoUrl!,
          fit: BoxFit.cover, width: 88, height: 88,
          placeholder: (_, __) => _initialeWidget(),
          errorWidget: (_, __, ___) => _initialeWidget(),
        ),
      );
    }
    return _initialeWidget();
  }

  Widget _initialeWidget() => Text(
    _c?.initiale ?? 'C',
    style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 32),
  );

  // ── STATS ──
  Widget _buildStats() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      _statCard('📦', '$_totalProduits', 'Produits',    kGreen,                   const Color(0xFFF0FAF5)),
      const SizedBox(width: 10),
      _statCard('⚠️', '$_stockFaibles',  'Stock faible', const Color(0xFFE65100), const Color(0xFFFFF3E0)),
      const SizedBox(width: 10),
      _statCard('🆔', '#${widget.commercantId}', 'Mon ID', const Color(0xFF6A1B9A), const Color(0xFFF3E5F5)),
    ]),
  );

  Widget _statCard(String emoji, String val, String label, Color couleur, Color bg) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: kWhite,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
          ),
          child: Column(children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 6),
            Text(val, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: couleur)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(fontSize: 10, color: kMuted), textAlign: TextAlign.center),
          ]),
        ),
      );

  // ── CHAMPS ──
  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(left: 18, top: 4, bottom: 8),
    child: Text(text,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
            color: kGreen, letterSpacing: 0.8)),
  );

  Widget _card(List<Widget> enfants) => Container(
    margin: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: kWhite,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10)],
    ),
    child: Column(
      children: List.generate(enfants.length, (i) => Column(children: [
        enfants[i],
        if (i < enfants.length - 1)
          const Divider(height: 1, indent: 20, endIndent: 20, color: kBorder),
      ])),
    ),
  );

  Widget _field(
    String label, IconData icon, TextEditingController ctrl, {
    TextInputType type = TextInputType.text,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _editing
            ? TextFormField(
                controller: ctrl,
                keyboardType: type,
                maxLines: maxLines,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: label,
                  prefixIcon: Icon(icon, color: kGreen, size: 18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kGreenLight, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              )
            : Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF0FAF5),
                      borderRadius: BorderRadius.circular(10)),
                  child: Icon(icon, color: kGreen, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(label, style: const TextStyle(
                        color: kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 3),
                    Text(
                      ctrl.text.isEmpty ? 'Non renseigné' : ctrl.text,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: ctrl.text.isEmpty ? kMuted : const Color(0xFF1A1A1A)),
                    ),
                  ]),
                ),
              ]),
      );

  Widget _fieldStatic(String label, IconData icon, String valeur) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    child: Row(children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: kMuted, size: 18),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(
              color: kMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 3),
          Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
      ),
    ]),
  );

  Widget _buildBoutons() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    child: Row(children: [
      Expanded(
        child: OutlinedButton(
          onPressed: _annulerEdition,
          style: OutlinedButton.styleFrom(
            foregroundColor: kMuted,
            side: const BorderSide(color: kBorder),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Annuler'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          onPressed: _saving ? null : _sauvegarder,
          style: ElevatedButton.styleFrom(
            backgroundColor: kGreen, foregroundColor: kWhite,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: _saving
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(color: kWhite, strokeWidth: 2))
              : const Icon(Icons.save_outlined, size: 18),
          label: Text(_saving ? 'Sauvegarde...' : 'Enregistrer'),
        ),
      ),
    ]),
  );

  void _toast(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? kSuccess : kDanger,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
