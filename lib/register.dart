import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashbord.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey               = GlobalKey<FormState>();
  final _prenomController      = TextEditingController();
  final _nomController         = TextEditingController();
  final _telephoneController   = TextEditingController();
  final _boutiqueController    = TextEditingController();
  final _villeController       = TextEditingController();
  final _pinController         = TextEditingController();
  final _confirmPinController  = TextEditingController();

  bool _isLoading      = false;
  bool _obscurePin     = true;
  bool _obscureConfirm = true;
  int  _currentStep    = 0;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  static const _green      = Color(0xFF0F6E56);
  static const _greenDark  = Color(0xFF085041);
  static const _greenLight = Color(0xFFE1F5EE);
  static const _red        = Color(0xFFA32D2D);
  static const _amber      = Color(0xFF854F0B);
  static const _amberLight = Color(0xFFFAEEDA);
  static const _amberMid   = Color(0xFFFAC775);
  static const _grey       = Color(0xFFF4F4F2);
  static const _greyMid    = Color(0xFFE8E8E5);
  static const _border     = Color(0xFFE0E0E0);
  static const _hint       = Color(0xFF9CA3AF);
  static const _text       = Color(0xFF1A1A1A);
  static const _textMuted  = Color(0xFF6B7280);

  final _stepTitles = ['Informations personnelles','Votre boutique','Sécurité'];
  final _stepSubs   = ['Prénom, nom et téléphone','Nom et ville de la boutique','Votre code PIN de connexion'];
  final _stepIcons  = [Icons.person_rounded, Icons.storefront_rounded, Icons.lock_rounded];
  final _stepLbls   = ['Infos','Boutique','Sécurité'];

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
  }

  @override
  void dispose() {
    for (final c in [_prenomController, _nomController, _telephoneController,
      _boutiqueController, _villeController, _pinController, _confirmPinController]) c.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  String? _requis(String? v, String champ) =>
      (v == null || v.trim().isEmpty) ? '$champ requis' : null;

  String? _valPhone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Numéro requis';
    if (v.trim().length != 9)          return '9 chiffres requis';
    if (!v.trim().startsWith('7'))     return 'Commence par 7';
    return null;
  }

  String? _valPin(String? v) {
    if (v == null || v.isEmpty) return 'Code PIN requis';
    if (v.length != 4)          return '4 chiffres exactement';
    return null;
  }

  String? _valConfirm(String? v) {
    if (v == null || v.isEmpty)   return 'Confirmation requise';
    if (v != _pinController.text) return 'Les codes ne correspondent pas';
    return null;
  }

  bool _stepOk(int s) {
    switch (s) {
      case 0: return _prenomController.text.trim().isNotEmpty &&
          _nomController.text.trim().isNotEmpty &&
          _valPhone(_telephoneController.text) == null;
      case 1: return _boutiqueController.text.trim().isNotEmpty &&
          _villeController.text.trim().isNotEmpty;
      case 2: return _valPin(_pinController.text) == null &&
          _valConfirm(_confirmPinController.text) == null;
      default: return false;
    }
  }

  void _next() {
    if (!_stepOk(_currentStep)) {
      _formKey.currentState!.validate();
      _toast('Veuillez remplir tous les champs', err: true);
      return;
    }
    if (_currentStep < 2) {
      _animCtrl.reset();
      setState(() => _currentStep++);
      _animCtrl.forward();
    } else {
      _inscrire();
    }
  }

  void _prev() {
    if (_currentStep > 0) {
      _animCtrl.reset();
      setState(() => _currentStep--);
      _animCtrl.forward();
    }
  }

  void _toast(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(err ? Icons.warning_rounded : Icons.check_circle_rounded,
            color: Colors.white, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
      ]),
      backgroundColor: err ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _inscrire() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));

    // ── Persistance locale
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_registered', true);
    await prefs.setBool('is_logged_in',  true);   // connecté juste après inscription
    await prefs.setString('nom_commercant',
        '${_prenomController.text.trim()} ${_nomController.text.trim()}');
    await prefs.setString('nom_boutique', _boutiqueController.text.trim());
    await prefs.setString('ville',        _villeController.text.trim());
    await prefs.setString('telephone',    _telephoneController.text.trim());
    await prefs.setString('pin',          _pinController.text);
    // ──────────────────────────────────────

    setState(() => _isLoading = false);
    if (!mounted) return;

    Navigator.pushReplacement(context, PageRouteBuilder(
      pageBuilder: (_, __, ___) => DashboardPage(
        nomCommercant: prefs.getString('nom_commercant') ?? '',
        nomBoutique:   prefs.getString('nom_boutique')   ?? '',
        ville:         prefs.getString('ville')          ?? '',
      ),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
      transitionDuration: const Duration(milliseconds: 500),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: FadeTransition(opacity: _fadeAnim,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 28),
                  _buildStepHeader(),
                  const SizedBox(height: 28),
                  _buildStepContent(),
                  const SizedBox(height: 32),
                ])),
            ),
          )),
          _buildNavButtons(),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(children: [
        Row(children: [
          Container(width: 40, height: 40,
            decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22)),
          const SizedBox(width: 10),
          const Text('Le Commerçant', style: TextStyle(
            color: _green, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(20)),
            child: const Row(children: [
              Icon(Icons.fiber_new_rounded, color: _green, size: 14),
              SizedBox(width: 4),
              Text('Inscription', style: TextStyle(color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 24),
        Row(children: List.generate(3, (i) {
          final active = i == _currentStep;
          final done   = i < _currentStep;
          return Expanded(child: Row(children: [
            if (i > 0) Expanded(child: Container(height: 2, color: done ? _green : _greyMid)),
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: done ? _green : active ? _greenLight : _grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: active || done ? _green : _border, width: active ? 2 : 1)),
                child: Center(child: done
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 18)
                  : Icon(_stepIcons[i], color: active ? _green : _hint, size: 16))),
              const SizedBox(height: 4),
              Text(_stepLbls[i], style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: active || done ? _green : _hint)),
            ]),
            if (i < 2) Expanded(child: Container(height: 2, color: i < _currentStep ? _green : _greyMid)),
          ]));
        })),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _buildStepHeader() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Container(width: 32, height: 32,
        decoration: BoxDecoration(color: _greenLight, borderRadius: BorderRadius.circular(8)),
        child: Icon(_stepIcons[_currentStep], color: _green, size: 18)),
      const SizedBox(width: 10),
      Text('Étape ${_currentStep + 1}/3',
        style: const TextStyle(color: _green, fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
    const SizedBox(height: 12),
    Text(_stepTitles[_currentStep],
      style: const TextStyle(color: _text, fontSize: 24, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(_stepSubs[_currentStep], style: const TextStyle(color: _hint, fontSize: 14)),
  ]);

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0: return _step0();
      case 1: return _step1();
      case 2: return _step2();
      default: return const SizedBox();
    }
  }

  Widget _step0() => Column(children: [
    Row(children: [
      Expanded(child: _Field(controller: _prenomController, hint: 'Prénom',
        icon: Icons.person_outline_rounded, validator: (v) => _requis(v, 'Prénom'),
        textInputAction: TextInputAction.next)),
      const SizedBox(width: 14),
      Expanded(child: _Field(controller: _nomController, hint: 'Nom',
        icon: Icons.person_outline_rounded, validator: (v) => _requis(v, 'Nom'),
        textInputAction: TextInputAction.next)),
    ]),
    const SizedBox(height: 14),
    Container(
      decoration: BoxDecoration(color: _grey, borderRadius: BorderRadius.circular(14)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          decoration: const BoxDecoration(color: _greenLight,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(14), bottomLeft: Radius.circular(14))),
          child: const Row(children: [
            Text('🇸🇳', style: TextStyle(fontSize: 18)),
            SizedBox(width: 6),
            Text('+221', style: TextStyle(color: _green, fontSize: 14, fontWeight: FontWeight.w700)),
          ])),
        Expanded(child: TextFormField(
          controller: _telephoneController,
          keyboardType: TextInputType.phone,
          maxLength: 9,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _valPhone,
          textInputAction: TextInputAction.next,
          style: const TextStyle(color: _text, fontSize: 15),
          decoration: const InputDecoration(
            counterText: '', hintText: '77 000 00 00',
            hintStyle: TextStyle(color: _hint, fontSize: 14),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 16)))),
      ])),
    const SizedBox(height: 16),
    _infoBox(Icons.info_outline_rounded,
      'Votre numéro servira à vous identifier. Assurez-vous qu\'il est correct.',
      _amberLight, _amber, const Color(0xFFEF9F27)),
  ]);

  Widget _step1() => Column(children: [
    _Field(controller: _boutiqueController, hint: 'Ex: Boutique Al Amine',
      label: 'Nom de la boutique', icon: Icons.storefront_outlined,
      validator: (v) => _requis(v, 'Nom boutique'), textInputAction: TextInputAction.next),
    const SizedBox(height: 14),
    _Field(controller: _villeController, hint: 'Ex: Touba, Dakar, Thiès...',
      label: 'Ville / Quartier', icon: Icons.location_on_outlined,
      validator: (v) => _requis(v, 'Ville'), textInputAction: TextInputAction.done),
    const SizedBox(height: 20),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.storefront_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('Aperçu de votre profil',
            style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ValueListenableBuilder(valueListenable: _boutiqueController, builder: (_, __, ___) =>
          Text(_boutiqueController.text.trim().isEmpty ? 'Nom de la boutique' : _boutiqueController.text.trim(),
            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800))),
        const SizedBox(height: 4),
        ValueListenableBuilder(valueListenable: _villeController, builder: (_, __, ___) =>
          Text([
            if (_prenomController.text.trim().isNotEmpty)
              '${_prenomController.text.trim()} ${_nomController.text.trim()}',
            if (_villeController.text.trim().isNotEmpty) _villeController.text.trim(),
          ].join(' · '), style: const TextStyle(color: Colors.white70, fontSize: 13))),
      ])),
  ]);

  Widget _step2() => Column(children: [
    Center(child: Container(width: 72, height: 72,
      decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle),
      child: const Icon(Icons.lock_rounded, color: _green, size: 34))),
    const SizedBox(height: 20),
    _Field(controller: _pinController, hint: '• • • •',
      label: 'Code PIN (4 chiffres)', icon: Icons.lock_outline_rounded,
      obscureText: _obscurePin, maxLength: 4, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: _valPin,
      suffixIcon: IconButton(
        icon: Icon(_obscurePin ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _hint, size: 20),
        onPressed: () => setState(() => _obscurePin = !_obscurePin)),
      textInputAction: TextInputAction.next),
    const SizedBox(height: 14),
    _Field(controller: _confirmPinController, hint: '• • • •',
      label: 'Confirmer le code PIN', icon: Icons.lock_outline_rounded,
      obscureText: _obscureConfirm, maxLength: 4, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: _valConfirm,
      suffixIcon: IconButton(
        icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: _hint, size: 20),
        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)),
      textInputAction: TextInputAction.done),
    const SizedBox(height: 16),
    _infoBox(Icons.shield_outlined,
      'Votre code PIN protège votre compte. Ne le partagez avec personne.',
      _greenLight, _greenDark, const Color(0xFF5DCAA5)),
  ]);

  Widget _infoBox(IconData icon, String text, Color bg, Color tc, Color bc) =>
    Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bc, width: 0.5)),
      child: Row(children: [
        Icon(icon, color: tc, size: 18), const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(color: tc, fontSize: 12, height: 1.4))),
      ]));

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 0.5))),
      child: Row(children: [
        if (_currentStep > 0) ...[
          GestureDetector(onTap: _prev,
            child: Container(width: 50, height: 54,
              decoration: BoxDecoration(color: _grey,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border)),
              child: const Icon(Icons.arrow_back_rounded, color: _textMuted, size: 22))),
          const SizedBox(width: 12),
        ],
        Expanded(child: SizedBox(height: 54,
          child: _isLoading
            ? Container(
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(14)),
                child: const Center(child: SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))))
            : ElevatedButton(onPressed: _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(_currentStep < 2 ? 'Continuer' : "S'inscrire",
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 8),
                  Icon(_currentStep < 2 ? Icons.arrow_forward_rounded : Icons.check_rounded, size: 20),
                ])))),
      ]),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? label;
  final IconData icon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final TextInputAction? textInputAction;

  static const _green = Color(0xFF0F6E56);
  static const _grey  = Color(0xFFF4F4F2);
  static const _hint  = Color(0xFF9CA3AF);
  static const _text  = Color(0xFF1A1A1A);
  static const _red   = Color(0xFFA32D2D);

  const _Field({
    required this.controller, required this.hint, required this.icon,
    this.label, this.obscureText = false, this.keyboardType = TextInputType.text,
    this.maxLength, this.inputFormatters, this.suffixIcon, this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (label != null) ...[
        Text(label!, style: const TextStyle(
          color: Color(0xFF374151), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
      ],
      TextFormField(
        controller: controller, obscureText: obscureText,
        keyboardType: keyboardType, maxLength: maxLength,
        inputFormatters: inputFormatters, textInputAction: textInputAction,
        validator: validator,
        style: const TextStyle(color: _text, fontSize: 15),
        decoration: InputDecoration(
          counterText: '', hintText: hint,
          hintStyle: const TextStyle(color: _hint, fontSize: 14),
          prefixIcon: Icon(icon, color: _hint, size: 20),
          suffixIcon: suffixIcon, filled: true, fillColor: _grey,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _green, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _red, width: 1.5)),
          errorStyle: const TextStyle(color: _red, fontSize: 11),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
    ]);
  }
}