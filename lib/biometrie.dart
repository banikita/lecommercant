import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:app_settings/app_settings.dart';

class BiometriePage extends StatefulWidget {
  final int commercantId;
  const BiometriePage({super.key, required this.commercantId});

  @override
  State<BiometriePage> createState() => _BiometriePageState();
}

class _BiometriePageState extends State<BiometriePage> {
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kWhite = Colors.white;
  static const Color kBg = Color(0xFFF5F5F0);
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kSuccess = Color(0xFF38A169);
  static const Color kDanger = Color(0xFFE53E3E);
  static const int maxTentatives = 5;

  final _supa = Supabase.instance.client;
  final LocalAuthentication _localAuth = LocalAuthentication();

  Map<String, dynamic> _biometrie = {
    'empreinte': false,
    'reconnaissance': false,
    'pin': true,
    'exigerBiometrie': false,
  };
  bool _saved = false;
  bool _isBiometricSupported = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _verifierOuInitialiserPin();
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    final available = await _localAuth.canCheckBiometrics;
    if (available) {
      final biometrics = await _localAuth.getAvailableBiometrics();
      setState(() {
        _isBiometricSupported = true;
        _availableBiometrics = biometrics;
      });
    } else {
      setState(() {
        _isBiometricSupported = false;
        _availableBiometrics = [];
      });
    }
  }

  Future<void> _verifierOuInitialiserPin() async {
    try {
      final response = await _supa
          .from('commercants')
          .select('pin_hash, tentatives_connexion')
          .eq('id', widget.commercantId)
          .maybeSingle();

      if (response == null || response['pin_hash'] == null) {
        const pinParDefaut = "0000";
        final hash = _hashPin(pinParDefaut);
        await _supa
            .from('commercants')
            .update({'pin_hash': hash, 'tentatives_connexion': 0})
            .eq('id', widget.commercantId);
        if (mounted) {
          _showSnackBar('PIN par défaut créé (0000). Modifiez‑le dès que possible.',
              erreur: false);
        }
      }
    } catch (e) {
      debugPrint("Erreur vérification PIN: $e");
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _biometrie['empreinte'] = prefs.getBool('biometrie_empreinte') ?? false;
      _biometrie['reconnaissance'] = prefs.getBool('biometrie_reconnaissance') ?? false;
      _biometrie['pin'] = prefs.getBool('biometrie_pin') ?? true;
      _biometrie['exigerBiometrie'] = prefs.getBool('biometrie_exigerBiometrie') ?? false;
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrie_$key', value);
  }

  Future<void> _update(String key, bool value) async {
    if (key != 'pin' && !value && !_biometrie['pin'] && 
        !(_biometrie['empreinte'] || _biometrie['reconnaissance'] || value)) {
      _showSnackBar('Vous devez garder au moins une méthode d’authentification active.',
          erreur: true);
      return;
    }
    if (key == 'pin' && !value && !_biometrie['empreinte'] && !_biometrie['reconnaissance']) {
      _showSnackBar('Vous devez garder au moins une méthode d’authentification active.',
          erreur: true);
      return;
    }

    setState(() => _biometrie[key] = value);
    await _savePreference(key, value);
    setState(() => _saved = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _saved = false);
    });
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<int> _getTentatives() async {
    final response = await _supa
        .from('commercants')
        .select('tentatives_connexion')
        .eq('id', widget.commercantId)
        .maybeSingle();
    return response?['tentatives_connexion'] as int? ?? 0;
  }

  Future<void> _incrementerTentatives() async {
    final current = await _getTentatives();
    await _supa
        .from('commercants')
        .update({'tentatives_connexion': current + 1})
        .eq('id', widget.commercantId);
  }

  Future<void> _resetTentatives() async {
    await _supa
        .from('commercants')
        .update({'tentatives_connexion': 0})
        .eq('id', widget.commercantId);
  }

  Future<bool> _verifierPin(String pin) async {
    final tentatives = await _getTentatives();
    if (tentatives >= maxTentatives) {
      _showSnackBar('Trop de tentatives échouées. Réessayez plus tard.', erreur: true);
      return false;
    }

    final response = await _supa
        .from('commercants')
        .select('pin_hash')
        .eq('id', widget.commercantId)
        .maybeSingle();
    final storedHash = response?['pin_hash'] as String?;

    if (storedHash == null) {
      const pinParDefaut = "0000";
      final hash = _hashPin(pinParDefaut);
      await _supa
          .from('commercants')
          .update({'pin_hash': hash, 'tentatives_connexion': 0})
          .eq('id', widget.commercantId);
      _showSnackBar('PIN réinitialisé à 0000. Veuillez réessayer.', erreur: true);
      return false;
    }

    final hashSaisi = _hashPin(pin);
    final correct = storedHash == hashSaisi;
    if (!correct) {
      await _incrementerTentatives();
      _showSnackBar('PIN incorrect (${tentatives + 1}/$maxTentatives)', erreur: true);
    } else {
      await _resetTentatives();
    }
    return correct;
  }

  Future<void> _mettreAJourPin(String nouveauPin) async {
    final newHash = _hashPin(nouveauPin);
    await _supa
        .from('commercants')
        .update({'pin_hash': newHash, 'tentatives_connexion': 0})
        .eq('id', widget.commercantId);
  }

  Future<bool> _preAuthenticate() async {
    final forceBiometric = _biometrie['exigerBiometrie'] == true;
    bool success = false;

    if (forceBiometric && (_biometrie['empreinte'] || _biometrie['reconnaissance'])) {
      success = await _checkBiometric();
    } else {
      if (_biometrie['empreinte'] || _biometrie['reconnaissance']) {
        success = await _checkBiometric();
      }
      if (!success && (_biometrie['pin'] ?? false)) {
        success = await _demanderPin("Authentifiez-vous pour modifier le code PIN");
      }
    }
    if (!success) {
      _showSnackBar('Authentification requise', erreur: true);
    }
    return success;
  }

  Future<bool> _checkBiometric() async {
    if (!_isBiometricSupported) return false;
    final options = AuthenticationOptions(
      stickyAuth: true,
      biometricOnly: _biometrie['empreinte'] || _biometrie['reconnaissance'],
    );
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Vérifiez votre identité',
        options: options,
      );
    } catch (e) {
      return false;
    }
  }

  Future<bool> _demanderPin(String raison) async {
    final pinController = TextEditingController();
    final completer = Completer<bool>();
    bool obscureText = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Code PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(raison),
                const SizedBox(height: 12),
                TextField(
                  controller: pinController,
                  obscureText: obscureText,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    hintText: 'Entrez votre code PIN',
                    suffixIcon: IconButton(
                      icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureText = !obscureText),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  completer.complete(false);
                },
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final ok = await _verifierPin(pinController.text);
                  Navigator.pop(ctx);
                  completer.complete(ok);
                },
                child: const Text('Valider'),
              ),
            ],
          );
        },
      ),
    );
    return completer.future;
  }

  Future<void> _ouvrirDialogueNouveauPin() async {
    final nouveauCtrl = TextEditingController();
    final confirmationCtrl = TextEditingController();
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool saving = false;

    return showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Changer le code PIN'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nouveauCtrl,
                  obscureText: obscureNew,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Nouveau code PIN (4+ chiffres)',
                    suffixIcon: IconButton(
                      icon: Icon(obscureNew ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmationCtrl,
                  obscureText: obscureConfirm,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le code PIN',
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirm ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nouveau = nouveauCtrl.text.trim();
                  final confirmation = confirmationCtrl.text.trim();

                  if (nouveau.isEmpty || confirmation.isEmpty) {
                    _showSnackBar('Veuillez remplir tous les champs', erreur: true);
                    return;
                  }
                  if (nouveau.length < 4) {
                    _showSnackBar('Le nouveau PIN doit comporter au moins 4 chiffres',
                        erreur: true);
                    return;
                  }
                  if (nouveau != confirmation) {
                    _showSnackBar('Les codes PIN ne correspondent pas', erreur: true);
                    return;
                  }

                  setDialogState(() => saving = true);
                  await _mettreAJourPin(nouveau);
                  setDialogState(() => saving = false);
                  Navigator.pop(ctx);
                  _showSnackBar('Code PIN modifié avec succès');
                },
                child: saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Changer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _modifierPin() async {
    final authenticated = await _preAuthenticate();
    if (!authenticated) return;
    await _ouvrirDialogueNouveauPin();
  }

  void _showSnackBar(String msg, {bool erreur = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: erreur ? kDanger : kSuccess,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Widget _toggleRow(IconData icon, String label, String key, {String? tooltip}) {
    bool value = _biometrie[key] ?? false;
    bool enabled = true;
    if (key == 'empreinte' && !_availableBiometrics.contains(BiometricType.fingerprint)) {
      enabled = false;
    }
    if (key == 'reconnaissance' && !_availableBiometrics.contains(BiometricType.face)) {
      enabled = false;
    }
    return SwitchListTile(
      value: value,
      onChanged: enabled ? (v) => _update(key, v) : null,
      activeColor: kGreen,
      secondary: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: kGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: enabled ? kGreen : kMuted, size: 18),
      ),
      title: Row(
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: enabled ? null : kMuted)),
          if (tooltip != null && !enabled) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: tooltip,
              child: Icon(Icons.info_outline, size: 14, color: kMuted),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        title: const Text('Biométrie et sécurité', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: kGreen,
        foregroundColor: kWhite,
        elevation: 0,
      ),
      body: Column(
        children: [
          if (_saved) _buildSuccessBanner(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (!_isBiometricSupported) _buildNoBiometricWarning(),
                _buildBioCard(),
                const SizedBox(height: 20),
                _buildPinChangeButton(),
                const SizedBox(height: 20),
                _buildSecurityOptionsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() => Container(
        width: double.infinity,
        color: kSuccess,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: const Text('✓ Préférences enregistrées',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      );

  Widget _buildNoBiometricWarning() => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kDanger.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDanger.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber, color: kDanger),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Aucune méthode biométrique détectée',
                      style: TextStyle(fontWeight: FontWeight.bold, color: kDanger)),
                  const Text('Votre appareil ne prend pas en charge l\'empreinte ou la reconnaissance faciale.',
                      style: TextStyle(fontSize: 12)),
                  TextButton(
                    onPressed: () => AppSettings.openAppSettings(),
                    child: const Text('Ouvrir les paramètres', style: TextStyle(color: kGreen)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildBioCard() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            _toggleRow(Icons.fingerprint, 'Authentification par empreinte', 'empreinte',
                tooltip: 'Capteur d\'empreinte non disponible'),
            const Divider(height: 1, indent: 70, color: kBorder),
            _toggleRow(Icons.face, 'Reconnaissance faciale', 'reconnaissance',
                tooltip: 'Camera faciale non disponible'),
            const Divider(height: 1, indent: 70, color: kBorder),
            SwitchListTile(
              value: _biometrie['pin'] ?? true,
              onChanged: (v) => _update('pin', v),
              activeColor: kGreen,
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.pin, color: kGreen, size: 18),
              ),
              title: const Text('Code PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );

  Widget _buildPinChangeButton() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Modifier le code PIN', style: TextStyle(fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Tooltip(
                    message: 'Une vérification d’identité sera demandée avant la modification',
                    child: Icon(Icons.help_outline, size: 18, color: kMuted),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _modifierPin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  foregroundColor: kWhite,
                  minimumSize: const Size(double.infinity, 44),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Changer le code PIN'),
              ),
            ],
          ),
        ),
      );

  Widget _buildSecurityOptionsCard() => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            SwitchListTile(
              value: _biometrie['exigerBiometrie'] ?? false,
              onChanged: (v) => _update('exigerBiometrie', v),
              activeColor: kGreen,
              secondary: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.security, color: kGreen, size: 18),
              ),
              title: const Text('Exiger la biométrie pour les actions sensibles',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              subtitle: const Text('Modification du PIN, accès aux données confidentielles'),
            ),
          ],
        ),
      );
}