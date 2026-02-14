// e:\FirstApp\flutter_application_1\lib\models\comment.dart
import 'user.dart';

class Comment {
  final String id;
  final User author;
  final String content;
  final String timestamp;
  final List<dynamic> reactions; // List of {user: id, type: string}
  final String? parentId;
  final List<Comment> replies;
  final int editCount;

  Comment({
    required this.id,
    required this.author,
    required this.content,
    required this.timestamp,
    this.reactions = const [],
    this.parentId,
    this.replies = const [],
    this.editCount = 0,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    return Comment(
      id: json['_id'] ?? json['id'] ?? '',
      author: json['author'] != null 
          ? User.fromJson(json['author']) 
          : User(id: 'unknown', name: 'Unknown', username: 'unknown'),
      content: json['content'] ?? '',
      timestamp: json['createdAt'] ?? DateTime.now().toIso8601String(),
      reactions: json['reactions'] ?? [],
      parentId: json['parentId'],
      replies: (json['replies'] != null)
          ? (json['replies'] as List).map((i) => Comment.fromJson(i)).toList()
          : [],
      editCount: json['editCount'] ?? 0,
    );
  }
}
