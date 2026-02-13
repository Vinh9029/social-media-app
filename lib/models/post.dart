import 'user.dart';

class Post {
  final String id;
  final String content;
  final String? image;
  final User author;
  final String timestamp;
  final int likes;
  final int comments;
  final int shares;

  Post({
    required this.id,
    required this.content,
    this.image,
    required this.author,
    required this.timestamp,
    this.likes = 0,
    this.comments = 0,
    this.shares = 0,
  });

  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['_id'] ?? json['id'] ?? '',
      content: json['content'] ?? '',
      image: json['image'] ?? json['image_url'],
      author: json['author'] != null 
          ? User.fromJson(json['author']) 
          : User(id: 'unknown', name: 'Unknown', username: 'unknown'),
      timestamp: json['timestamp'] ?? json['createdAt'] ?? DateTime.now().toIso8601String(),
      likes: (json['likes'] is List) 
          ? (json['likes'] as List).length 
          : (json['likes'] ?? 0),
      comments: json['comments'] ?? 0,
      shares: json['shares'] ?? 0,
    );
  }
}