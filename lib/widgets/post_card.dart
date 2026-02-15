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
  final Function(Post)? onPostUpdated; // Callback để báo cho cha biết có thay đổi (dùng trong detail)
  final Function(String)? onPostDeleted; // Callback khi xóa bài

  const PostCard({super.key, required this.post, this.isDetail = false, this.onPostUpdated, this.onPostDeleted});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _likesCount;
  late int _commentsCount;
  late int _sharesCount;
  bool _isLiked = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _likesCount = widget.post.likes;
    _commentsCount = widget.post.comments;
    _sharesCount = widget.post.shares;
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
    _notifyUpdate();

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
      _notifyUpdate();
    }
  }

  Future<void> _savePost() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    if (token == null) return;

    setState(() => _isSaved = !_isSaved);

    // Gọi API Save
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
      setState(() {
        _sharesCount += 1;
      });
      _notifyUpdate();
    } catch (e) {
      print("Share error: $e");
    }
  }

  // Hàm edit bài viết
  Future<void> _editPost(String newContent) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.put(
        Uri.parse('$API_URL/api/posts/${widget.post.id}'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
        body: json.encode({'content': newContent}),
      );

      if (response.statusCode == 200) {
        // Cập nhật UI tạm thời (hoặc parse response để lấy data mới)
        // Ở đây ta không thể sửa widget.post.content vì nó là final, 
        // nhưng trong thực tế nên reload lại list hoặc dùng state management.
        // Để đơn giản, ta thông báo thành công.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã cập nhật bài viết")));
        // Nếu muốn UI cập nhật text ngay, cần chuyển content vào State variable tương tự likeCount.
      }
    } catch (e) {
      print("Edit error: $e");
    }
  }

  // Hàm xóa bài viết
  Future<void> _deletePost() async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.delete(
        Uri.parse('$API_URL/api/posts/${widget.post.id}'),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã xóa bài viết")));
        if (widget.onPostDeleted != null) {
          widget.onPostDeleted!(widget.post.id);
        }
      }
    } catch (e) {
      print("Delete error: $e");
    }
  }

  void _showEditDialog() {
    final controller = TextEditingController(text: widget.post.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Chỉnh sửa bài viết"),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _editPost(controller.text);
            },
            child: const Text("Lưu"),
          )
        ],
      ),
    );
  }

  // UI/UX: Bottom Sheet thay vì PopupMenu
  void _showOptionsBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(LucideIcons.edit, color: Colors.blue),
                title: const Text('Chỉnh sửa bài viết'),
                onTap: () {
                  Navigator.pop(context);
                  _showEditDialog();
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.trash2, color: Colors.red),
                title: const Text('Xóa bài viết', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Xác nhận xóa"),
                      content: const Text("Bạn có chắc chắn muốn xóa bài viết này không?"),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _deletePost();
                          },
                          child: const Text("Xóa", style: TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  // Helper để báo cho PostDetailScreen biết có thay đổi
  void _notifyUpdate() {
    if (widget.onPostUpdated != null) {
      // Tạo một bản sao Post mới với dữ liệu đã update
      // Lưu ý: Post model cần có method copyWith hoặc tạo mới thủ công
      // Ở đây ta tạo thủ công dựa trên model hiện có
      
      Post updatedPost = Post(
        id: widget.post.id,
        author: widget.post.author,
        content: widget.post.content, // Nếu có edit content thì lấy từ state
        image: widget.post.image,
        likes: _likesCount,
        comments: _commentsCount,
        shares: _sharesCount,
        timestamp: widget.post.timestamp
      );
      widget.onPostUpdated!(updatedPost);
     
      // Do class Post không có copyWith trong context, ta truyền tạm object cũ 
      // nhưng PostDetailScreen sẽ cần các biến count riêng.
      // Cách đơn giản nhất cho bài toán này: PostDetailScreen tự quản lý state count
      // và truyền callback xuống đây để update state đó.
      
      // Gọi callback đơn giản để báo cha update (nếu cha quản lý state)
      widget.onPostUpdated!(widget.post); 
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
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final isMe = currentUser?.id == widget.post.author.id;

    return GestureDetector(
      onTap: widget.isDetail ? null : () async {
        // Await kết quả trả về từ Detail Screen để sync data
        final updatedData = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
        );
        
        // Nếu có dữ liệu trả về (Map chứa các count mới)
        if (updatedData != null && updatedData is Map<String, dynamic>) {
          setState(() {
            if (updatedData.containsKey('likes')) _likesCount = updatedData['likes'];
            if (updatedData.containsKey('comments')) _commentsCount = updatedData['comments'];
            if (updatedData.containsKey('shares')) _sharesCount = updatedData['shares'];
            if (updatedData.containsKey('isLiked')) _isLiked = updatedData['isLiked'];
            if (updatedData.containsKey('isSaved')) _isSaved = updatedData['isSaved'];
          });
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
                if (isMe)
                  IconButton(
                    icon: const Icon(LucideIcons.moreHorizontal, color: Colors.grey),
                    onPressed: _showOptionsBottomSheet,
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
                  label: '$_commentsCount',
                  onTap: () async {
                    if (!widget.isDetail) {
                       final updatedData = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PostDetailScreen(post: widget.post)),
                      );
                       if (updatedData != null && updatedData is Map<String, dynamic>) {
                          setState(() {
                            if (updatedData.containsKey('likes')) _likesCount = updatedData['likes'];
                            if (updatedData.containsKey('comments')) _commentsCount = updatedData['comments'];
                            if (updatedData.containsKey('shares')) _sharesCount = updatedData['shares'];
                            if (updatedData.containsKey('isLiked')) _isLiked = updatedData['isLiked'];
                          });
                       }
                    }
                  },
                ),
                _buildActionButton(icon: LucideIcons.share2, label: '$_sharesCount', onTap: _sharePost),
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