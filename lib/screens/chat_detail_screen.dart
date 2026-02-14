import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool _showStickers = false;

  // Danh sách sticker mẫu (bạn có thể thay bằng link ảnh thật của bạn)
  final List<String> _stickers = [
    'https://cdn-icons-png.flaticon.com/128/742/742751.png', // Smile
    'https://cdn-icons-png.flaticon.com/128/742/742752.png', // Sad
    'https://cdn-icons-png.flaticon.com/128/742/742920.png', // Love
    'https://cdn-icons-png.flaticon.com/128/742/742760.png', // Angry
  ];

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

  Future<void> _sendMessage({String? content, String type = 'text', XFile? imageFile}) async {
    if ((content == null || content.trim().isEmpty) && imageFile == null) return;
    
    if (type == 'text') _controller.clear();

    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      var request = http.MultipartRequest('POST', Uri.parse('$API_URL/api/messages'));
      request.headers['x-auth-token'] = token ?? '';
      request.fields['recipientId'] = widget.partnerId;
      request.fields['type'] = type;
      
      if (content != null) {
        request.fields['content'] = content;
      }

      if (imageFile != null) {
        request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

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

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      _sendMessage(imageFile: pickedFile, type: 'image');
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
                    child: msg.type == 'image' || msg.type == 'sticker'
                        ? CachedNetworkImage(
                            imageUrl: msg.content,
                            width: 150,
                            placeholder: (context, url) => const CircularProgressIndicator(),
                            errorWidget: (context, url, error) => const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          )
                        : Text(
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
                IconButton(
                  icon: const Icon(Icons.image, color: Colors.blue),
                  onPressed: _pickImage,
                ),
                IconButton(
                  icon: Icon(Icons.emoji_emotions, color: _showStickers ? Colors.blue : Colors.grey),
                  onPressed: () => setState(() => _showStickers = !_showStickers),
                ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Nhập tin nhắn...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue), 
                  onPressed: () => _sendMessage(content: _controller.text, type: 'text')
                ),
              ],
            ),
          ),
          if (_showStickers)
            Container(
              height: 200,
              color: Colors.grey[100],
              child: GridView.builder(
                padding: const EdgeInsets.all(10),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, crossAxisSpacing: 10, mainAxisSpacing: 10),
                itemCount: _stickers.length,
                itemBuilder: (context, index) {
                  return GestureDetector(
                    onTap: () => _sendMessage(content: _stickers[index], type: 'sticker'),
                    child: Image.network(_stickers[index]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}