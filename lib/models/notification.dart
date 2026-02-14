class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String avatar;
  final bool isNew;
  final String? type;
  final String? targetId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.avatar,
    this.isNew = false,
    this.type,
    this.targetId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      avatar: json['avatar'] ?? '',
      isNew: json['isNew'] ?? false,
      type: json['type'],
      targetId: json['targetId'],
    );
  }
}
