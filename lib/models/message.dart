import 'user.dart';

class Message {
  final String id;
  final User sender;
  final String content;
  final String timestamp;
  final String type; // 'text', 'image', 'sticker'

  Message({
    required this.id,
    required this.sender,
    required this.content,
    required this.timestamp,
    this.type = 'text',
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      sender: json['sender'] != null 
          ? User.fromJson(json['sender']) 
          : User(id: 'unknown', name: 'Unknown', username: 'unknown'),
      content: json['content'] ?? '',
      timestamp: json['createdAt'] ?? DateTime.now().toIso8601String(),
      type: json['type'] ?? 'text',
    );
  }
}

class Conversation {
  final String partnerId;
  final String name;
  final String username;
  final String? avatar;
  final String lastMessage;
  final String timestamp;

  Conversation({required this.partnerId, required this.name, required this.username, this.avatar, required this.lastMessage, required this.timestamp});

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      partnerId: json['partnerId'] ?? '',
      name: json['name'] ?? 'Unknown',
      username: json['username'] ?? '',
      avatar: json['avatar'],
      lastMessage: json['lastMessage'] ?? '',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
    );
  }
}