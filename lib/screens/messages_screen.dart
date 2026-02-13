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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchConversations();
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
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    
    if (_conversations.isEmpty) {
      return const Center(child: Text('Chưa có tin nhắn nào'));
    }

    return ListView.builder(
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: conv.avatar != null ? CachedNetworkImageProvider(conv.avatar!) : null,
            child: conv.avatar == null ? const Icon(Icons.person) : null,
          ),
          title: Text(conv.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(conv.lastMessage, maxLines: 1, overflow: TextOverflow.ellipsis),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatDetailScreen(partnerId: conv.partnerId, partnerName: conv.name),
              ),
            ).then((_) => _fetchConversations()); // Refresh khi quay lại
          },
        );
      },
    );
  }
}