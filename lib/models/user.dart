class User {
  final String id;
  final String name;
  final String username;
  final String? avatar;
  final String? bio;
  final String? cover;

  User({
    required this.id,
    required this.name,
    required this.username,
    this.avatar,
    this.bio,
    this.cover,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? json['full_name'] ?? 'Unknown',
      username: json['username'] ?? '',
      avatar: json['avatar'] ?? json['avatar_url'],
      bio: json['bio'],
      cover: json['cover'],
    );
  }
}