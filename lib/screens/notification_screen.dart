import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notification.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../config.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/notifications'),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: _notifications.isEmpty
          ? const Center(child: Text('Không có thông báo nào'))
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return ListTile(
                  leading: n.avatar.isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(n.avatar))
                      : const CircleAvatar(child: Icon(Icons.notifications)),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.body),
                  trailing: n.isNew ? const Icon(Icons.fiber_new, color: Colors.red) : null,
                  onTap: () {
                    // TODO: Điều hướng đến post/comment/chat...
                  },
                );
              },
            ),
    );
  }
}
