class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String avatar;
  final String timestamp;
  final bool isNew;
  final String? senderId;
  final String? postId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.avatar,
    required this.timestamp,
    required this.isNew,
    this.senderId,
    this.postId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Thông báo',
      body: json['body'] ?? '',
      avatar: json['avatar'] ?? '',
      timestamp: json['timestamp'] ?? '',
      isNew: json['isNew'] ?? false,
      senderId: json['senderId'],
      postId: json['postId'],
    );
  }
}