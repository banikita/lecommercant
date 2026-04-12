import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:le_commercant/database/app_database.dart';
import 'dashbord.dart';

// ══════════════════════════════════════════════════════════════
//  LOGIN PAGE — Style Wave (PIN screen)
//  Logo : remplacez le widget _buildLogo() par votre propre logo
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
    with TickerProviderStateMixin {

  // ── Couleurs Wave (bleu clair)
  static const _waveBlueFill  = Color(0xFF90CAF9); // point rempli
  static const _waveBlueEmpty = Color(0xFFBBDEFB); // point vide
  static const _waveBlue      = Color(0xFF1E88E5); // liens + textes
  static const _deleteColor   = Color(0xFF424242); // bouton effacer
  static const _keyColor      = Color(0xFF212121); // chiffres
  static const _subText       = Color(0xFF757575); // sous-titre
  static const _red           = Color(0xFFE53935); // erreur
  static const _green         = Color(0xFF0F6E56); // succès

  static const int _pinLength     = 4;
  static const int _maxTentatives = 5;

  String _pin       = '';
  int    _erreurs   = 0;
  bool   _checking  = false;
  bool   _shaking   = false;

  final _db = AppDatabase.instance;

  late AnimationController _shakeCtrl;
  late Animation<double>   _shakeAnim;
  late AnimationController _dotCtrl;
  late Animation<double>   _dotAnim;

  @override
  void initState() {
    super.initState();

    // Animation secousse (erreur PIN)
    _shakeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 480));
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0),  weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0),   weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0),    weight: 1),
    ]).animate(_shakeCtrl);

    // Animation point (remplissage)
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

  // ══════════════════════════════════════
  //  LOGIQUE PIN
  // ══════════════════════════════════════

  void _onKey(String key) {
    if (_checking || _pin.length >= _pinLength) return;

    HapticFeedback.lightImpact(); // vibration tactile

    _dotCtrl.reset();
    _dotCtrl.forward();

    setState(() => _pin += key);

    if (_pin.length == _pinLength) {
      Future.delayed(const Duration(milliseconds: 120), _verifier);
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _verifier() async {
    setState(() => _checking = true);

    final correct = await _db.verifierPin(widget.commercantId, _pin);

    if (correct) {
      // ── Succès
      await _db.reinitialiserTentatives(widget.commercantId);
      await _db.ouvrirSession(widget.commercantId);
      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => DashboardPage(
            commercantId:  widget.commercantId,
            nomCommercant: widget.nomCommercant,
            nomBoutique:   widget.nomBoutique,
            ville:         widget.ville,
          ),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    } else {
      // ── Erreur
      HapticFeedback.heavyImpact();
      final tentatives = await _db.incrementerTentatives(widget.commercantId);

      _shakeCtrl.reset();
      _shakeCtrl.forward();

      setState(() {
        _erreurs  = tentatives;
        _shaking  = true;
        _checking = false;
        _pin      = '';
      });

      Future.delayed(const Duration(milliseconds: 480),
          () { if (mounted) setState(() => _shaking = false); });

      if (tentatives >= _maxTentatives) _dialogBlocage();
    }
  }

  void _dialogBlocage() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Compte bloqué',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
        content: const Text(
            'Trop de tentatives incorrectes.\nVérifiez votre numéro pour réinitialiser votre PIN.',
            style: TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); _sheetOubliPin(); },
            child: const Text('Réinitialiser',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }

  // ── Oublié PIN : vérifier le numéro en DB
  void _sheetOubliPin() {
    final telCtrl = TextEditingController();
    bool erreur = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),

              const Text('Votre numéro de téléphone',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Entrez le numéro lié à votre compte pour réinitialiser votre PIN.',
                  style: TextStyle(color: Color(0xFF757575), fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),

              // Champ téléphone
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
                    child: const Row(children: [
                      Text('🇸🇳', style: TextStyle(fontSize: 18)),
                      SizedBox(width: 6),
                      Text('+221', style: TextStyle(
                          color: _waveBlue, fontSize: 14, fontWeight: FontWeight.w700)),
                    ])),
                  Expanded(child: TextField(
                    controller: telCtrl,
                    keyboardType: TextInputType.phone, maxLength: 9,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 16),
                    decoration: const InputDecoration(
                      counterText: '', border: InputBorder.none,
                      hintText: '77 000 00 00',
                      hintStyle: TextStyle(color: Color(0xFFBDBDBD)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16)))),
                ])),

              if (erreur) ...[
                const SizedBox(height: 8),
                const Text('❌  Numéro non reconnu. Réessayez.',
                    style: TextStyle(color: _red, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    final commercant = await _db.chargerCommercant();
                    if (commercant == null) return;
                    if (telCtrl.text.trim() == commercant['telephone']) {
                      Navigator.pop(context);
                      _sheetNouveauPin();
                    } else {
                      setBS(() => erreur = true);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _waveBlue, foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14))),
                  child: const Text('Vérifier',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Saisir nouveau PIN
  void _sheetNouveauPin() {
    final pinCtrl  = TextEditingController();
    final confCtrl = TextEditingController();
    bool obs1 = true, obs2 = true, loading = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setBS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)))),

              const Text('Nouveau code PIN',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700)),
              const SizedBox(height: 18),

              _pinField(pinCtrl,  'Nouveau PIN (4 chiffres)', obs1,
                  () => setBS(() => obs1 = !obs1)),
              const SizedBox(height: 12),
              _pinField(confCtrl, 'Confirmer le PIN', obs2,
                  () => setBS(() => obs2 = !obs2)),
              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 54,
                child: ElevatedButton(
                  onPressed: loading ? null : () async {
                    if (pinCtrl.text.length != 4 || pinCtrl.text != confCtrl.text) return;
                    setBS(() => loading = true);
                    await _db.mettreAJourPin(widget.commercantId, pinCtrl.text);
                    setState(() => _erreurs = 0);
                    setBS(() => loading = false);
                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('✅  Code PIN mis à jour !'),
                      backgroundColor: _green,
                      behavior: SnackBarBehavior.floating));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _waveBlue, foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Enregistrer',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _pinField(TextEditingController ctrl, String hint, bool obs, VoidCallback toggle) =>
    TextField(controller: ctrl, obscureText: obs,
      keyboardType: TextInputType.number, maxLength: 4,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(counterText: '', hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 14),
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFBDBDBD), size: 20),
        suffixIcon: IconButton(
          icon: Icon(obs ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: const Color(0xFFBDBDBD), size: 20), onPressed: toggle),
        filled: true, fillColor: const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _waveBlue, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14)));

  // ══════════════════════════════════════
  //  BUILD — Layout style Wave
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [

            // ── Espace haut flexible (comme Wave)
            const Spacer(flex: 2),

            // ── LOGO (remplacez _buildLogo() par votre logo)
            _buildLogo(),

            // ── Espace entre logo et points
            const Spacer(flex: 2),

            // ── Points PIN avec animation secousse
            AnimatedBuilder(
              animation: _shakeAnim,
              builder: (_, child) => Transform.translate(
                offset: Offset(_shaking ? _shakeAnim.value : 0, 0),
                child: child),
              child: _buildDots(),
            ),

            // ── Message erreur (visible seulement si erreurs)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              child: _erreurs > 0
                ? Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Text(
                      _erreurs >= _maxTentatives - 1
                          ? '⚠️  Dernière tentative'
                          : 'Code incorrect · $_erreurs/${_maxTentatives}',
                      style: const TextStyle(
                          color: _red, fontSize: 13, fontWeight: FontWeight.w600)))
                : const SizedBox(height: 0)),

            // ── Espace entre points et clavier
            const Spacer(flex: 2),

            // ── CLAVIER NUMÉRIQUE
            _buildKeyboard(),

            // ── Lien "Oublié votre code secret ?"
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _sheetOubliPin,
              child: const Text(
                'Oublié votre code secret?',
                style: TextStyle(
                  color: _waveBlue,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════
  //  LOGO — Remplacez ce widget par votre propre logo
  // ══════════════════════════════════════
  Widget _buildLogo() {
    return Column(children: [
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // OPTION 1 — Logo depuis les assets (recommandé)
      // Décommentez et adaptez le chemin :
      //
      // Image.asset(
      //   'assets/images/logo.png',
      //   width: 120,
      //   height: 120,
      //   fit: BoxFit.contain,
      // ),
      //
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      // OPTION 2 — Icône avec nom (par défaut tant que le logo n'est pas ajouté)
      Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: const Color(0xFFE1F5EE),
          borderRadius: BorderRadius.circular(28),
        ),
        child: const Center(
          child: Icon(Icons.storefront_rounded,
              color: Color(0xFF0F6E56), size: 58)),
      ),
      const SizedBox(height: 14),
      const Text(
        'Le Commerçant',
        style: TextStyle(
          color: Color(0xFF0F6E56),
          fontSize: 18,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.3,
        ),
      ),
      // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ]);
  }

  // ══════════════════════════════════════
  //  POINTS PIN — style Wave (bleu clair)
  // ══════════════════════════════════════
  Widget _buildDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pinLength, (i) {
        final filled = i < _pin.length;
        final isLast = i == _pin.length - 1 && filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 14),
          width: filled ? 16 : 14,
          height: filled ? 16 : 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _shaking
                ? _red
                : filled
                    ? _waveBlueFill
                    : _waveBlueEmpty,
          ),
        );
      }),
    );
  }

  // ══════════════════════════════════════
  //  CLAVIER — style Wave (grand, espacé)
  // ══════════════════════════════════════
  Widget _buildKeyboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(children: [
        _keyRow(['1', '2', '3']),
        const SizedBox(height: 4),
        _keyRow(['4', '5', '6']),
        const SizedBox(height: 4),
        _keyRow(['7', '8', '9']),
        const SizedBox(height: 4),
        _bottomRow(),
      ]),
    );
  }

  Widget _keyRow(List<String> keys) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: keys.map(_buildKey).toList());

  Widget _bottomRow() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      // Espace vide à gauche (comme Wave)
      const SizedBox(width: 88, height: 88),
      _buildKey('0'),
      _buildDeleteKey(),
    ]);

  Widget _buildKey(String val) {
    return GestureDetector(
      onTap: () => _onKey(val),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Center(
          child: Text(
            val,
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w400,
              color: _keyColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteKey() {
    return GestureDetector(
      onTap: _onDelete,
      onLongPress: () => setState(() => _pin = ''), // Maintenir = tout effacer
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 88,
        height: 88,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.backspace_outlined,
                size: 26, color: _deleteColor),
          ),
        ),
      ),
    );
  }
}