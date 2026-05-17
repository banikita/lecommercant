import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dashbord.dart';
import 'register.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  static const int _pinLength = 4;
  static const int _maxTentatives = 5;

  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePin = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -5.0, end: 5.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 5.0, end: 0.0), weight: 1),
    ]).animate(_shakeController);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _login() async {
    final phone = _phoneController.text.trim();
    final pin = _pinController.text.trim();

    if (phone.isEmpty || pin.isEmpty) {
      setState(() => _errorMessage = 'Veuillez remplir tous les champs');
      _shakeController.forward(from: 0.0);
      return;
    }
    if (phone.length != 9 || !phone.startsWith('7')) {
      setState(() => _errorMessage = 'Numéro invalide (ex: 77 123 45 67)');
      _shakeController.forward(from: 0.0);
      return;
    }
    if (pin.length != _pinLength) {
      setState(() => _errorMessage = 'Le PIN doit contenir 4 chiffres');
      _shakeController.forward(from: 0.0);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _supabase
          .from('commercants')
          .select('id, prenom, nom, nom_boutique, ville, pin_hash, tentatives_connexion')
          .eq('telephone', phone)
          .maybeSingle();

      if (response == null) {
        setState(() {
          _errorMessage = 'Aucun compte avec ce numéro';
          _isLoading = false;
        });
        _shakeController.forward(from: 0.0);
        return;
      }

      final tentatives = response['tentatives_connexion'] as int? ?? 0;
      if (tentatives >= _maxTentatives) {
        setState(() {
          _errorMessage = 'Compte bloqué. Réinitialisez votre PIN.';
          _isLoading = false;
        });
        _showBlockedDialog(phone);
        return;
      }

      final storedHash = response['pin_hash'] as String?;
      if (storedHash == null) {
        setState(() {
          _errorMessage = 'PIN non configuré';
          _isLoading = false;
        });
        _shakeController.forward(from: 0.0);
        return;
      }

      final enteredHash = _hashPin(pin);
      if (storedHash == enteredHash) {
        await _supabase
            .from('commercants')
            .update({'tentatives_connexion': 0})
            .eq('telephone', phone);

        final id = response['id'] as int;
        final prenom = response['prenom'] as String? ?? '';
        final nom = response['nom'] as String? ?? '';
        final boutique = response['nom_boutique'] as String? ?? '';
        final ville = response['ville'] as String? ?? '';

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_logged_in', true);
        await prefs.setInt('commercant_id', id);
        await prefs.setString('nom_commercant', '$prenom $nom');
        await prefs.setString('nom_boutique', boutique);
        await prefs.setString('ville', ville);
        await prefs.setString('telephone', phone);

        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              commercantId: id,
              nomCommercant: '$prenom $nom',
              nomBoutique: boutique,
              ville: ville,
            ),
          ),
        );
      } else {
        final newTentatives = tentatives + 1;
        await _supabase
            .from('commercants')
            .update({'tentatives_connexion': newTentatives})
            .eq('telephone', phone);

        setState(() {
          _errorMessage = 'PIN incorrect (${newTentatives}/$_maxTentatives)';
          _isLoading = false;
          _pinController.clear();
        });
        _shakeController.forward(from: 0.0);

        if (newTentatives >= _maxTentatives) {
          _showBlockedDialog(phone);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur de connexion';
        _isLoading = false;
      });
      _shakeController.forward(from: 0.0);
    }
  }

  void _showBlockedDialog(String phone) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Compte bloqué'),
        content: const Text('Trop de tentatives incorrectes. Réinitialisez votre PIN.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showResetPinSheet(phone);
            },
            child: const Text('Réinitialiser'),
          ),
        ],
      ),
    );
  }

  void _showResetPinSheet(String phone) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ResetPinSheet(phone: phone),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE1F5EE),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/logo.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.storefront_rounded,
                        size: 50,
                        color: const Color(0xFF0F6E56),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Le Commerçant',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F6E56)),
                ),
                const SizedBox(height: 8),
                const Text('Gérez vos ventes et vos clients', style: TextStyle(color: Color(0xFF6B7280))),
                const SizedBox(height: 40),
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(_shakeAnimation.value, 0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              maxLength: 9,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Numéro de téléphone',
                                hintText: '77 123 45 67',
                                prefixText: '+221 ',
                                prefixStyle: const TextStyle(color: Color(0xFF0F6E56)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _pinController,
                              obscureText: _obscurePin,
                              keyboardType: TextInputType.number,
                              maxLength: _pinLength,
                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                              decoration: InputDecoration(
                                labelText: 'Code PIN',
                                hintText: '••••',
                                suffixIcon: IconButton(
                                  icon: Icon(_obscurePin ? Icons.visibility_off : Icons.visibility),
                                  onPressed: () => setState(() => _obscurePin = !_obscurePin),
                                ),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                            if (_errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                            ],
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 50,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0F6E56),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text('Se connecter'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage()));
                  },
                  child: const Text('Pas encore de compte ? Inscrivez-vous'),
                ),
                TextButton(
                  onPressed: () {
                    final phone = _phoneController.text.trim();
                    if (phone.isEmpty) {
                      setState(() => _errorMessage = 'Entrez votre numéro pour réinitialiser');
                      return;
                    }
                    if (phone.length != 9 || !phone.startsWith('7')) {
                      setState(() => _errorMessage = 'Numéro invalide');
                      return;
                    }
                    _showResetPinSheet(phone);
                  },
                  child: const Text('Mot de passe oublié ?', style: TextStyle(color: Color(0xFF0F6E56))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPinSheet extends StatefulWidget {
  final String phone;
  const _ResetPinSheet({required this.phone});

  @override
  State<_ResetPinSheet> createState() => _ResetPinSheetState();
}

class _ResetPinSheetState extends State<_ResetPinSheet> {
  final _newPinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _newPinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin.trim());
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _resetPin() async {
    final newPin = _newPinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (newPin.isEmpty || confirm.isEmpty) {
      setState(() => _error = 'Veuillez remplir les deux champs');
      return;
    }
    if (newPin.length != 4 || !RegExp(r'^\d+$').hasMatch(newPin)) {
      setState(() => _error = 'Le PIN doit contenir 4 chiffres');
      return;
    }
    if (newPin != confirm) {
      setState(() => _error = 'Les codes PIN ne correspondent pas');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final supabase = Supabase.instance.client;
      final hash = _hashPin(newPin);
      await supabase
          .from('commercants')
          .update({'pin_hash': hash, 'tentatives_connexion': 0})
          .eq('telephone', widget.phone);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN réinitialisé avec succès')),
      );
    } catch (e) {
      setState(() => _error = 'Erreur, veuillez réessayer');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          const Text('Réinitialiser le code PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Nouveau PIN pour le numéro ${widget.phone}', style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          TextField(
            controller: _newPinCtrl,
            obscureText: _obscureNew,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: 'Nouveau PIN (4 chiffres)',
              suffixIcon: IconButton(
                icon: Icon(_obscureNew ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureNew = !_obscureNew),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmCtrl,
            obscureText: _obscureConfirm,
            keyboardType: TextInputType.number,
            maxLength: 4,
            decoration: InputDecoration(
              labelText: 'Confirmer le PIN',
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) ...[const SizedBox(height: 8), Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12))],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _resetPin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F6E56),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Réinitialiser'),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}