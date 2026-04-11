import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:le_commercant/database/app_database.dart';
import 'dashbord.dart';

// ══════════════════════════════════════════════════════════════
//  REGISTER PAGE — Branchée sur AppDatabase
//
//  Actions DB :
//    • AppDatabase.inscrire()  → crée le compte dans SQLite
//    • AppDatabase.ouvrirSession() → crée la session active
//    • Redirige vers DashboardPage avec les données du compte
// ══════════════════════════════════════════════════════════════

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {

  final _formKey              = GlobalKey<FormState>();
  final _prenomCtrl           = TextEditingController();
  final _nomCtrl              = TextEditingController();
  final _telephoneCtrl        = TextEditingController();
  final _boutiqueCtrl         = TextEditingController();
  final _villeCtrl            = TextEditingController();
  final _pinCtrl              = TextEditingController();
  final _confirmPinCtrl       = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePin     = true;
  bool _obscureConfirm = true;
  int  _etape          = 0;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  final _db = AppDatabase.instance;

  // ── Palette
  static const _green      = Color(0xFF0F6E56);
  static const _greenDark  = Color(0xFF085041);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red        = Color(0xFFA32D2D);
  static const _amber      = Color(0xFF854F0B);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _border     = Color(0xFFE0E0E0);
  static const _hint       = Color(0xFF9CA3AF);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);

  final _titres  = ['Informations personnelles', 'Votre boutique', 'Code PIN'];
  final _subs    = ['Prénom, nom et téléphone', 'Nom et ville de la boutique', 'Votre code secret de connexion'];
  final _icons   = [Icons.person_rounded, Icons.storefront_rounded, Icons.lock_rounded];
  final _labels  = ['Infos', 'Boutique', 'PIN'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this,
        duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in [_prenomCtrl, _nomCtrl, _telephoneCtrl,
      _boutiqueCtrl, _villeCtrl, _pinCtrl, _confirmPinCtrl]) c.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Validateurs
  String? _req(String? v, String champ) =>
      (v == null || v.trim().isEmpty) ? '$champ requis' : null;

  String? _valTel(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    if (v.trim().length != 9)          return '9 chiffres requis';
    if (!v.trim().startsWith('7'))     return 'Commence par 7';
    return null;
  }

  String? _valPin(String? v) {
    if (v == null || v.isEmpty) return 'PIN requis';
    if (v.length != 4)          return '4 chiffres exactement';
    return null;
  }

  String? _valConfirm(String? v) {
    if (v == null || v.isEmpty)   return 'Confirmation requise';
    if (v != _pinCtrl.text)       return 'Les codes ne correspondent pas';
    return null;
  }

  bool _etapeValide() {
    switch (_etape) {
      case 0: return _prenomCtrl.text.trim().isNotEmpty &&
          _nomCtrl.text.trim().isNotEmpty &&
          _valTel(_telephoneCtrl.text) == null;
      case 1: return _boutiqueCtrl.text.trim().isNotEmpty &&
          _villeCtrl.text.trim().isNotEmpty;
      case 2: return _valPin(_pinCtrl.text) == null &&
          _valConfirm(_confirmPinCtrl.text) == null;
      default: return false;
    }
  }

  void _suivant() {
    if (!_etapeValide()) {
      _formKey.currentState!.validate();
      _toast('Remplissez tous les champs', err: true);
      return;
    }
    if (_etape < 2) {
      _animCtrl.reset();
      setState(() => _etape++);
      _animCtrl.forward();
    } else {
      _inscrire();
    }
  }

  void _precedent() {
    if (_etape > 0) {
      _animCtrl.reset();
      setState(() => _etape--);
      _animCtrl.forward();
    }
  }

  // ──────────────────────────────────────
  //  ACTION PRINCIPALE — écriture en DB
  // ──────────────────────────────────────
  Future<void> _inscrire() async {
    setState(() => _isLoading = true);

    try {
      // 1. Créer le compte dans SQLite
      final id = await _db.inscrire(
        prenom:      _prenomCtrl.text.trim(),
        nom:         _nomCtrl.text.trim(),
        telephone:   _telephoneCtrl.text.trim(),
        nomBoutique: _boutiqueCtrl.text.trim(),
        ville:       _villeCtrl.text.trim(),
        pin:         _pinCtrl.text,
      );

      if (id == null) {
        // Numéro déjà utilisé
        _toast('Ce numéro est déjà enregistré', err: true);
        setState(() => _isLoading = false);
        return;
      }

      // 2. Ouvrir une session active
      await _db.ouvrirSession(id);

      setState(() => _isLoading = false);
      if (!mounted) return;

      // 3. Naviguer vers le Dashboard avec les données fraîches
      Navigator.pushReplacement(context, PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          commercantId:  id,
          nomCommercant: '${_prenomCtrl.text.trim()} ${_nomCtrl.text.trim()}',
          nomBoutique:   _boutiqueCtrl.text.trim(),
          ville:         _villeCtrl.text.trim(),
        ),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ));

    } catch (e) {
      setState(() => _isLoading = false);
      _toast('Erreur : ${e.toString()}', err: true);
    }
  }

  // ══════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Column(children: [
        _buildHeader(),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(key: _formKey,
            child: FadeTransition(opacity: _fadeAnim,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SizedBox(height: 24),
                _buildEtapeHeader(),
                const SizedBox(height: 24),
                _buildContenu(),
                const SizedBox(height: 32),
              ]))))),
        _buildBoutons(),
      ])),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(children: [
        // Logo
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          const Text('Le Commerçant', style: TextStyle(
              color: _green, fontSize: 20, fontWeight: FontWeight.w800)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.fiber_new_rounded, color: _green, size: 14),
              SizedBox(width: 4),
              Text('Inscription', style: TextStyle(
                  color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
            ])),
        ]),
        const SizedBox(height: 22),

        // Stepper
        Row(children: List.generate(3, (i) {
          final actif = i == _etape;
          final fait  = i < _etape;
          return Expanded(child: Row(children: [
            if (i > 0)
              Expanded(child: Container(height: 2, color: fait ? _green : _greyMid)),
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: fait ? _green : actif ? _greenLight : _grey,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: actif || fait ? _green : _border,
                      width: actif ? 2 : 1)),
                child: Center(child: fait
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Icon(_icons[i], color: actif ? _green : _hint, size: 16))),
              const SizedBox(height: 4),
              Text(_labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  color: actif || fait ? _green : _hint)),
            ]),
            if (i < 2)
              Expanded(child: Container(height: 2,
                  color: i < _etape ? _green : _greyMid)),
          ]));
        })),
        const SizedBox(height: 16),
      ]));
  }

  Widget _buildEtapeHeader() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 30, height: 30,
        decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(8)),
        child: Icon(_icons[_etape], color: _green, size: 16)),
      const SizedBox(width: 10),
      Text('Étape ${_etape + 1}/3',
          style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 10),
    Text(_titres[_etape],
        style: const TextStyle(color: _text, fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(_subs[_etape], style: const TextStyle(color: _hint, fontSize: 13)),
  ]);

  Widget _buildContenu() {
    switch (_etape) {
      case 0: return _etape0();
      case 1: return _etape1();
      case 2: return _etape2();
      default: return const SizedBox();
    }
  }

  // ── Étape 0 : Identité
  Widget _etape0() => Column(children: [
    Row(children: [
      Expanded(child: _champ(_prenomCtrl, 'Prénom', Icons.person_outline_rounded,
          validator: (v) => _req(v, 'Prénom'))),
      const SizedBox(width: 12),
      Expanded(child: _champ(_nomCtrl, 'Nom', Icons.person_outline_rounded,
          validator: (v) => _req(v, 'Nom'))),
    ]),
    const SizedBox(height: 12),
    _champTelephone(),
    const SizedBox(height: 14),
    _infoBox(Icons.info_outline_rounded,
        'Votre numéro servira à vous identifier. Assurez-vous qu\'il est correct.',
        _amberLight, _amber, const Color(0xFFEF9F27)),
  ]);

  // ── Étape 1 : Boutique
  Widget _etape1() => Column(children: [
    _champ(_boutiqueCtrl, 'Nom de la boutique', Icons.storefront_outlined,
        label: 'Nom boutique', validator: (v) => _req(v, 'Nom boutique')),
    const SizedBox(height: 12),
    _champ(_villeCtrl, 'Ex: Touba, Dakar, Thiès...', Icons.location_on_outlined,
        label: 'Ville / Quartier', validator: (v) => _req(v, 'Ville')),
    const SizedBox(height: 18),
    // Aperçu carte
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
          SizedBox(width: 6),
          Text('Aperçu', style: TextStyle(color: Colors.white70, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        ValueListenableBuilder(valueListenable: _boutiqueCtrl, builder: (_, __, ___) =>
          Text(_boutiqueCtrl.text.isEmpty ? 'Nom de la boutique' : _boutiqueCtrl.text,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        ValueListenableBuilder(valueListenable: _villeCtrl, builder: (_, __, ___) =>
          Text([
            if (_prenomCtrl.text.isNotEmpty) '${_prenomCtrl.text} ${_nomCtrl.text}',
            if (_villeCtrl.text.isNotEmpty) _villeCtrl.text,
          ].join(' · '), style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ])),
  ]);

  // ── Étape 2 : PIN
  Widget _etape2() => Column(children: [
    Center(child: Container(width: 70, height: 70,
      decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
      child: const Icon(Icons.lock_rounded, color: _green, size: 32))),
    const SizedBox(height: 18),
    _champ(_pinCtrl, '• • • •', Icons.lock_outline_rounded,
      label: 'Code PIN (4 chiffres)',
      obscure: _obscurePin, maxLen: 4, type: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: _valPin,
      suffix: IconButton(
        icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _hint, size: 20),
        onPressed: () => setState(() => _obscurePin = !_obscurePin))),
    const SizedBox(height: 12),
    _champ(_confirmPinCtrl, '• • • •', Icons.lock_outline_rounded,
      label: 'Confirmer le code PIN',
      obscure: _obscureConfirm, maxLen: 4, type: TextInputType.number,
      formatters: [FilteringTextInputFormatter.digitsOnly],
      validator: _valConfirm,
      suffix: IconButton(
        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _hint, size: 20),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
    const SizedBox(height: 14),
    _infoBox(Icons.shield_outlined,
        'Votre code PIN protège votre compte. Ne le partagez jamais.',
        _greenLight, _greenDark, const Color(0xFF5DCAA5)),
  ]);

  Widget _buildBoutons() => Container(
    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
    decoration: const BoxDecoration(color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 0.5))),
    child: Row(children: [
      if (_etape > 0) ...[
        GestureDetector(onTap: _precedent,
          child: Container(width: 50, height: 54,
            decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border)),
            child: const Icon(Icons.arrow_back_rounded, color: _textMuted, size: 22))),
        const SizedBox(width: 12),
      ],
      Expanded(child: SizedBox(height: 54,
        child: _isLoading
          ? Container(decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
              child: const Center(child: SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))))
          : ElevatedButton(onPressed: _suivant,
              style: ElevatedButton.styleFrom(backgroundColor: _green,
                foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text(_etape < 2 ? 'Continuer' : "S'inscrire",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Icon(_etape < 2 ? Icons.arrow_forward_rounded : Icons.check_rounded, size: 20),
              ])))),
    ]));

  // ── Widgets utilitaires
  Widget _champTelephone() => Container(
    decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: const BoxDecoration(color: _greenLight,
          borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
        child: const Row(children: [
          Text('🇸🇳', style: TextStyle(fontSize: 18)),
          SizedBox(width: 6),
          Text('+221', style: TextStyle(color: _green, fontSize: 14, fontWeight: FontWeight.w700)),
        ])),
      Expanded(child: TextFormField(
        controller: _telephoneCtrl, keyboardType: TextInputType.phone,
        maxLength: 9, inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: _valTel,
        style: const TextStyle(color: _text, fontSize: 15),
        decoration: const InputDecoration(counterText: '', hintText: '77 000 00 00',
          hintStyle: TextStyle(color: _hint, fontSize: 14),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16)))),
    ]));

  Widget _champ(TextEditingController ctrl, String hint, IconData icon, {
    String? label, bool obscure = false, int? maxLen,
    TextInputType type = TextInputType.text,
    List<TextInputFormatter>? formatters,
    Widget? suffix, String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
            color: Color(0xFF374151))),
        const SizedBox(height: 6),
      ],
      TextFormField(controller: ctrl, obscureText: obscure,
        keyboardType: type, maxLength: maxLen, inputFormatters: formatters,
        validator: validator,
        style: const TextStyle(color: _text, fontSize: 15),
        decoration: InputDecoration(counterText: '', hintText: hint,
          hintStyle: const TextStyle(color: _hint, fontSize: 14),
          prefixIcon: Icon(icon, color: _hint, size: 20),
          suffixIcon: suffix, filled: true, fillColor: _grey,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _green, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1)),
          errorStyle: const TextStyle(color: _red, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    ]);
  }

  Widget _infoBox(IconData icon, String text, Color bg, Color tc, Color bc) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: bc, width: 0.5)),
      child: Row(children: [
        Icon(icon, color: tc, size: 18), const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: tc, fontSize: 12, height: 1.4))),
      ]));

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13)),
      backgroundColor: err ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}