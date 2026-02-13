// e:\FirstApp\flutter_application_1\lib\models\comment.dart
import 'user.dart';

class Comment {
  final String id;
  final User author;
  final String content;
  final String timestamp;
  final int likes;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp,
    this.likes = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? json['id'] ?? '',
      author: json['author'] != null 
          ? User.fromJson(json['author']) 
          : User(id: 'unknown', name: 'Unknown', username: 'unknown'),
      content: json['content'] ?? '',
      timestamp: json['createdAt'] ?? DateTime.now().toIso8601String(),
      likes: (json['likes'] is List) ? (json['likes'] as List).length : 0,
    );
  }
}
