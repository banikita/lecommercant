import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:le_commercant/database/app_database.dart';

class ParametresPage extends StatefulWidget {
  const ParametresPage({super.key});

  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kGreenMid = Color(0xFF22614D);
  static const Color kWhite = Colors.white;
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kBg = Color(0xFFF5F5F0);
  static const Color kDanger = Color(0xFFE53E3E);

  late Map<String, dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = AppDatabase.getSettings();
  }

  Future<void> _update(String key, dynamic value) async {
    setState(() => _settings[key] = value);
    await AppDatabase.saveSettings(_settings);
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 18, top: 16, bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: kMuted, letterSpacing: 1)),
      );

  Widget _toggleRow(IconData icon, String label, String key) {
    return SwitchListTile(
      value: _settings[key] as bool,
      onChanged: (v) => _update(key, v),
      activeColor: kGreen,
      secondary: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: kGreen, size: 18),
      ),
      title: Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    );
  }

  Widget _dropdownRow(IconData icon, String label, String key, List<String> options) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: kGreen, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          DropdownButton<String>(
            value: _settings[key] as String,
            underline: const SizedBox(),
            style: const TextStyle(fontSize: 13, color: Color(0xFF1A1A1A), fontFamily: 'Nunito'),
            items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: (v) { if (v != null) _update(key, v); },
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: kWhite,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
        ),
        child: Column(
          children: List.generate(children.length, (i) => Column(
            children: [
              children[i],
              if (i < children.length - 1) const Divider(height: 1, indent: 70, color: kBorder),
            ],
          )),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          // Header
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [kGreen, kGreenMid],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 16, 16),
                child: Row(
                  children: [
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: kWhite, size: 20)),
                    const Expanded(
                      child: Text('Paramètres',
                          style: TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionLabel('PRÉFÉRENCES'),
                  _card([
                    _dropdownRow(Icons.language, 'Langue', 'langue',
                        ['Français', 'English', 'Wolof']),
                    _dropdownRow(Icons.monetization_on_outlined, 'Devise', 'devise',
                        ['XOF (F CFA)', 'EUR (€)', 'USD (\$)']),
                  ]),

                  _sectionLabel('NOTIFICATIONS'),
                  _card([
                    _toggleRow(Icons.notifications_outlined, 'Notifications push', 'notifications'),
                    _toggleRow(Icons.volume_up_outlined, 'Sons', 'sons'),
                    _toggleRow(Icons.vibration, 'Vibrations', 'vibration'),
                  ]),

                  _sectionLabel('DONNÉES'),
                  _card([
                    _toggleRow(Icons.sync, 'Synchronisation auto', 'syncAuto'),
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF5F5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.delete_outline, color: kDanger, size: 18),
                      ),
                      title: const Text('Vider le cache',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kDanger)),
                      trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Cache vidé !'), backgroundColor: kGreen));
                      },
                    ),
                  ]),

                  _sectionLabel('APPLICATION'),
                  _card([
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.info_outline, color: kGreen, size: 18),
                      ),
                      title: const Text('Version de l\'app',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Text('v2.4.1',
                          style: TextStyle(fontSize: 13, color: kMuted)),
                    ),
                    const Divider(height: 1, indent: 70, color: kBorder),
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.shield_outlined, color: kGreen, size: 18),
                      ),
                      title: const Text("Conditions d'utilisation",
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                      onTap: () {},
                    ),
                    const Divider(height: 1, indent: 70, color: kBorder),
                    ListTile(
                      leading: Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.policy_outlined, color: kGreen, size: 18),
                      ),
                      title: const Text('Politique de confidentialité',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                      onTap: () {},
                    ),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}