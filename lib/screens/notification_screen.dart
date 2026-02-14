import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/notification.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import 'profile_screen.dart';
import 'post_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});
  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/notifications'),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _notifications = data.map((json) => NotificationModel.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching notifications: $e');
      setState(() => _isLoading = false);
    }
  }

  // Hàm hỗ trợ lấy chi tiết bài viết rồi mới điều hướng
  Future<void> _fetchPostAndNavigate(String postId) async {
    setState(() => _isLoading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/posts/$postId'),
        headers: {'x-auth-token': token ?? ''},
      );

      if (response.statusCode == 200) {
        final postData = json.decode(response.body);
        final post = Post.fromJson(postData);
        
        if (mounted) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetailScreen(post: post)));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bài viết không tồn tại hoặc đã bị xóa")));
      }
    } catch (e) {
      print("Error fetching post: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleNotificationTap(NotificationModel n) async {
    // 1. Đánh dấu đã đọc (Cập nhật UI trước cho mượt)
    if (n.isNew) {
      setState(() {
        // Tạo bản sao mới với isNew = false
        final index = _notifications.indexOf(n);
        if (index != -1) {
          // Lưu ý: NotificationModel cần bỏ final hoặc tạo method copyWith để sửa đổi chuẩn hơn
          // Ở đây ta giả định fetch lại hoặc backend tự update khi click
        }
      });
      
      // Gọi API đánh dấu đã đọc (nếu backend hỗ trợ route này)
      // await http.put(Uri.parse('$API_URL/api/notifications/${n.id}/read'));
    }

    // 2. Điều hướng theo Use Cases
    // + Follow: Dẫn đến Profile user đó
    if (n.title.toLowerCase().contains('follow') || n.body.toLowerCase().contains('theo dõi')) {
       if (n.senderId != null) {
         Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: n.senderId)));
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Không tìm thấy người dùng")));
       }
       return;
    }

    // + Reaction: Unclickable
    if (n.title.contains('Thích')) {
      return;
    }

    // + Comment/Reply: Dẫn đến Post Detail
    if (n.title.contains('Bình luận') || n.body.contains('trả lời')) {
       if (n.postId != null) {
         await _fetchPostAndNavigate(n.postId!);
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bài viết không xác định")));
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: _notifications.isEmpty
          ? const Center(child: Text('Không có thông báo nào'))
          : ListView.separated(
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final n = _notifications[index];
                return ListTile(
                  tileColor: n.isNew ? Colors.blue.withOpacity(0.05) : null, // Highlight tin chưa đọc
                  leading: n.avatar.isNotEmpty
                      ? CircleAvatar(backgroundImage: NetworkImage(n.avatar))
                      : const CircleAvatar(child: Icon(Icons.notifications)),
                  title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(n.body),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(n.timestamp.substring(0, 10), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                      if (n.isNew) const Icon(Icons.circle, color: Colors.blue, size: 10),
                    ],
                  ),
                  onTap: () => _handleNotificationTap(n),
                );
              },
            ),
    );
  }
}
