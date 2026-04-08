import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dashbord.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _prenomController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _boutiqueController = TextEditingController();
  final _villeController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirmPin = true;
  int _currentStep = 0; // Étape actuelle (0 = infos perso, 1 = boutique, 2 = sécurité)

  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Palette de couleurs
  static const Color _green = Color(0xFF0F6E56);
  static const Color _greenDark = Color(0xFF085041);
  static const Color _greenLight = Color(0xFFE1F5EE);
  static const Color _red = Color(0xFFA32D2D);
  static const Color _amber = Color(0xFF854F0B);
  static const Color _amberLight = Color(0xFFFAEEDA);
  static const Color _grey = Color(0xFFF4F4F2);
  static const Color _greyMid = Color(0xFFE8E8E5);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _hint = Color(0xFF9CA3AF);
  static const Color _text = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF6B7280);

  final List<String> _stepTitles = [
    'Informations personnelles',
    'Votre boutique',
    'Sécurité',
  ];

  final List<String> _stepSubtitles = [
    'Prénom, nom et téléphone',
    'Nom et ville de la boutique',
    'Code PIN de connexion',
  ];

  final List<IconData> _stepIcons = [
    Icons.person_rounded,
    Icons.storefront_rounded,
    Icons.lock_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _prenomController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    _boutiqueController.dispose();
    _villeController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    _animController.dispose();
    super.dispose();
  }

  // ── Validateurs
  String? _validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Numéro requis';
    if (value.trim().length != 9) return '9 chiffres requis';
    if (!value.trim().startsWith('7')) return 'Commence par 7 (ex: 77xxx xx xx)';
    return null;
  }

  String? _validatePin(String? value) {
    if (value == null || value.isEmpty) return 'Code PIN requis';
    if (value.length != 4) return '4 chiffres exactement';
    return null;
  }

  String? _validateConfirmPin(String? value) {
    if (value == null || value.isEmpty) return 'Confirmation requise';
    if (value != _pinController.text) return 'Les codes ne correspondent pas';
    return null;
  }

  String? _validateNotEmpty(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) return '$fieldName requis';
    return null;
  }

  // ── Validation par étape
  bool _validateStep(int step) {
    switch (step) {
      case 0:
        return _prenomController.text.trim().isNotEmpty &&
            _nomController.text.trim().isNotEmpty &&
            _validatePhone(_telephoneController.text) == null;
      case 1:
        return _boutiqueController.text.trim().isNotEmpty &&
            _villeController.text.trim().isNotEmpty;
      case 2:
        return _validatePin(_pinController.text) == null &&
            _validateConfirmPin(_confirmPinController.text) == null;
      default:
        return false;
    }
  }

  void _nextStep() {
    if (!_validateStep(_currentStep)) {
      _formKey.currentState!.validate();
      _showError('Veuillez remplir tous les champs correctement');
      return;
    }
    if (_currentStep < 2) {
      _animController.reset();
      setState(() => _currentStep++);
      _animController.forward();
    } else {
      _inscrire();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _animController.reset();
      setState(() => _currentStep--);
      _animController.forward();
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: _red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _inscrire() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _isLoading = false);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => DashboardPage(
          nomBoutique: _boutiqueController.text.trim(),
          nomCommercant:
              '${_prenomController.text.trim()} ${_nomController.text.trim()}',
          ville: _villeController.text.trim(),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER avec logo + progression
            _buildHeader(),

            // ── CONTENU FORMULAIRE
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Form(
                  key: _formKey,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 28),

                        // Titre de l'étape
                        _buildStepHeader(),

                        const SizedBox(height: 28),

                        // Contenu de l'étape
                        _buildStepContent(),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── BOUTONS NAVIGATION
            _buildNavButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        children: [
          // Logo
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _green,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              const Text(
                'Le Commerçant',
                style: TextStyle(
                  color: _green,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              // Bouton retour connexion
              if (_currentStep == 0)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _greenLight,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'Connexion',
                      style: TextStyle(
                          color: _green, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 24),

          // Barre de progression par étapes
          Row(
            children: List.generate(3, (i) {
              final isActive = i == _currentStep;
              final isDone = i < _currentStep;
              return Expanded(
                child: Row(
                  children: [
                    if (i > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: isDone ? _green : _greyMid,
                        ),
                      ),
                    Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: isDone
                                ? _green
                                : isActive
                                    ? _greenLight
                                    : _grey,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isActive || isDone ? _green : _border,
                              width: isActive ? 2 : 1,
                            ),
                          ),
                          child: Center(
                            child: isDone
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 18)
                                : Icon(
                                    _stepIcons[i],
                                    color: isActive ? _green : _hint,
                                    size: 16,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ['Infos', 'Boutique', 'Sécurité'][i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isActive || isDone ? _green : _hint,
                          ),
                        ),
                      ],
                    ),
                    if (i < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i < _currentStep ? _green : _greyMid,
                        ),
                      ),
                  ],
                ),
              );
            }),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _greenLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_stepIcons[_currentStep], color: _green, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'Étape ${_currentStep + 1}/3',
              style: const TextStyle(
                color: _green,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          _stepTitles[_currentStep],
          style: const TextStyle(
            color: _text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _stepSubtitles[_currentStep],
          style: const TextStyle(color: _hint, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildStep0();
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      default:
        return const SizedBox();
    }
  }

  // ── ÉTAPE 0 : Informations personnelles
  Widget _buildStep0() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _AppField(
                controller: _prenomController,
                hint: 'Prénom',
                icon: Icons.person_outline_rounded,
                validator: (v) => _validateNotEmpty(v, 'Prénom'),
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _AppField(
                controller: _nomController,
                hint: 'Nom de famille',
                icon: Icons.person_outline_rounded,
                validator: (v) => _validateNotEmpty(v, 'Nom'),
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Téléphone avec indicatif
        Container(
          decoration: BoxDecoration(
            color: _grey,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              // Indicatif pays
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  color: _greenLight,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                  ),
                ),
                child: const Row(
                  children: [
                    Text('🇸🇳', style: TextStyle(fontSize: 18)),
                    SizedBox(width: 6),
                    Text(
                      '+221',
                      style: TextStyle(
                        color: _green,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Champ numéro
              Expanded(
                child: TextFormField(
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  maxLength: 9,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: _validatePhone,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: _text, fontSize: 15),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '77 000 00 00',
                    hintStyle: TextStyle(color: _hint, fontSize: 14),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Carte info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _amberLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEF9F27), width: 0.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: _amber, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre numéro servira à vous identifier. Assurez-vous qu\'il est correct.',
                  style: TextStyle(color: _amber, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 1 : Boutique
  Widget _buildStep1() {
    return Column(
      children: [
        _AppField(
          controller: _boutiqueController,
          hint: 'Ex: Boutique Al Amine',
          label: 'Nom de la boutique',
          icon: Icons.storefront_outlined,
          validator: (v) => _validateNotEmpty(v, 'Nom boutique'),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),
        _AppField(
          controller: _villeController,
          hint: 'Ex: Touba, Dakar, Thiès...',
          label: 'Ville / Quartier',
          icon: Icons.location_on_outlined,
          validator: (v) => _validateNotEmpty(v, 'Ville'),
          textInputAction: TextInputAction.done,
        ),
        const SizedBox(height: 20),

        // Aperçu de la carte commerçant
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _green,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.storefront_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Aperçu de votre profil',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ValueListenableBuilder(
                valueListenable: _boutiqueController,
                builder: (_, val, __) => Text(
                  _boutiqueController.text.trim().isEmpty
                      ? 'Nom de la boutique'
                      : _boutiqueController.text.trim(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              ValueListenableBuilder(
                valueListenable: _villeController,
                builder: (_, __, ___) => Text(
                  [
                    if (_prenomController.text.trim().isNotEmpty)
                      '${_prenomController.text.trim()} ${_nomController.text.trim()}',
                    if (_villeController.text.trim().isNotEmpty)
                      _villeController.text.trim(),
                  ].join(' · '),
                  style:
                      const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── ÉTAPE 2 : Sécurité PIN
  Widget _buildStep2() {
    return Column(
      children: [
        // Icône cadenas décorative
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: _greenLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_rounded, color: _green, size: 34),
          ),
        ),
        const SizedBox(height: 20),

        _AppField(
          controller: _pinController,
          hint: '• • • •',
          label: 'Code PIN (4 chiffres)',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscurePin,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validatePin,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePin
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _hint,
              size: 20,
            ),
            onPressed: () => setState(() => _obscurePin = !_obscurePin),
          ),
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 14),

        _AppField(
          controller: _confirmPinController,
          hint: '• • • •',
          label: 'Confirmer le code PIN',
          icon: Icons.lock_outline_rounded,
          obscureText: _obscureConfirmPin,
          maxLength: 4,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          validator: _validateConfirmPin,
          suffixIcon: IconButton(
            icon: Icon(
              _obscureConfirmPin
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: _hint,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureConfirmPin = !_obscureConfirmPin),
          ),
          textInputAction: TextInputAction.done,
        ),

        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _greenLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF5DCAA5), width: 0.5),
          ),
          child: const Row(
            children: [
              Icon(Icons.shield_outlined, color: _green, size: 18),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Votre code PIN protège votre compte. Ne le partagez avec personne.',
                  style: TextStyle(color: _greenDark, fontSize: 12, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNavButtons() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 0.5)),
      ),
      child: Row(
        children: [
          // Bouton Retour (masqué à étape 0)
          if (_currentStep > 0)
            GestureDetector(
              onTap: _prevStep,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: _grey,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: _textMuted, size: 22),
              ),
            ),
          if (_currentStep > 0) const SizedBox(width: 12),

          // Bouton Principal
          Expanded(
            child: SizedBox(
              height: 54,
              child: _isLoading
                  ? Container(
                      decoration: BoxDecoration(
                        color: _green,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _nextStep,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _currentStep < 2 ? 'Continuer' : "S'inscrire",
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _currentStep < 2
                                ? Icons.arrow_forward_rounded
                                : Icons.check_rounded,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── WIDGET CHAMP RÉUTILISABLE
class _AppField extends StatelessWidget {
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

  static const Color _green = Color(0xFF0F6E56);
  static const Color _grey = Color(0xFFF4F4F2);
  static const Color _border = Color(0xFFE0E0E0);
  static const Color _hint = Color(0xFF9CA3AF);
  static const Color _text = Color(0xFF1A1A1A);
  static const Color _red = Color(0xFFA32D2D);

  const _AppField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.label,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLength,
    this.inputFormatters,
    this.suffixIcon,
    this.validator,
    this.textInputAction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: const TextStyle(
              color: Color(0xFF374151),
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          textInputAction: textInputAction,
          validator: validator,
          style: const TextStyle(color: _text, fontSize: 15),
          decoration: InputDecoration(
            counterText: '',
            hintText: hint,
            hintStyle: const TextStyle(color: _hint, fontSize: 14),
            prefixIcon: Icon(icon, color: _hint, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: _grey,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _green, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red, width: 1.5),
            ),
            errorStyle: const TextStyle(color: _red, fontSize: 11),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}