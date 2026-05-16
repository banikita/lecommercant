import 'package:flutter/material.dart';

class AidePage extends StatefulWidget {
  const AidePage({super.key});

  @override
  State<AidePage> createState() => _AidePageState();
}

class _AidePageState extends State<AidePage> {
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kGreenMid = Color(0xFF22614D);
  static const Color kWhite = Colors.white;
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kBg = Color(0xFFF5F5F0);

  int? _openFaq;

  final List<Map<String, String>> _faqs = [
    {
      'q': 'Comment enregistrer une vente ?',
      'a': "Allez dans l'onglet Vente, cliquez sur le bouton +, sélectionnez les produits et validez la transaction.",
    },
    {
      'q': 'Comment exporter un rapport ?',
      'a': 'Dans Rapports & Stats, choisissez la période, puis cliquez sur l\'icône de partage en haut à droite.',
    },
    {
      'q': 'Comment changer mon mot de passe ?',
      'a': 'Allez dans Mon Profil > Changer le mot de passe. Saisissez l\'ancien puis le nouveau mot de passe.',
    },
    {
      'q': 'Comment activer la biométrie ?',
      'a': 'Dans Biométrie & Sécurité, activez l\'option "Empreinte digitale" ou "Reconnaissance faciale".',
    },
    {
      'q': 'L\'application ne se synchronise pas',
      'a': 'Vérifiez votre connexion internet. Allez dans Paramètres et assurez-vous que la synchronisation auto est activée.',
    },
  ];

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
                      child: Text('Aide & Support',
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
                  // Quick contact buttons
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: _contactBtn(
                            icon: Icons.chat_bubble_outline,
                            label: 'Chat en direct',
                            color: kGreen,
                            onTap: () {},
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _contactBtn(
                            icon: Icons.bug_report_outlined,
                            label: 'Signaler un bug',
                            color: const Color(0xFF3B82F6),
                            onTap: () {},
                          ),
                        ),
                      ],
                    ),
                  ),

                  // FAQ
                  const Padding(
                    padding: EdgeInsets.only(left: 18, top: 16, bottom: 6),
                    child: Text('QUESTIONS FRÉQUENTES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: kMuted, letterSpacing: 1)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: List.generate(_faqs.length, (i) {
                        final isOpen = _openFaq == i;
                        return Column(
                          children: [
                            InkWell(
                              onTap: () => setState(() => _openFaq = isOpen ? null : i),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(_faqs[i]['q']!,
                                          style: const TextStyle(
                                              fontSize: 14, fontWeight: FontWeight.w600)),
                                    ),
                                    AnimatedRotation(
                                      turns: isOpen ? 0.25 : 0,
                                      duration: const Duration(milliseconds: 200),
                                      child: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isOpen)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                child: Text(_faqs[i]['a']!,
                                    style: const TextStyle(fontSize: 13, color: kMuted, height: 1.6)),
                              ),
                            if (i < _faqs.length - 1)
                              const Divider(height: 1, color: kBorder),
                          ],
                        );
                      }),
                    ),
                  ),

                  // Informations
                  const Padding(
                    padding: EdgeInsets.only(left: 18, top: 16, bottom: 6),
                    child: Text('INFORMATIONS',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: kMuted, letterSpacing: 1)),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: kWhite,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 6)],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.help_outline, color: kGreen, size: 18),
                          ),
                          title: const Text("Centre d'aide en ligne",
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 70, color: kBorder),
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.play_circle_outline, color: kGreen, size: 18),
                          ),
                          title: const Text('Tutoriels vidéo',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          trailing: const Icon(Icons.chevron_right, color: kMuted, size: 18),
                          onTap: () {},
                        ),
                        const Divider(height: 1, indent: 70, color: kBorder),
                        ListTile(
                          leading: Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: const Color(0xFFF0FAF5), borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.mail_outline, color: kGreen, size: 18),
                          ),
                          title: const Text('Nous contacter',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          subtitle: const Text('support@cerveb.com',
                              style: TextStyle(fontSize: 12, color: kMuted)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _contactBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(icon, color: kWhite, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(color: kWhite, fontSize: 13, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}