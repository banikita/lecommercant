import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────
// PAGE PARAMÈTRES
// Gère : Langue · Thème · Verrouillage · Affichage · Données · À propos
// ─────────────────────────────────────────
class ParametresPage extends StatefulWidget {
  final int commercantId;
  const ParametresPage({super.key, required this.commercantId});
  @override
  State<ParametresPage> createState() => _ParametresPageState();
}

class _ParametresPageState extends State<ParametresPage> {

  static const _bg         = Color(0xFFF3F6F4);
  static const _white      = Color(0xFFFFFFFF);
  static const _ink        = Color(0xFF0E1A11);
  static const _slate      = Color(0xFF6B7A72);
  static const _mist       = Color(0xFFE5E8E4);
  static const _primary    = Color(0xFF0A5C47);
  static const _primaryMid = Color(0xFF0D7A5F);
  static const _primaryFt  = Color(0xFFE8F5F0);
  static const _gold       = Color(0xFFD4940A);
  static const _goldFt     = Color(0xFFFFF0C2);
  static const _purple     = Color(0xFF5B55D8);
  static const _purpleFt   = Color(0xFFEEEDFE);
  static const _blue       = Color(0xFF1A5FA8);
  static const _blueFt     = Color(0xFFE6F1FB);
  static const _coral      = Color(0xFFCC3B3B);
  static const _coralFt    = Color(0xFFFFF0F0);

  // ── États ──
  String _langue          = 'Français';
  bool   _modeSombre      = false;
  bool   _verrouAuto      = true;
  int    _delaiVerrou     = 1;
  bool   _afficherPrix    = true;
  bool   _compactView     = false;
  bool   _animations      = true;
  String _devise          = 'F CFA';
  String _formatDate      = 'DD/MM/YYYY';
  bool   _sauvegardeAuto  = true;
  bool   _modeHorsLigne   = false;

  static const _langues = ['Français', 'Wolof', 'English', 'Arabic'];
  static const _devises = ['F CFA', 'EUR', 'USD', 'GBP'];
  static const _formats = ['DD/MM/YYYY', 'MM/DD/YYYY', 'YYYY-MM-DD'];
  static const _delais  = [1, 2, 5, 10, 30];

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bg,
        body: Column(children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [

                // ── LANGUE & RÉGION ──────────────────
                _section('LANGUE & RÉGION', [
                  _ChoixTile(
                    emoji: '🌐', label: 'Langue de l\'application',
                    valeur: _langue, bg: _blueFt, iconColor: _blue,
                    onTap: () => _picker(
                      titre: 'Choisir la langue',
                      options: _langues, selected: _langue,
                      onSelect: (v) => setState(() => _langue = v),
                    ),
                  ),
                  _ChoixTile(
                    emoji: '💱', label: 'Devise',
                    valeur: _devise, bg: _goldFt, iconColor: _gold,
                    onTap: () => _picker(
                      titre: 'Choisir la devise',
                      options: _devises, selected: _devise,
                      onSelect: (v) => setState(() => _devise = v),
                    ),
                  ),
                  _ChoixTile(
                    emoji: '📅', label: 'Format de date',
                    valeur: _formatDate, bg: _purpleFt, iconColor: _purple,
                    onTap: () => _picker(
                      titre: 'Format de date',
                      options: _formats, selected: _formatDate,
                      onSelect: (v) => setState(() => _formatDate = v),
                    ),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── THÈME ────────────────────────────
                _section('THÈME & AFFICHAGE', [
                  _SwitchTile(
                    emoji: '🌙', emojiOn: '🌙', emojiOff: '☀️',
                    label: 'Mode sombre',
                    sub: _modeSombre ? 'Activé — fond foncé' : 'Désactivé — fond clair',
                    bg: const Color(0xFFEAE9F8),
                    activeColor: const Color(0xFF5B55D8),
                    value: _modeSombre,
                    onChanged: (v) => setState(() => _modeSombre = v),
                  ),
                  _SwitchTile(
                    emoji: '✨', label: 'Animations',
                    sub: 'Transitions et effets visuels',
                    bg: _purpleFt, activeColor: _purple,
                    value: _animations,
                    onChanged: (v) => setState(() => _animations = v),
                  ),
                  _SwitchTile(
                    emoji: '🗜️', label: 'Vue compacte',
                    sub: 'Réduire l\'espacement des listes',
                    bg: _primaryFt, activeColor: _primaryMid,
                    value: _compactView,
                    onChanged: (v) => setState(() => _compactView = v),
                  ),
                  _SwitchTile(
                    emoji: '💵', label: 'Afficher les prix',
                    sub: 'Visible dans le stock et les ventes',
                    bg: _goldFt, activeColor: _gold,
                    value: _afficherPrix,
                    onChanged: (v) => setState(() => _afficherPrix = v),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── ÉCRAN DE VERROUILLAGE ────────────
                _section('ÉCRAN DE VERROUILLAGE', [
                  _SwitchTile(
                    emoji: '🔐', label: 'Verrouillage automatique',
                    sub: 'Protéger l\'app après inactivité',
                    bg: _goldFt, activeColor: _gold,
                    value: _verrouAuto,
                    onChanged: (v) => setState(() => _verrouAuto = v),
                  ),
                  if (_verrouAuto)
                    _ChoixTile(
                      emoji: '⏱️', label: 'Délai de verrouillage',
                      valeur: '$_delaiVerrou min',
                      bg: _goldFt, iconColor: _gold,
                      onTap: () => _picker(
                        titre: 'Délai avant verrouillage',
                        options: _delais.map((d) => '$d min').toList(),
                        selected: '$_delaiVerrou min',
                        onSelect: (v) => setState(() =>
                            _delaiVerrou = int.parse(v.split(' ')[0])),
                      ),
                    ),
                  _InfoTile(
                    emoji: '🔒', label: 'Biométrie & mot de passe',
                    sub: 'Configurez-les dans Biométrie & sécurité',
                    bg: _primaryFt, iconColor: _primaryMid,
                  ),
                ]),

                const SizedBox(height: 20),

                // ── STOCKAGE & RÉSEAU ────────────────
                _section('STOCKAGE & RÉSEAU', [
                  _SwitchTile(
                    emoji: '☁️', label: 'Sauvegarde automatique',
                    sub: 'Synchronisation en arrière-plan',
                    bg: _blueFt, activeColor: _blue,
                    value: _sauvegardeAuto,
                    onChanged: (v) => setState(() => _sauvegardeAuto = v),
                  ),
                  _SwitchTile(
                    emoji: '📶', label: 'Mode hors ligne',
                    sub: 'Travailler sans connexion internet',
                    bg: _primaryFt, activeColor: _primaryMid,
                    value: _modeHorsLigne,
                    onChanged: (v) => setState(() => _modeHorsLigne = v),
                  ),
                  _ActionTile(
                    emoji: '🗑️', label: 'Vider le cache',
                    sub: 'Libérer de l\'espace de stockage',
                    bg: _coralFt, iconColor: _coral,
                    onTap: _confirmerViderCache,
                  ),
                  _ActionTile(
                    emoji: '📤', label: 'Exporter mes données',
                    sub: 'PDF ou Excel',
                    bg: _goldFt, iconColor: _gold,
                    onTap: () => _toast('Export — bientôt disponible !'),
                  ),
                ]),

                const SizedBox(height: 20),

                // ── À PROPOS ─────────────────────────
                _section('À PROPOS', [
                  _InfoTile(
                    emoji: '📱', label: 'Version',
                    sub: 'LeCommerçant v1.0.0 — build 42',
                    bg: _primaryFt, iconColor: _primaryMid,
                  ),
                  _InfoTile(
                    emoji: '🛡️', label: 'Politique de confidentialité',
                    sub: 'Vos données restent privées et sécurisées',
                    bg: _blueFt, iconColor: _blue,
                  ),
                  _ActionTile(
                    emoji: '⭐', label: 'Noter l\'application',
                    sub: 'Donnez votre avis sur le store',
                    bg: _goldFt, iconColor: _gold,
                    onTap: () => _toast('Merci pour votre soutien ! 🙏'),
                  ),
                ]),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ── HEADER ──────────────────────────────
  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF0A5C47), Color(0xFF0D7A5F), Color(0xFF0F926F)],
          stops: [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft:  Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [BoxShadow(
          color: Color(0x260A5C47), blurRadius: 20, offset: Offset(0, 6))],
      ),
      child: SafeArea(bottom: false, child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Row(children: [
          // Bouton retour
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20), width: 1),
              ),
              child: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 17),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Paramètres',
                  style: TextStyle(
                      color: Colors.white, fontSize: 20,
                      fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Personnalisez votre expérience',
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.65),
                      fontSize: 12)),
            ],
          )),
          // Badge langue
          GestureDetector(
            onTap: () => _picker(
              titre: 'Choisir la langue',
              options: _langues, selected: _langue,
              onSelect: (v) => setState(() => _langue = v),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.20), width: 1),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Text('🌐', style: TextStyle(fontSize: 12)),
                const SizedBox(width: 5),
                Text(_langue,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11,
                        fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                Icon(Icons.expand_more,
                    color: Colors.white.withValues(alpha: 0.8), size: 14),
              ]),
            ),
          ),
        ]),
      )),
    );
  }

  // ── SECTION ─────────────────────────────
  Widget _section(String title, List<Widget> items) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
        child: Row(children: [
          Container(width: 3, height: 13,
              decoration: BoxDecoration(
                  color: _primaryMid,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w800,
                  color: _slate, letterSpacing: 1.1)),
        ]),
      ),
      Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12, offset: const Offset(0, 3),
          )],
        ),
        child: Column(children: [
          for (int i = 0; i < items.length; i++) ...[
            items[i],
            if (i < items.length - 1)
              const Divider(height: 1, indent: 62, endIndent: 16,
                  color: _mist),
          ],
        ]),
      ),
    ]);
  }

  // ── PICKER BOTTOM SHEET ──────────────────
  void _picker({
    required String titre,
    required List<String> options,
    required String selected,
    required void Function(String) onSelect,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: _mist, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
            child: Text(titre,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800, color: _ink)),
          ),
          ...options.map((opt) {
            final sel = opt == selected;
            return GestureDetector(
              onTap: () { onSelect(opt); Navigator.pop(context); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: sel ? _primaryFt : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: sel
                        ? _primaryMid.withValues(alpha: 0.35)
                        : Colors.transparent,
                  ),
                ),
                child: Row(children: [
                  Expanded(child: Text(opt,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? _primaryMid : _ink))),
                  if (sel)
                    Container(
                      width: 22, height: 22,
                      decoration: const BoxDecoration(
                          color: _primaryMid, shape: BoxShape.circle),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 14),
                    ),
                ]),
              ),
            );
          }),
          const SizedBox(height: 8),
        ]),
      )),
    );
  }

  void _confirmerViderCache() {
    showDialog(context: context, builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Row(children: [
        Text('🗑️', style: TextStyle(fontSize: 22)),
        SizedBox(width: 8),
        Text('Vider le cache',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      ]),
      content: const Text(
          'Supprime les images et données temporaires.\n'
          'Vos ventes et dettes restent intactes.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler', style: TextStyle(color: _slate)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: _coral, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10))),
          onPressed: () {
            Navigator.pop(context);
            _toast('Cache vidé ✅');
          },
          child: const Text('Vider'),
        ),
      ],
    ));
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: _primaryMid,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }
}

// ─────────────────────────────────────────
// TUILE — CHOIX (valeur + flèche)
// ─────────────────────────────────────────
class _ChoixTile extends StatefulWidget {
  final String emoji, label, valeur;
  final Color  bg, iconColor;
  final VoidCallback onTap;
  const _ChoixTile({
    required this.emoji, required this.label, required this.valeur,
    required this.bg, required this.iconColor, required this.onTap,
  });
  @override
  State<_ChoixTile> createState() => _ChoixTileState();
}
class _ChoixTileState extends State<_ChoixTile> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _p = true),
    onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _p ? widget.bg.withValues(alpha: 0.5) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: widget.bg,
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(widget.emoji,
              style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 14),
        Expanded(child: Text(widget.label,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600,
                color: Color(0xFF0E1A11)))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
              color: widget.bg, borderRadius: BorderRadius.circular(20)),
          child: Text(widget.valeur,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                  color: widget.iconColor)),
        ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right, size: 18, color: Color(0xFF6B7A72)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────
// TUILE — SWITCH
// ─────────────────────────────────────────
class _SwitchTile extends StatelessWidget {
  final String  emoji, label, sub;
  final String? emojiOn, emojiOff;
  final Color   bg, activeColor;
  final bool    value;
  final void Function(bool) onChanged;
  const _SwitchTile({
    required this.emoji, required this.label, required this.sub,
    required this.bg, required this.activeColor,
    required this.value, required this.onChanged,
    this.emojiOn, this.emojiOff,
  });
  @override
  Widget build(BuildContext context) {
    final displayEmoji = value && emojiOn != null ? emojiOn!
        : !value && emojiOff != null ? emojiOff! : emoji;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: value
                ? activeColor.withValues(alpha: 0.15) : bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Text(displayEmoji,
              style: const TextStyle(fontSize: 18))),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF0E1A11))),
            const SizedBox(height: 2),
            Text(sub,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7A72))),
          ],
        )),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          activeTrackColor: activeColor.withValues(alpha: 0.25),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────
// TUILE — ACTION
// ─────────────────────────────────────────
class _ActionTile extends StatefulWidget {
  final String emoji, label, sub;
  final Color  bg, iconColor;
  final VoidCallback onTap;
  const _ActionTile({
    required this.emoji, required this.label, required this.sub,
    required this.bg, required this.iconColor, required this.onTap,
  });
  @override
  State<_ActionTile> createState() => _ActionTileState();
}
class _ActionTileState extends State<_ActionTile> {
  bool _p = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown:   (_) => setState(() => _p = true),
    onTapUp:     (_) { setState(() => _p = false); widget.onTap(); },
    onTapCancel: () => setState(() => _p = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      color: _p ? widget.bg.withValues(alpha: 0.5) : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: widget.bg,
              borderRadius: BorderRadius.circular(12)),
          child: Center(child: Text(widget.emoji,
              style: const TextStyle(fontSize: 18)))),
        const SizedBox(width: 14),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600,
                    color: Color(0xFF0E1A11))),
            const SizedBox(height: 2),
            Text(widget.sub,
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF6B7A72))),
          ],
        )),
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: widget.bg,
              borderRadius: BorderRadius.circular(8)),
          child: Icon(Icons.chevron_right,
              size: 16, color: widget.iconColor)),
      ]),
    ),
  );
}

// ─────────────────────────────────────────
// TUILE — INFO (non cliquable)
// ─────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final String emoji, label, sub;
  final Color  bg, iconColor;
  const _InfoTile({
    required this.emoji, required this.label, required this.sub,
    required this.bg, required this.iconColor,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      Container(width: 40, height: 40,
        decoration: BoxDecoration(color: bg,
            borderRadius: BorderRadius.circular(12)),
        child: Center(child: Text(emoji,
            style: const TextStyle(fontSize: 18)))),
      const SizedBox(width: 14),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: Color(0xFF0E1A11))),
          const SizedBox(height: 2),
          Text(sub,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF6B7A72))),
        ],
      )),
      Icon(Icons.info_outline, size: 16, color: iconColor),
    ]),
  );
}
