import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:le_commercant/database/app_database.dart';
import 'package:intl/intl.dart';

class ProfilPage extends StatefulWidget {
  final int commercantId;
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
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kGreenMid = Color(0xFF22614D);
  static const Color kGreenLight = Color(0xFF2D7A61);
  static const Color kAccent = Color(0xFFE8A04A);
  static const Color kBg = Color(0xFFF5F5F0);
  static const Color kWhite = Colors.white;
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kDanger = Color(0xFFE53E3E);
  static const Color kSuccess = Color(0xFF38A169);

  late Map<String, dynamic> _commercant;
  bool _editing = false;
  bool _saved = false;
  bool _loading = true;

  late TextEditingController _prenomCtrl;
  late TextEditingController _nomCtrl;
  late TextEditingController _telephoneCtrl;
  late TextEditingController _boutiqueCtrl;
  late TextEditingController _villeCtrl;

  @override
  void initState() {
    super.initState();
    _loadCommercant();
  }

  Future<void> _loadCommercant() async {
    setState(() => _loading = true);
    final data = await AppDatabase.instance.chargerCommercant();
    if (data != null && mounted) {
      setState(() {
        _commercant = data;
        _initControllers();
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  void _initControllers() {
    _prenomCtrl = TextEditingController(text: _commercant['prenom'] ?? '');
    _nomCtrl = TextEditingController(text: _commercant['nom'] ?? '');
    _telephoneCtrl = TextEditingController(text: _commercant['telephone'] ?? '');
    _boutiqueCtrl = TextEditingController(text: _commercant['nom_boutique'] ?? '');
    _villeCtrl = TextEditingController(text: _commercant['ville'] ?? '');
  }

  @override
  void dispose() {
    _prenomCtrl.dispose();
    _nomCtrl.dispose();
    _telephoneCtrl.dispose();
    _boutiqueCtrl.dispose();
    _villeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = {
      'prenom': _prenomCtrl.text,
      'nom': _nomCtrl.text,
      'telephone': _telephoneCtrl.text,
      'nom_boutique': _boutiqueCtrl.text,
      'ville': _villeCtrl.text,
    };
    final db = AppDatabase.instance;
    final dbConn = await db.database;
    await dbConn.update(
      'commercants',
      updated,
      where: 'id = ?',
      whereArgs: [widget.commercantId],
    );
    await _loadCommercant(); // recharge les données mises à jour
    setState(() {
      _editing = false;
      _saved = true;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Widget _field(String label, TextEditingController ctrl, {bool enabled = true}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(),
              style: const TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          _editing && enabled
              ? TextField(
                  controller: ctrl,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kGreenLight)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kGreenLight, width: 1.5)),
                  ),
                )
              : Text(ctrl.text.isNotEmpty ? ctrl.text : 'Non renseigné',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final avatarText = '${(_commercant['prenom']?[0] ?? '')}${(_commercant['nom']?[0] ?? '')}'.toUpperCase();
    final fullName = '${_commercant['prenom'] ?? ''} ${_commercant['nom'] ?? ''}'.trim();
    final role = 'Gérant';
    final joinedDate = _commercant['created_at'] != null
        ? DateFormat('dd MMM yyyy').format(DateTime.parse(_commercant['created_at']))
        : 'Récemment';

    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kGreen, kGreenMid],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 20)),
                        const Expanded(
                          child: Text('Mon Profil',
                              style: TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.w700)),
                        ),
                        TextButton.icon(
                          onPressed: _editing ? _save : () => setState(() => _editing = true),
                          style: TextButton.styleFrom(
                            backgroundColor: _editing ? kAccent : Colors.white24,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          ),
                          icon: Icon(_editing ? Icons.save_outlined : Icons.edit_outlined,
                              color: kWhite, size: 16),
                          label: Text(_editing ? 'Sauver' : 'Modifier',
                              style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: kAccent,
                    child: Text(avatarText.isNotEmpty ? avatarText : 'P',
                        style: const TextStyle(color: kGreen, fontWeight: FontWeight.w800, fontSize: 24)),
                  ),
                  const SizedBox(height: 10),
                  Text(fullName.isNotEmpty ? fullName : widget.nomCommercant,
                      style: const TextStyle(color: kWhite, fontWeight: FontWeight.w700, fontSize: 18)),
                  const SizedBox(height: 2),
                  Text(role,
                      style: const TextStyle(color: Colors.white70, fontSize: 13)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Success banner
          if (_saved)
            Container(
              width: double.infinity,
              color: kSuccess,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text('✓ Profil mis à jour avec succès',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w600)),
            ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 18, bottom: 6),
                    child: Text('INFORMATIONS PERSONNELLES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        _field('Prénom', _prenomCtrl),
                        _field('Nom', _nomCtrl),
                        _field('Téléphone', _telephoneCtrl),
                        _field('Nom de la boutique', _boutiqueCtrl),
                        _field('Ville', _villeCtrl),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('MEMBRE DEPUIS',
                                  style: TextStyle(fontSize: 11, color: kMuted, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                              const SizedBox(height: 4),
                              Text(joinedDate,
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Padding(
                    padding: EdgeInsets.only(left: 18, top: 16, bottom: 6),
                    child: Text('COMPTE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.lock_outline, color: kGreen, size: 18),
                          ),
                          title: const Text('Changer le mot de passe',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                          onTap: () {
                            // À implémenter : ouvrir une page de changement de mot de passe
                          },
                        ),
                        const Divider(height: 1, indent: 70, color: kBorder),
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                          ),
                          title: const Text('Supprimer le compte',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDanger)),
                          trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                          onTap: () {
                            // À implémenter : dialogue de confirmation puis suppression
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}