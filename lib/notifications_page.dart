import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'creanciers_page.dart';

class NotificationsPage extends StatefulWidget {
  final int commercantId;
  const NotificationsPage({super.key, required this.commercantId});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage>
    with AutomaticKeepAliveClientMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  RealtimeChannel? _channel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _chargerNotifications();
    _ecouterNotificationsRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  void _ecouterNotificationsRealtime() {
    _channel = _supabase
        .channel('public:notifications')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'commercant_id',
            value: widget.commercantId,
          ),
          callback: (payload) {
            final nouvelle = payload.newRecord;
            setState(() {
              _notifications.insert(0, Map<String, dynamic>.from(nouvelle));
            });
            _showNotificationPopup(nouvelle['titre'], nouvelle['message']);
          },
        )
        .subscribe();
  }

  void _showNotificationPopup(String titre, String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(titre, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Ouvrir',
          textColor: Colors.white,
          onPressed: _chargerNotifications,
        ),
      ),
    );
  }

  Future<void> _chargerNotifications() async {
    setState(() => _loading = true);
    final data = await _supabase
        .from('notifications')
        .select()
        .eq('commercant_id', widget.commercantId)
        .order('created_at', ascending: false);
    setState(() {
      _notifications = List<Map<String, dynamic>>.from(data);
      _loading = false;
    });
  }

  Future<void> _marquerLue(int id) async {
    await _supabase.from('notifications').update({'est_lu': true}).eq('id', id);
    _chargerNotifications();
  }

  Future<void> _toutMarquerLu() async {
    await _supabase
        .from('notifications')
        .update({'est_lu': true})
        .eq('commercant_id', widget.commercantId);
    _chargerNotifications();
  }

  Future<void> _supprimerNotification(int id) async {
    await _supabase.from('notifications').delete().eq('id', id);
    _chargerNotifications();
  }

  void _ouvrirDetail(Map<String, dynamic> notif) {
    // Détection d'une invitation (basée sur le titre ou le message)
    final bool estInvitation = notif['titre'].contains('Invitation') ||
        notif['titre'].contains('invitation') ||
        notif['message'].contains('ajouté comme débiteur');

    if (estInvitation) {
      // Extraire le nom du commerçant depuis le message
      final String message = notif['message'];
      // Format attendu : "X vous a ajouté comme débiteur..."
      final RegExp regExp = RegExp(r'^(.+?) vous a ajouté');
      final match = regExp.firstMatch(message);
      String nom = match?.group(1) ?? '';
      if (nom.isEmpty) {
        // Fallback : chercher après "vous a ajouté"
        final parts = message.split(' vous a ajouté');
        if (parts.isNotEmpty) nom = parts[0];
      }
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CreanciersPage(
            commercantId: widget.commercantId,
            suggestedNom: nom.trim(),
          ),
        ),
      ).then((_) => _marquerLue(notif['id']));
    } else {
      _marquerLue(notif['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        centerTitle: true,
        actions: [
          if (_notifications.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.done_all),
              tooltip: 'Tout marquer comme lu',
              onPressed: _toutMarquerLu,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.notifications_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text('Aucune notification',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _notifications.length,
                  itemBuilder: (_, i) {
                    final n = _notifications[i];
                    final bool lu = n['est_lu'] ?? false;
                    final date = DateTime.parse(n['created_at'] as String);
                    final bool estInvitation = n['titre'].contains('Invitation') ||
                        n['titre'].contains('invitation') ||
                        n['message'].contains('ajouté comme débiteur');
                    return Dismissible(
                      key: Key(n['id'].toString()),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) => _supprimerNotification(n['id']),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: lu ? Colors.grey.shade300 : Colors.green,
                          child: Icon(Icons.notifications,
                              color: lu ? Colors.grey : Colors.white),
                        ),
                        title: Text(
                          n['titre'],
                          style: TextStyle(
                            fontWeight: lu ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(n['message']),
                            const SizedBox(height: 4),
                            Text(DateFormat('dd/MM/yyyy HH:mm').format(date),
                                style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                        trailing: estInvitation && !lu
                            ? const Icon(Icons.chevron_right, color: Colors.blue)
                            : null,
                        onTap: () => _ouvrirDetail(n),
                      ),
                    );
                  },
                ),
    );
  }
}