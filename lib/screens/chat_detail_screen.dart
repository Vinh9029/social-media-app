import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/message.dart';
import '../providers/auth_provider.dart';

class ChatDetailScreen extends StatefulWidget {
  final String partnerId;
  final String partnerName;

  const ChatDetailScreen({super.key, required this.partnerId, required this.partnerName});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  List<Message> _messages = [];
  final _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchMessages();
  }

  Future<void> _fetchMessages() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/messages/${widget.partnerId}'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _messages = data.map((json) => Message.fromJson(json)).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Error fetching messages: $e");
    }
  }

  Future<void> _sendMessage() async {
    if (_controller.text.trim().isEmpty) return;
    final content = _controller.text;
    _controller.clear();

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? ''
        },
        body: json.encode({
          'recipientId': widget.partnerId,
          'content': content
        }),
      );

      if (response.statusCode == 200) {
        final newMessage = Message.fromJson(json.decode(response.body));
        setState(() {
          _messages.add(newMessage);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print("Error sending message: $e");
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final myId = Provider.of<AuthProvider>(context, listen: false).user?.id;

    return Scaffold(
      appBar: AppBar(title: Text(widget.partnerName)),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg.sender.id == myId;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.blue : Colors.grey[300],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      msg.content,
                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}