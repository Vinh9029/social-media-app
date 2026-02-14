import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';
import 'chat_detail_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchConversations();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations.where((c) =>
        c.name.toLowerCase().contains(query) ||
        c.username.toLowerCase().contains(query) ||
        c.lastMessage.toLowerCase().contains(query)
      ).toList();
    });
  }

  Future<void> _fetchConversations() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/messages/conversations'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _conversations = data.map((json) => Conversation.fromJson(json)).toList();
          _filteredConversations = _conversations;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Tìm kiếm tin nhắn hoặc người dùng...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: _filteredConversations.isEmpty
              ? const Center(child: Text('Không tìm thấy cuộc trò chuyện nào'))
              : ListView.builder(
                  itemCount: _filteredConversations.length,
                  itemBuilder: (context, index) {
                    final conv = _filteredConversations[index];
                    return ListTile(
                      leading: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile', arguments: conv.partnerId);
                        },
                        child: (conv.avatar != null && conv.avatar!.isNotEmpty)
                            ? CachedNetworkImage(
                                imageUrl: conv.avatar!,
                                imageBuilder: (context, imageProvider) => CircleAvatar(backgroundImage: imageProvider),
                                placeholder: (context, url) => const CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
                                errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.person)),
                              )
                            : const CircleAvatar(child: Icon(Icons.person)),
                      ),
                      title: GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, '/profile', arguments: conv.partnerId);
                        },
                        child: Text(conv.name, style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                      ),
                      subtitle: Text(conv.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700])),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatDetailScreen(partnerId: conv.partnerId, partnerName: conv.name),
                          ),
                        ).then((_) => _fetchConversations());
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}