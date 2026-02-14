import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config.dart';
import '../providers/auth_provider.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<dynamic> _conversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations([String? query]) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      String url = '$API_URL/api/messages/conversations';
      if (query != null && query.isNotEmpty) {
        url += '?q=$query';
      }
      final response = await http.get(
        Uri.parse(url),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        setState(() {
          _conversations = json.decode(response.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching conversations: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Không dùng AppBar cho search, đặt search ngay đầu body để dễ với tay
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => _fetchConversations(val),
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm tin nhắn...',
                    prefixIcon: Icon(LucideIcons.search, color: Colors.grey),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _conversations.isEmpty
                      ? const Center(child: Text("Chưa có tin nhắn nào"))
                      : ListView.builder(
                          itemCount: _conversations.length,
                          itemBuilder: (context, index) {
                            final conv = _conversations[index];
                            return ListTile(
                              leading: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundImage: conv['avatar'] != null
                                        ? CachedNetworkImageProvider(conv['avatar'])
                                        : null,
                                    child: conv['avatar'] == null ? const Icon(Icons.person) : null,
                                  ),
                                  // Mock Online Status indicator
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                  )
                                ],
                              ),
                              title: Text(conv['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                conv['lastMessage'],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: conv['read'] == false && conv['isSender'] == false ? FontWeight.bold : FontWeight.normal),
                              ),
                              trailing: Text(
                                DateTime.parse(conv['timestamp']).toLocal().toString().substring(11, 16),
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatDetailScreen(
                                      partnerId: conv['partnerId'],
                                      partnerName: conv['name'],
                                      partnerAvatar: conv['avatar'],
                                    ),
                                  ),
                                ).then((_) => _fetchConversations());
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}