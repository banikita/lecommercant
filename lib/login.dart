import 'package:flutter/material.dart';
import 'package:le_commercant/database/app_database.dart';
import 'dashbord.dart';
import 'register.dart';

// ══════════════════════════════════════════════════════════════
//  LOGIN PAGE (PIN) — Branchée sur AppDatabase
//
//  Actions DB :
//    • AppDatabase.verifierPin()          → compare le PIN hashé
//    • AppDatabase.incrementerTentatives() → compte les erreurs
//    • AppDatabase.reinitialiserTentatives() → remet à 0 au succès
//    • AppDatabase.ouvrirSession()        → crée la session active
//    • AppDatabase.mettreAJourPin()       → réinitialisation PIN
// ══════════════════════════════════════════════════════════════

class LoginPage extends StatefulWidget {
  final int    commercantId;
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
  static const _amberMid   = Color(0xFFFAC775);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);
  static const _pinLength  = 4;
  static const _maxTentatives = 5;

  String _pin        = '';
  int    _erreurs    = 0;
  bool   _verifie    = false;
  bool   _secoue     = false;

  final _db = AppDatabase.instance;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;

  String get _initiales {
    final p = widget.nomCommercant.trim().split(' ');
    return p.length >= 2
        ? '${p[0][0]}${p[1][0]}'.toUpperCase()
        : widget.nomCommercant.substring(0, 2).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 500));
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _onTouche(String key) {
    if (_verifie || _pin.length >= _pinLength) return;
    setState(() => _pin += key);
    if (_pin.length == _pinLength) _verifierPin();
  }

  void _effacer() {
    if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  // ──────────────────────────────────────
  //  VÉRIFICATION PIN — lecture DB
  // ──────────────────────────────────────
  Future<void> _verifierPin() async {
    setState(() => _verifie = true);

    // Vérification en DB (PIN hashé)
    final correct = await _db.verifierPin(widget.commercantId, _pin);

    if (correct) {
      // ── Succès : ouvrir la session + naviguer
      await _db.reinitialiserTentatives(widget.commercantId);
      await _db.ouvrirSession(widget.commercantId);

      if (!mounted) return;
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          commercantId:  widget.commercantId,
          nomCommercant: widget.nomCommercant,
          nomBoutique:   widget.nomBoutique,
          ville:         widget.ville,
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 450),
      ));

    } else {
      // ── Erreur : incrémenter en DB + animer
      final tentatives = await _db.incrementerTentatives(widget.commercantId);

      setState(() {
        _erreurs = tentatives;
        _verifie = false;
        _secoue  = true;
        _pin     = '';
      });
      _shakeCtrl.reset();
      _shakeCtrl.forward();
      Future.delayed(const Duration(milliseconds: 800),
          () { if (mounted) setState(() => _secoue = false); });

      // Bloquer après 5 tentatives
      if (tentatives >= _maxTentatives) _afficherBlocage();
    }
  }

  void _afficherBlocage() {
    showDialog(context: context, barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(children: [
          Icon(Icons.lock_person_rounded, color: _red, size: 22),
          SizedBox(width: 10),
          Text('Compte bloqué', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ]),
        content: const Text(
            '5 tentatives incorrectes.\nVérifiez votre numéro de téléphone pour réinitialiser votre PIN.',
            style: TextStyle(fontSize: 13, height: 1.5)),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); _ouvrirResetPin(); },
            child: const Text('Réinitialiser', style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ]));
  }

  // ── Oublié PIN : vérifier le téléphone en DB
  void _ouvrirOubliPin() {
    final telCtrl = TextEditingController();
    bool erreur = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setBS) => Container(
        margin: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Vérification du numéro',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 6),
          const Text('Entrez le numéro associé à votre compte.',
              style: TextStyle(color: _textMuted, fontSize: 13)),
          const SizedBox(height: 18),

          // Champ téléphone
          Container(
            decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: const BoxDecoration(color: _greenLight,
                  borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
                child: const Row(children: [
                  Text('🇸🇳', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 4),
                  Text('+221', style: TextStyle(color: _green, fontSize: 13, fontWeight: FontWeight.w700)),
                ])),
              Expanded(child: TextField(controller: telCtrl,
                keyboardType: TextInputType.phone, maxLength: 9,
                style: const TextStyle(fontSize: 14, color: _text),
                decoration: const InputDecoration(counterText: '',
                  hintText: '77 000 00 00',
                  hintStyle: TextStyle(color: _textMuted, fontSize: 13),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14)))),
            ])),

          if (erreur) ...[
            const SizedBox(height: 8),
            const Text('❌ Numéro non reconnu.',
                style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 18),

          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () async {
                // Vérifier le numéro en DB
                final commercant = await _db.chargerCommercant();
                if (commercant == null) return;
                if (telCtrl.text.trim() == commercant['telephone']) {
                  Navigator.pop(context);
                  _ouvrirResetPin();
                } else {
                  setBS(() => erreur = true);
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Vérifier',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 8),
        ]))));
  }

  // ── Réinitialiser PIN : écriture en DB
  void _ouvrirResetPin() {
    final pinCtrl     = TextEditingController();
    final confirmCtrl = TextEditingController();
    bool obsPin = true, obsConfirm = true, loading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(builder: (ctx, setBS) => Container(
        margin: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Nouveau code PIN',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: _text)),
          const SizedBox(height: 18),

          _resetField(pinCtrl, 'Nouveau PIN', obsPin, () => setBS(() => obsPin = !obsPin)),
          const SizedBox(height: 12),
          _resetField(confirmCtrl, 'Confirmer le PIN', obsConfirm, () => setBS(() => obsConfirm = !obsConfirm)),
          const SizedBox(height: 18),

          SizedBox(width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: loading ? null : () async {
                if (pinCtrl.text.length != 4) return;
                if (pinCtrl.text != confirmCtrl.text) return;
                setBS(() => loading = true);
                // Mettre à jour le PIN en DB (hashé automatiquement)
                await _db.mettreAJourPin(widget.commercantId, pinCtrl.text);
                setBS(() => loading = false);
                if (!mounted) return;
                Navigator.pop(context);
                _toast('✅ Code PIN mis à jour !');
              },
              style: ElevatedButton.styleFrom(backgroundColor: _green,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: loading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Enregistrer',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)))),
          const SizedBox(height: 8),
        ]))));
  }

  Widget _resetField(TextEditingController ctrl, String label, bool obs, VoidCallback toggle) =>
    TextField(controller: ctrl, obscureText: obs,
      keyboardType: TextInputType.number, maxLength: 4,
      style: const TextStyle(fontSize: 15, color: _text),
      decoration: InputDecoration(counterText: '',
        labelText: label, labelStyle: const TextStyle(color: _textMuted, fontSize: 13),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: _textMuted, size: 20),
        suffixIcon: IconButton(
          icon: Icon(obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: _textMuted, size: 20), onPressed: toggle),
        filled: true, fillColor: _grey,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _green, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        const SizedBox(height: 36),

        // Logo
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          const Text('Le Commerçant', style: TextStyle(
              color: _green, fontSize: 20, fontWeight: FontWeight.w800)),
        ]),

        const SizedBox(height: 32),

        // Avatar
        Container(width: 70, height: 70,
          decoration: BoxDecoration(color: _amberMid, shape: BoxShape.circle,
              border: Border.all(color: _greenLight, width: 3)),
          child: Center(child: Text(_initiales,
              style: const TextStyle(color: Color(0xFF633806), fontSize: 24, fontWeight: FontWeight.w800)))),
        const SizedBox(height: 10),
        Text('Bonjour, ${widget.nomCommercant}',
            style: const TextStyle(color: _text, fontSize: 17, fontWeight: FontWeight.w800)),
        Text(widget.nomBoutique,
            style: const TextStyle(color: _textMuted, fontSize: 13)),
        const SizedBox(height: 6),
        const Text('Entrez votre code PIN',
            style: TextStyle(color: _textMuted, fontSize: 14)),

        const SizedBox(height: 28),

        // Points PIN avec animation secousse
        AnimatedBuilder(
          animation: _shakeAnim,
          builder: (_, child) => Transform.translate(
            offset: Offset(_secoue
                ? 10 * (0.5 - (_shakeAnim.value - 0.5).abs()) * 2 : 0, 0),
            child: child),
          child: Row(mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pinLength, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 10),
              width: 16, height: 16,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _secoue ? _red : i < _pin.length ? _greenDot : _greenEmpty,
                border: i < _pin.length ? null
                    : Border.all(color: _greyMid, width: 1.5))))),
        ),

        // Message d'erreur
        AnimatedOpacity(
          opacity: _erreurs > 0 ? 1 : 0,
          duration: const Duration(milliseconds: 300),
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(color: _redLight, borderRadius: BorderRadius.circular(20)),
              child: Text(
                _erreurs >= _maxTentatives - 1
                    ? '⚠️  Dernière tentative avant blocage'
                    : 'Code incorrect · $_erreurs essai${_erreurs > 1 ? 's' : ''}',
                style: const TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w700))))),

        const SizedBox(height: 28),

        // Clavier numérique
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48),
          child: Column(children: [
            _ligne(['1','2','3']),
            const SizedBox(height: 10),
            _ligne(['4','5','6']),
            const SizedBox(height: 10),
            _ligne(['7','8','9']),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              const SizedBox(width: 78, height: 78),
              _touche('0'),
              _toucheEffacer(),
            ]),
          ])),

        const Spacer(),

        // Lien PIN oublié
        GestureDetector(
          onTap: _ouvrirOubliPin,
          child: const Padding(
            padding: EdgeInsets.only(bottom: 32),
            child: Text('Oublié votre code PIN ?', style: TextStyle(
              color: _green, fontSize: 14, fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline, decorationColor: _green)))),
      ])),
    );
  }

  Widget _ligne(List<String> keys) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: keys.map(_touche).toList());

  Widget _touche(String val) => GestureDetector(
    onTap: () => _onTouche(val),
    child: Container(width: 78, height: 78,
      decoration: const BoxDecoration(color: _grey, shape: BoxShape.circle),
      child: Center(child: Text(val, style: const TextStyle(
          fontSize: 26, fontWeight: FontWeight.w500, color: _text)))));

  Widget _toucheEffacer() => GestureDetector(
    onTap: _effacer,
    child: Container(width: 78, height: 78,
      child: const Center(child: Icon(Icons.backspace_outlined, size: 26, color: _textMuted))));

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }
}