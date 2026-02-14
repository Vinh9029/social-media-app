import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../models/post.dart';
import '../screens/post_detail_screen.dart';
import '../providers/auth_provider.dart';
import '../config.dart';

class PostCard extends StatefulWidget {
  final Post post;
  final bool isDetail; // Flag để biết đang ở màn hình detail

  const PostCard({super.key, required this.post, this.isDetail = false});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likesCount;
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likes;
    // Logic kiểm tra đã like/save chưa. 
    // Do Post model hiện tại chưa có field isLiked/isSaved rõ ràng trong context,
    // ta tạm thời để false hoặc cần update Post model.
    // Giả sử logic check nằm ở đây nếu có data.
  }

  Future<void> _toggleLike() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() {
      _isLiked = !_isLiked;
      _likesCount += _isLiked ? 1 : -1;
    });

    try {
      await http.put(
        Uri.parse('$API_URL/api/posts/${widget.post.id}/like'),
        headers: {'x-auth-token': token},
      );
    } catch (e) {
      print("Like error: $e");
      // Revert nếu lỗi
      setState(() {
        _isLiked = !_isLiked;
        _likesCount += _isLiked ? 1 : -1;
      });
    }
  }

  Future<void> _savePost() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isSaved = !_isSaved);

    try {
      await http.put(
        Uri.parse('$API_URL/api/posts/${widget.post.id}/save'),
        headers: {'x-auth-token': token},
      );
    } catch (e) {
      print("Save error: $e");
      setState(() => _isSaved = !_isSaved);
    }
  }

  Future<void> _sharePost() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    try {
      await http.post(
        Uri.parse('$API_URL/api/posts/${widget.post.id}/share'),
        headers: {'x-auth-token': token},
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Đã chia sẻ bài viết!")),
      );
    } catch (e) {
      print("Share error: $e");
    }
  }

  String _formatDate(String timestamp) {
    // Simple date formatting logic
    try {
      final date = DateTime.parse(timestamp);
      final now = DateTime.now();
      final diff = now.difference(date);
      if (diff.inDays > 0) return '${diff.inDays} ngày trước';
      if (diff.inHours > 0) return '${diff.inHours} giờ trước';
      if (diff.inMinutes > 0) return '${diff.inMinutes} phút trước';
      return 'Vừa xong';
    } catch (e) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: widget.isDetail ? null : () async {
        // Await kết quả trả về từ Detail Screen để sync data
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
        );
        if (result == true) {
          // Nếu có thay đổi (ví dụ comment), reload hoặc update state
          // Ở đây ta giả lập tăng comment count hoặc cần fetch lại post
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/profile',
                      arguments: widget.post.author.id,
                    );
                  },
                  child: (widget.post.author.avatar != null && widget.post.author.avatar!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: widget.post.author.avatar!,
                          imageBuilder: (context, imageProvider) => CircleAvatar(
                            radius: 22,
                            backgroundImage: imageProvider,
                          ),
                          placeholder: (context, url) => const CircleAvatar(radius: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                          errorWidget: (context, url, error) => const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                        )
                      : const CircleAvatar(radius: 22, child: Icon(Icons.person)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/profile',
                        arguments: widget.post.author.id,
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.post.author.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Text(
                          '@${widget.post.author.username} • ${_formatDate(widget.post.timestamp)}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Edit Button Logic (Giả lập editCount < 3)
                PopupMenuButton<String>(
                  icon: const Icon(LucideIcons.moreHorizontal, color: Colors.grey),
                  onSelected: (value) {
                    if (value == 'edit') {
                      // Handle edit post logic
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'edit', child: Text('Chỉnh sửa bài viết')),
                    const PopupMenuItem<String>(value: 'delete', child: Text('Xóa bài viết')),
                  ],
                ),
              ],
            ),
            
            // Content
            const SizedBox(height: 12),
            Text(
              widget.post.content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),

            // Image
            if (widget.post.image != null && widget.post.image!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: widget.post.image!,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey[200],
                  ),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
            ],

            // Actions
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(
                  icon: _isLiked ? Icons.favorite : LucideIcons.heart,
                  label: '$_likesCount',
                  color: _isLiked ? Colors.red : Colors.grey[600],
                  onTap: _toggleLike,
                ),
                _buildActionButton(
                  icon: LucideIcons.messageCircle,
                  label: '${widget.post.comments}',
                  onTap: () async {
                    if (!widget.isDetail) {
                       await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
                      );
                    }
                  },
                ),
                _buildActionButton(icon: LucideIcons.share2, label: '${widget.post.shares}', onTap: _sharePost),
                _buildActionButton(
                  icon: _isSaved ? Icons.bookmark : LucideIcons.bookmark, 
                  label: '', 
                  color: _isSaved ? Colors.blue : Colors.grey[600],
                  onTap: _savePost
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, Color? color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color ?? Colors.grey[600]),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color ?? Colors.grey[600])),
            ],
          ],
        ),
      ),
    );
  }
}