import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashbord.dart';
import 'register.dart';

// ══════════════════════════════════════════════════════════════
//  PAGE LOGIN (PIN)
//  Affiché à chaque ouverture de l'app quand un compte existe.
//  Le PIN est comparé à celui sauvegardé lors de l'inscription.
// ══════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {

  static const _green      = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _greenDot   = Color(0xFF1D9E75);
  static const _greenEmpty = Color(0xFFB4B2A9);
  static const _red        = Color(0xFFA32D2D);
  static const _redLight   = Color(0xFFFCEBEB);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);
  static const _pinLength  = 4;

  String  _pin         = '';
  int     _erreurs     = 0;
  bool    _isChecking  = false;
  String  _nomAffiche  = '';
  String  _boutique    = '';
  String  _initiales   = '';
  bool    _shakeError  = false;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));
    _loadUserInfo();
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nomAffiche = prefs.getString('nom_commercant') ?? 'Commerçant';
      _boutique   = prefs.getString('nom_boutique')   ?? '';
      final parts = _nomAffiche.split(' ');
      _initiales  = parts.length >= 2
          ? '${parts[0][0]}${parts[1][0]}'.toUpperCase()
          : _nomAffiche.substring(0, 2).toUpperCase();
    });
  }

  void _onKey(String key) {
    if (_isChecking || _pin.length >= _pinLength) return;
    setState(() => _pin += key);
    if (_pin.length == _pinLength) _verifierPin();
  }

  void _onDelete() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifierPin() async {
    setState(() => _isChecking = true);
    final prefs   = await SharedPreferences.getInstance();
    final pinSave = prefs.getString('pin') ?? '';

    await Future.delayed(const Duration(milliseconds: 400));

    if (_pin == pinSave) {
      // ── Succès : marquer session active + naviguer
      await prefs.setBool('is_logged_in', true);
      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          nomCommercant: prefs.getString('nom_commercant') ?? '',
          nomBoutique:   prefs.getString('nom_boutique')   ?? '',
          ville:         prefs.getString('ville')          ?? '',
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ));
    } else {
      // ── Erreur : vibrer + réinitialiser
      setState(() { _erreurs++; _isChecking = false; });
      _shakeCtrl.reset();
      _shakeCtrl.forward();
      setState(() { _pin = ''; _shakeError = true; });
      Future.delayed(const Duration(milliseconds: 800),
          () { if (mounted) setState(() => _shakeError = false); });

      if (_erreurs >= 5) _blockerCompte();
    }
  }

  void _blockerCompte() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.lock_person_rounded, color: _red, size: 24),
          SizedBox(width: 10),
          Text('Compte bloqué', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
          '5 tentatives incorrectes. Votre compte est temporairement bloqué.',
          style: TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _ouvrirResetPin(); },
            child: const Text('Réinitialiser', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  void _ouvrirResetPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ResetPinSheet(),
    );
  }

  void _ouvrirOubliPin() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _OubliPinSheet(
        nomCommercant: _nomAffiche,
        onReset: () { Navigator.pop(context); _ouvrirResetPin(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          const SizedBox(height: 40),

          // ── Logo + Nom app
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(11)),
              child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 24)),
            const SizedBox(width: 10),
            const Text('Le Commerçant', style: TextStyle(
              color: _green, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          ]),

          const SizedBox(height: 36),

          // ── Avatar commerçant
          Container(width: 72, height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFFAC775), shape: BoxShape.circle,
              border: Border.all(color: _greenLight, width: 3)),
            child: Center(child: Text(_initiales,
              style: const TextStyle(color: Color(0xFF633806), fontSize: 24, fontWeight: FontWeight.w800)))),

          const SizedBox(height: 12),

          // ── Nom + boutique
          Text('Bonjour, $_nomAffiche',
            style: const TextStyle(color: _text, fontSize: 18, fontWeight: FontWeight.w800)),
          if (_boutique.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(_boutique, style: const TextStyle(color: _textMuted, fontSize: 13)),
          ],

          const SizedBox(height: 8),

          // ── Sous-titre
          const Text('Entrez votre code PIN',
            style: TextStyle(color: _textMuted, fontSize: 14)),

          const SizedBox(height: 32),

          // ── Indicateurs PIN (points)
          AnimatedBuilder(
            animation: _shakeAnim,
            builder: (_, child) => Transform.translate(
              offset: Offset(_shakeError
                  ? 12 * (0.5 - (_shakeAnim.value - 0.5).abs()) * 2
                  : 0, 0),
              child: child),
            child: Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pinLength, (i) {
                final filled = i < _pin.length;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16, height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _shakeError ? _red : filled ? _greenDot : _greenEmpty,
                    border: filled ? null : Border.all(color: _greyMid, width: 1.5)));
              })),
          ),

          // ── Message d'erreur
          if (_erreurs > 0) ...[
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: _redLight, borderRadius: BorderRadius.circular(20)),
              child: Text(
                _erreurs >= 4
                    ? '⚠️ Dernière tentative avant blocage'
                    : 'Code incorrect · ${_erreurs} essai${_erreurs > 1 ? 's' : ''}',
                style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700))),
          ],

          const SizedBox(height: 32),

          // ── Clavier numérique
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 50),
            child: Column(children: [
              _keyRow(['1','2','3']),
              const SizedBox(height: 10),
              _keyRow(['4','5','6']),
              const SizedBox(height: 10),
              _keyRow(['7','8','9']),
              const SizedBox(height: 10),
              _bottomRow(),
            ]),
          ),

          const Spacer(),

          // ── Lien "Code oublié"
          GestureDetector(
            onTap: _ouvrirOubliPin,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 32),
              child: Text('Oublié votre code PIN ?',
                style: const TextStyle(
                  color: _green, fontSize: 14, fontWeight: FontWeight.w700,
                  decoration: TextDecoration.underline,
                  decorationColor: _green)))),
        ]),
      ),
    );
  }

  Widget _keyRow(List<String> keys) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: keys.map(_buildKey).toList());

  Widget _bottomRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      const SizedBox(width: 80, height: 80),
      _buildKey('0'),
      _buildDeleteKey(),
    ]);

  Widget _buildKey(String val) {
    return GestureDetector(
      onTap: () => _onKey(val),
      child: Container(width: 80, height: 80,
        decoration: BoxDecoration(
          color: _grey, shape: BoxShape.circle),
        child: Center(child: Text(val,
          style: const TextStyle(
            fontSize: 26, fontWeight: FontWeight.w500, color: _text)))));
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: _onDelete,
      child: Container(width: 80, height: 80,
        decoration: const BoxDecoration(color: Colors.transparent, shape: BoxShape.circle),
        child: const Center(child: Icon(Icons.backspace_outlined, size: 26, color: _textMuted))));
  }
}

// ══════════════════════════════════════════════════════════════
//  SHEET : CODE OUBLIÉ (vérifier le numéro de téléphone)
// ══════════════════════════════════════════════════════════════
class _OubliPinSheet extends StatefulWidget {
  final String nomCommercant;
  final VoidCallback onReset;
  const _OubliPinSheet({required this.nomCommercant, required this.onReset});

  @override
  State<_OubliPinSheet> createState() => _OubliPinSheetState();
}

class _OubliPinSheetState extends State<_OubliPinSheet> {
  final _telCtrl = TextEditingController();
  bool _erreur   = false;

  static const _green      = Color(0xFF0F6E56);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red        = Color(0xFFA32D2D);
  static const _grey       = Color(0xFFF4F4F2);
  static const _hint       = Color(0xFF9CA3AF);
  static const _text       = Color(0xFF1A1A1A);

  Future<void> _verifier() async {
    final prefs    = await SharedPreferences.getInstance();
    final telSave  = prefs.getString('telephone') ?? '';
    if (_telCtrl.text.trim() == telSave) {
      widget.onReset();
    } else {
      setState(() => _erreur = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Handle
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Vérification du numéro',
            style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Entrez le numéro associé à votre compte pour réinitialiser votre PIN.',
            style: TextStyle(color: _hint, fontSize: 13, height: 1.5)),
          const SizedBox(height: 20),

          // Indicatif + champ
          Container(
            decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: const BoxDecoration(color: _greenLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
                child: const Row(children: [
                  Text('🇸🇳', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 6),
                  Text('+221', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
                ])),
              Expanded(child: TextField(
                controller: _telCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 9,
                decoration: const InputDecoration(
                  counterText: '', hintText: '77 000 00 00',
                  hintStyle: TextStyle(color: _hint, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)))),
            ])),

          if (_erreur) ...[
            const SizedBox(height: 8),
            const Text('❌ Numéro non reconnu. Vérifiez et réessayez.',
              style: TextStyle(color: _red, fontSize: 12)),
          ],

          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _verifier,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Vérifier', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
//  SHEET : RÉINITIALISATION DU PIN
// ══════════════════════════════════════════════════════════════
class _ResetPinSheet extends StatefulWidget {
  @override
  State<_ResetPinSheet> createState() => _ResetPinSheetState();
}

class _ResetPinSheetState extends State<_ResetPinSheet> {
  final _pinCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obsPin      = true;
  bool _obsConfirm  = true;
  bool _loading     = false;

  static const _green = Color(0xFF0F6E56);
  static const _grey  = Color(0xFFF4F4F2);
  static const _hint  = Color(0xFF9CA3AF);
  static const _text  = Color(0xFF1A1A1A);
  static const _red   = Color(0xFFA32D2D);

  Future<void> _enregistrer() async {
    if (_pinCtrl.text.length != 4) return;
    if (_pinCtrl.text != _confirmCtrl.text) return;
    setState(() => _loading = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pin', _pinCtrl.text);
    await prefs.setInt('erreurs_pin', 0);
    setState(() => _loading = false);
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Code PIN mis à jour !'),
      backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Nouveau code PIN',
            style: TextStyle(color: _text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Choisissez un nouveau code PIN à 4 chiffres.',
            style: TextStyle(color: _hint, fontSize: 13)),
          const SizedBox(height: 20),

          _pinField('Nouveau PIN', _pinCtrl, _obsPin, () => setState(() => _obsPin = !_obsPin)),
          const SizedBox(height: 12),
          _pinField('Confirmer le PIN', _confirmCtrl, _obsConfirm, () => setState(() => _obsConfirm = !_obsConfirm)),

          const SizedBox(height: 20),
          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _enregistrer,
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: _loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Enregistrer', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 12),
        ]),
      ),
    );
  }

  Widget _pinField(String label, TextEditingController ctrl, bool obs, VoidCallback toggle) {
    return TextFormField(
      controller: ctrl, obscureText: obs,
      keyboardType: TextInputType.number, maxLength: 4,
      style: const TextStyle(color: _text, fontSize: 15),
      decoration: InputDecoration(
        counterText: '', hintText: '• • • •',
        hintStyle: const TextStyle(color: _hint, fontSize: 14),
        labelText: label,
        labelStyle: const TextStyle(color: _hint, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _hint, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _hint, size: 20),
          onPressed: toggle),
        filled: true, fillColor: _grey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));
  }
}