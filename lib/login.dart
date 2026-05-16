import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import ajouté
import 'dashbord.dart';

class LoginPage extends StatefulWidget {
  final int commercantId;
  final String nomCommercant;
  final String nomBoutique;
  final String ville;

  const LoginPage({
    super.key,
    required this.commercantId,
    required this.nomCommercant,
    required this.nomBoutique,
    required this.ville,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  static const _greenFill = Color(0xFF80CBC4);
  static const _greenEmpty = Color(0xFFB2DFDB);
  static const _greenMain = Color(0xFF0F6E56);
  static const _deleteColor = Color(0xFF424242);
  static const _keyColor = Color(0xFF212121);
  static const _red = Color(0xFFE53935);
  static const _green = Color(0xFF0F6E56);

  static const int _pinLength = 4;
  static const int _maxTentatives = 5;

  String _pin = '';
  int _erreurs = 0;
  bool _checking = false;
  bool _shaking = false;

  final _supabase = Supabase.instance.client;
  final _storage = const FlutterSecureStorage(); // Instance pour le mode hors-ligne

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;
  late AnimationController _dotCtrl;
  late Animation<double> _dotAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(_shakeCtrl);

    _dotCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _dotAnim = CurvedAnimation(parent: _dotCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  void _onKey(String key) {
    if (_checking || _pin.length >= _pinLength) return;
    HapticFeedback.lightImpact();
    _dotCtrl.reset();
    _dotCtrl.forward();
    setState(() => _pin += key);
    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 150), _verifier);
    }
  }

  void _onDelete() {
    if (_checking || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ─────────────────────────────────────────
  //  VÉRIFICATION (Hybride En ligne / Hors-ligne)
  // ─────────────────────────────────────────
  Future<void> _verifier() async {
    if (!mounted) return;
    setState(() => _checking = true);

    final pinSaisiHash = _hashPin(_pin);

    try {
      // TENTATIVE 1 : EN LIGNE (Supabase)
      final response = await _supabase
          .from('commercants')
          .select('pin_hash, tentatives_connexion')
          .eq('id', widget.commercantId)
          .single();

      final pinHashEnBase = response['pin_hash'] as String? ?? '';
      final tentativesActuelles = (response['tentatives_connexion'] as int?) ?? 0;
      final correct = pinHashEnBase.isNotEmpty && pinHashEnBase == pinSaisiHash;

      if (correct) {
        // Sauvegarde locale sécurisée pour le mode hors-ligne futur
        await _storage.write(key: 'offline_pin_${widget.commercantId}', value: pinSaisiHash);
        
        await _supabase.from('commercants').update({
          'tentatives_connexion': 0,
          'derniere_connexion': DateTime.now().toIso8601String(),
        }).eq('id', widget.commercantId);

        _naviguerVersDashboard();
      } else {
        _gererEchec(tentativesActuelles + 1);
      }
    } catch (e) {
      // TENTATIVE 2 : HORS-LIGNE (Si erreur réseau)
      final savedHash = await _storage.read(key: 'offline_pin_${widget.commercantId}');

      if (savedHash != null && savedHash == pinSaisiHash) {
        _naviguerVersDashboard();
      } else {
        if (!mounted) return;
        setState(() {
          _pin = '';
          _checking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(savedHash == null 
              ? 'Connexion internet requise pour la première fois' 
              : 'Code incorrect (Mode hors-ligne)'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted && _checking) setState(() => _checking = false);
    }
  }

  void _naviguerVersDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          commercantId: widget.commercantId,
          nomCommercant: widget.nomCommercant,
          nomBoutique: widget.nomBoutique,
          ville: widget.ville,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  void _gererEchec(int nouvellesTentatives) async {
    HapticFeedback.heavyImpact();
    await _supabase.from('commercants').update({'tentatives_connexion': nouvellesTentatives}).eq('id', widget.commercantId);
    _shakeCtrl.reset();
    await _shakeCtrl.forward();
    if (!mounted) return;
    setState(() {
      _erreurs = nouvellesTentatives;
      _shaking = true;
      _pin = '';
      _checking = false;
    });
    await Future.delayed(const Duration(milliseconds: 500));
    if (mounted) setState(() => _shaking = false);
    if (nouvellesTentatives >= _maxTentatives) _dialogBlocage();
  }

  // ─────────────────────────────────────────
  //  DIALOGUES ET SHEETS (Inchangés)
  // ─────────────────────────────────────────
  void _dialogBlocage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Compte bloqué', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Trop de tentatives incorrectes.\nVérifiez votre numéro pour réinitialiser.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _sheetOubliPin(); },
            child: const Text('Réinitialiser', style: TextStyle(color: _red, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _sheetOubliPin() {
    final telCtrl = TextEditingController();
    bool erreur = false;
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                const Text('Réinitialisation', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(
                  controller: telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(hintText: 'Numéro de téléphone', filled: true, fillColor: Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none)),
                ),
                if (erreur) const Text('Numéro non reconnu', style: TextStyle(color: _red)),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _greenMain, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: loading ? null : () async {
                      setBS(() => loading = true);
                      try {
                        final res = await _supabase.from('commercants').select('telephone').eq('id', widget.commercantId).single();
                        if (telCtrl.text.trim() == res['telephone']) {
                          Navigator.pop(context); _sheetNouveauPin();
                        } else { setBS(() { erreur = true; loading = false; }); }
                      } catch (_) { setBS(() { erreur = true; loading = false; }); }
                    },
                    child: loading ? const CircularProgressIndicator(color: Colors.white) : const Text('Vérifier', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _sheetNouveauPin() {
    final pinCtrl = TextEditingController();
    final confCtrl = TextEditingController();
    bool loading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Nouveau PIN', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
                const SizedBox(height: 20),
                TextField(controller: pinCtrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(hintText: 'Nouveau PIN')),
                TextField(controller: confCtrl, keyboardType: TextInputType.number, maxLength: 4, obscureText: true, decoration: const InputDecoration(hintText: 'Confirmer')),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: _greenMain, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: loading ? null : () async {
                      if (pinCtrl.text != confCtrl.text) return;
                      setBS(() => loading = true);
                      final h = _hashPin(pinCtrl.text);
                      await _supabase.from('commercants').update({'pin_hash': h, 'tentatives_connexion': 0}).eq('id', widget.commercantId);
                      await _storage.write(key: 'offline_pin_${widget.commercantId}', value: h);
                      Navigator.pop(context);
                    },
                    child: const Text('Enregistrer', style: TextStyle(color: Colors.white)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────
  //  UI BUILD (Inchangé)
  // ─────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          const Spacer(flex: 2),
          _buildLogo(),
          const Spacer(flex: 2),
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(offset: Offset(_shaking ? _shakeAnim.value : 0, 0), child: child),
            child: _buildDots(),
          ),
          if (_erreurs > 0) Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text('Code incorrect · $_erreurs/$_maxTentatives', style: const TextStyle(color: _red, fontWeight: FontWeight.w600)),
          ),
          const Spacer(flex: 2),
          if (_checking) const CircularProgressIndicator(color: _greenMain),
          _buildKeyboard(),
          const SizedBox(height: 24),
          GestureDetector(onTap: _sheetOubliPin, child: const Text('Oublié votre code secret?', style: TextStyle(color: _greenMain, fontWeight: FontWeight.w500))),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _buildLogo() => Column(children: [
    Container(width: 110, height: 110, decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(28)), child: const Icon(Icons.storefront_rounded, color: _greenMain, size: 58)),
    const SizedBox(height: 14),
    const Text('Le Commerçant', style: TextStyle(color: _greenMain, fontSize: 18, fontWeight: FontWeight.w800)),
  ]);

  Widget _buildDots() => Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pinLength, (i) => AnimatedContainer(duration: const Duration(milliseconds: 150), margin: const EdgeInsets.symmetric(horizontal: 14), width: i < _pin.length ? 16 : 14, height: i < _pin.length ? 16 : 14, decoration: BoxDecoration(shape: BoxShape.circle, color: _shaking ? _red : (i < _pin.length ? _greenFill : _greenEmpty)))));

  Widget _buildKeyboard() => Padding(padding: const EdgeInsets.symmetric(horizontal: 24), child: Column(children: [_keyRow(['1', '2', '3']), const SizedBox(height: 4), _keyRow(['4', '5', '6']), const SizedBox(height: 4), _keyRow(['7', '8', '9']), const SizedBox(height: 4), _bottomRow()]));

  Widget _keyRow(List<String> keys) => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: keys.map(_buildKey).toList());

  Widget _bottomRow() => Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [const SizedBox(width: 88, height: 88), _buildKey('0'), _buildDeleteKey()]);

  Widget _buildKey(String val) => GestureDetector(onTap: () => _onKey(val), behavior: HitTestBehavior.opaque, child: SizedBox(width: 88, height: 88, child: Center(child: Text(val, style: const TextStyle(fontSize: 30, color: _keyColor)))));

  Widget _buildDeleteKey() => GestureDetector(onTap: _onDelete, onLongPress: () { if (!_checking) setState(() => _pin = ''); }, behavior: HitTestBehavior.opaque, child: SizedBox(width: 88, height: 88, child: const Center(child: Icon(Icons.backspace_outlined, size: 26, color: _deleteColor))));
}