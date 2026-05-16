import 'package:flutter/material.dart';
import 'package:le_commercant/database/app_database.dart';

class BiometriePage extends StatefulWidget {
  const BiometriePage({super.key});

  @override
  State<BiometriePage> createState() => _BiometriePageState();
}

class _BiometriePageState extends State<BiometriePage> {
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kGreenLight = Color(0xFF2D7A61);
  static const Color kWhite = Colors.white;
  static const Color kBg = Color(0xFFF5F5F0);
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kSuccess = Color(0xFF38A169);
  static const Color kDanger = Color(0xFFE53E3E);

  late Map<String, dynamic> _biometrie;
  bool _saved = false;
  int? _commercantId;

  final _ancienPinCtrl = TextEditingController();
  final _nouveauPinCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _biometrie = AppDatabase.getBiometrie();
    final commercial = await AppDatabase.instance.chargerCommercant();
    if (commercial != null) {
      _commercantId = commercial['id'];
    }
    setState(() {});
  }

  Future<void> _update(String key, bool value) async {
    setState(() {
      _biometrie[key] = value;
    });
    await AppDatabase.saveBiometrie(_biometrie);
    _showSuccess();
  }

  void _showSuccess() {
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  Future<void> _changerPin() async {
    final ancien = _ancienPinCtrl.text.trim();
    final nouveau = _nouveauPinCtrl.text.trim();

    if (_commercantId == null) {
      _showSnackBar('Erreur : commerçant non trouvé', erreur: true);
      return;
    }
    if (ancien.isEmpty || nouveau.isEmpty) {
      _showSnackBar('Veuillez remplir tous les champs', erreur: true);
      return;
    }
    if (nouveau.length < 4) {
      _showSnackBar('Le nouveau PIN doit comporter au moins 4 chiffres', erreur: true);
      return;
    }

    final verif = await AppDatabase.instance.verifierPin(_commercantId!, ancien);
    if (!verif) {
      _showSnackBar('Ancien PIN incorrect', erreur: true);
      return;
    }

    await AppDatabase.instance.mettreAJourPin(_commercantId!, nouveau);
    _ancienPinCtrl.clear();
    _nouveauPinCtrl.clear();
    _showSnackBar('Code PIN modifié avec succès');
  }

  void _showSnackBar(String msg, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erreur ? kDanger : kSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _toggleRow(IconData icon, String label, String key) {
    bool value = _biometrie[key] ?? false;
    return SwitchListTile(
      value: value,
      onChanged: (v) => _update(key, v),
      activeColor: kGreen,
      secondary: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: kGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: kGreen, size: 18),
      ),
      title: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          if (key == 'empreinte')
            Tooltip(
              message: 'Utilisez le capteur d’empreinte de votre appareil',
              child: Icon(Icons.info_outline, size: 14, color: kMuted),
            ),
          if (key == 'reconnaissance')
            Tooltip(
              message: 'Reconnaissance faciale (si disponible)',
              child: Icon(Icons.info_outline, size: 14, color: kMuted),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ancienPinCtrl.dispose();
    _nouveauPinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Biométrie', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kGreen,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_saved)
            Container(
              width: double.infinity,
              color: kSuccess,
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: const Text('✓ Préférences enregistrées',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Column(
                    children: [
                      _toggleRow(Icons.fingerprint, 'Authentification par empreinte', 'empreinte'),
                      const Divider(height: 1, indent: 70, color: kBorder),
                      _toggleRow(Icons.face, 'Reconnaissance faciale', 'reconnaissance'),
                      const Divider(height: 1, indent: 70, color: kBorder),
                      SwitchListTile(
                        value: _biometrie['pin'] ?? true,
                        onChanged: (v) => _update('pin', v),
                        activeColor: kGreen,
                        secondary: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: kGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.pin, color: kGreen, size: 18),
                        ),
                        title: const Text('Code PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Modifier le code PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _ancienPinCtrl,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Ancien code PIN',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nouveauPinCtrl,
                          obscureText: true,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'Nouveau code PIN (4+ chiffres)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _changerPin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kGreen,
                            foregroundColor: kWhite,
                            minimumSize: const Size(double.infinity, 44),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Modifier le code PIN'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    leading: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: kGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.history, color: kGreen, size: 18),
                    ),
                    title: const Text('Dernière authentification', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    trailing: Text(_biometrie['lastAuth'] ?? 'Jamais', style: const TextStyle(color: kMuted)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}