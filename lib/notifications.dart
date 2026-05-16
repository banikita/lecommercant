import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:le_commercant/database/app_database.dart';
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const Color kGreen = Color(0xFF1A4A3A);
  static const Color kGreenMid = Color(0xFF22614D);
  static const Color kWhite = Colors.white;
  static const Color kMuted = Color(0xFF6B7280);
  static const Color kBorder = Color(0xFFE2E8F0);
  static const Color kBg = Color(0xFFF5F5F0);
  static const Color kDanger = Color(0xFFE53E3E);
  final _db = AppDatabase.instance;
  late List<Map<String, dynamic>> _notifs;

  @override
  void initState() {
    super.initState();
    _notifs = AppDatabase.getNotifications();
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'vente': return const Color(0xFF22614D);
      case 'rapport': return const Color(0xFF3B82F6);
      case 'securite': return const Color(0xFFE53E3E);
      default: return const Color(0xFFF59E0B);
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'vente': return Icons.check_circle_outline;
      case 'rapport': return Icons.bar_chart;
      case 'securite': return Icons.shield_outlined;
      default: return Icons.settings_outlined;
    }
  }

  Future<void> _markOne(int id) async {
    setState(() {
      _notifs = _notifs.map((n) => n['id'] == id ? {...n, 'read': true} : n).toList();
    });
    await AppDatabase.saveNotifications(_notifs);
  }

  Future<void> _markAll() async {
    setState(() {
      _notifs = _notifs.map((n) => {...n, 'read': true}).toList();
    });
    await AppDatabase.saveNotifications(_notifs);
  }

  Future<void> _deleteOne(int id) async {
    setState(() {
      _notifs = _notifs.where((n) => n['id'] != id).toList();
    });
    await AppDatabase.saveNotifications(_notifs);
  }

  int get _unread => _notifs.where((n) => n['read'] == false).length;

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
                    Expanded(
                      child: Text(
                        _unread > 0 ? 'Notifications ($_unread)' : 'Notifications',
                        style: const TextStyle(color: kWhite, fontSize: 20, fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (_unread > 0)
                      TextButton(
                        onPressed: _markAll,
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white24,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        ),
                        child: const Text('Tout lire',
                            style: TextStyle(color: kWhite, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // List
          Expanded(
            child: _notifs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 60, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        const Text('Aucune notification',
                            style: TextStyle(color: kMuted, fontSize: 15)),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _notifs.length,
                    itemBuilder: (ctx, i) {
                      final n = _notifs[i];
                      final isRead = n['read'] as bool;
                      final type = n['type'] as String;
                      return GestureDetector(
                        onTap: () => _markOne(n['id'] as int),
                        child: Container(
                          color: isRead ? kWhite : const Color(0xFFF0FAF5),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: _typeColor(type),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(_typeIcon(type), color: kWhite, size: 20),
                              ),
                              const SizedBox(width: 12),
                              // Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(n['title'] as String,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: isRead ? FontWeight.w500 : FontWeight.w700)),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8, height: 8,
                                            decoration: const BoxDecoration(
                                                color: kGreen, shape: BoxShape.circle),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(n['body'] as String,
                                        style: const TextStyle(fontSize: 12, color: kMuted)),
                                    const SizedBox(height: 4),
                                    Text(n['time'] as String,
                                        style: const TextStyle(fontSize: 11, color: kMuted)),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => _deleteOne(n['id'] as int),
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFD1D5DB)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
