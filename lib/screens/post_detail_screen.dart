// e:\FirstApp\flutter_application_1\lib\screens\post_detail_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/post.dart';
import '../models/comment.dart';
import '../providers/auth_provider.dart';
import '../widgets/post_card.dart';

class PostDetailScreen extends StatefulWidget {
  final Post post;

  const PostDetailScreen({super.key, required this.post});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  List<Comment> _comments = [];
  bool _isLoadingComments = true;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _replyingToId; // ID của comment đang được reply
  String? _editingCommentId; // ID của comment đang edit

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      // Sử dụng route của comments.js (giả định mount tại /api/comments)
      final response = await http.get(Uri.parse('$API_URL/api/comments/post/${widget.post.id}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _comments = data.map((json) => Comment.fromJson(json)).toList();
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      print("Error fetching comments: ");
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment({String? parentId}) async {
    if (_commentController.text.trim().isEmpty) return;
    final content = _commentController.text;
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    // Logic Edit
    if (_editingCommentId != null) {
      try {
        await http.put(
          Uri.parse('$API_URL/api/comments/$_editingCommentId'),
          headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
          body: json.encode({'content': content}),
        );
        _commentController.clear();
        setState(() => _editingCommentId = null);
        FocusScope.of(context).unfocus();
        _fetchComments(); // Reload để cập nhật UI
      } catch (e) {
        print("Error editing: $e");
      }
      return;
    }

    // Logic Post New / Reply
    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/comments/post/${widget.post.id}'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? ''
        },
        body: json.encode({'content': content, 'parentId': parentId ?? _replyingToId}),
      );

      if (response.statusCode == 200) {
        final newComment = Comment.fromJson(json.decode(response.body));
        setState(() {
          // Thêm vào đầu danh sách hoặc reload lại để có đúng thứ tự tree
          _comments.insert(0, newComment);
          _replyingToId = null;
          _commentController.clear();
        });
        FocusScope.of(context).unfocus();
        Future.delayed(const Duration(milliseconds: 100), () {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      print("Error posting comment: ");
    }
  }

  Future<void> _reactToComment(String commentId, String type) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      await http.put(
        Uri.parse('$API_URL/api/comments/$commentId/reaction'),
        headers: {'Content-Type': 'application/json', 'x-auth-token': token ?? ''},
        body: json.encode({'type': type}),
      );
      _fetchComments(); // Reload reactions
    } catch (e) {
      print("React error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sử dụng PopScope để trả về dữ liệu khi back
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        // Trả về post hiện tại (hoặc updated data nếu có logic update post ở đây)
        // Ở đây ta giả định comment count thay đổi, ta trả về true để PostCard reload
        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Chi tiết bài viết')),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                child: Column(
                  children: [
                    // Cho phép tương tác với PostCard (like, share) ngay trong detail
                    PostCard(post: widget.post, isDetail: true),
                    const Divider(),
                    if (_isLoadingComments)
                      const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                    else if (_comments.isEmpty)
                      const Padding(padding: EdgeInsets.all(20), child: Text("Chưa có bình luận nào."))
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          return _buildCommentItem(_comments[index]);
                        },
                      ),
                  ],
                ),
              ),
            ),
            _buildBottomInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildReactionButton(Comment comment) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    // Tìm reaction của user hiện tại
    final myReaction = comment.reactions.firstWhere(
      (r) => r['user'] == currentUser?.id,
      orElse: () => null,
    );

    IconData icon = Icons.thumb_up_outlined;
    Color color = Colors.grey;
    String text = "Thích";

    if (myReaction != null) {
      switch (myReaction['type']) {
        case 'love': icon = Icons.favorite; color = Colors.red; text = "Yêu thích"; break;
        case 'haha': icon = Icons.sentiment_very_satisfied; color = Colors.orange; text = "Haha"; break;
        case 'sad': icon = Icons.sentiment_dissatisfied; color = Colors.blue; text = "Buồn"; break;
        case 'angry': icon = Icons.sentiment_very_dissatisfied; color = Colors.red[900]!; text = "Phẫn nộ"; break;
        default: icon = Icons.thumb_up; color = Colors.blue; text = "Thích";
      }
    }

    return GestureDetector(
      onTap: () => _reactToComment(comment.id, 'like'),
      onLongPress: () {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            content: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _reactionIcon(Icons.thumb_up, Colors.blue, 'like', comment.id),
                _reactionIcon(Icons.favorite, Colors.red, 'love', comment.id),
                _reactionIcon(Icons.sentiment_very_satisfied, Colors.orange, 'haha', comment.id),
                _reactionIcon(Icons.sentiment_dissatisfied, Colors.blue, 'sad', comment.id),
                _reactionIcon(Icons.sentiment_very_dissatisfied, Colors.red[900]!, 'angry', comment.id),
              ],
            ),
          ),
        );
      },
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _reactionIcon(IconData icon, Color color, String type, String commentId) {
    return GestureDetector(
      onTap: () {
        _reactToComment(commentId, type);
        Navigator.pop(context);
      },
      child: Icon(icon, color: color, size: 30),
    );
  }

  Widget _buildCommentItem(Comment comment, {double indent = 0}) {
    final currentUser = Provider.of<AuthProvider>(context, listen: false).user;
    final isMe = currentUser?.id == comment.author.id;
    final canEdit = isMe && comment.editCount < 3;

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16 + indent, right: 16, top: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 18,
                backgroundImage: comment.author.avatar != null
                    ? CachedNetworkImageProvider(comment.author.avatar!)
                    : null,
                child: comment.author.avatar == null ? const Icon(Icons.person, size: 18) : null,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(comment.author.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          const SizedBox(height: 4),
                          Text(comment.content, style: const TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, left: 8),
                      child: Row(
                        children: [
                          Text(
                            DateTime.parse(comment.timestamp).toLocal().toString().substring(0, 16),
                            style: TextStyle(color: Colors.grey[600], fontSize: 11)
                          ),
                          const SizedBox(width: 12),
                          _buildReactionButton(comment),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _replyingToId = comment.id;
                                _editingCommentId = null;
                              });
                              _commentController.text = "";
                              FocusScope.of(context).requestFocus();
                            },
                            child: Text("Phản hồi", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                          if (canEdit) ...[
                            const SizedBox(width: 12),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _editingCommentId = comment.id;
                                  _replyingToId = null;
                                });
                                _commentController.text = comment.content;
                                FocusScope.of(context).requestFocus();
                              },
                              child: Text("Sửa", style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12)),
                            ),
                          ],
                          if (comment.reactions.isNotEmpty) ...[
                            const Spacer(),
                            const Icon(Icons.thumb_up, size: 12, color: Colors.blue),
                            const SizedBox(width: 2),
                            Text("${comment.reactions.length}", style: const TextStyle(fontSize: 12)),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Hiển thị Replies (đệ quy hoặc loop)
        if (comment.replies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Column(
              children: comment.replies.map((reply) => _buildCommentItem(reply, indent: indent + 40)).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildBottomInput() {
    final isReplying = _replyingToId != null;
    final isEditing = _editingCommentId != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Column(
        children: [
          if (isReplying || isEditing)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isReplying ? Colors.blue[50] : Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isReplying ? Colors.blue[200]! : Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(isReplying ? Icons.reply : Icons.edit, size: 16, color: isReplying ? Colors.blue : Colors.orange),
                  const SizedBox(width: 8),
                  Text(isReplying ? "Đang trả lời bình luận..." : "Đang chỉnh sửa...", style: TextStyle(color: Colors.grey[800], fontSize: 13, fontWeight: FontWeight.w500)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { _replyingToId = null; _editingCommentId = null; _commentController.clear(); }), 
                    child: const Icon(Icons.close, size: 18, color: Colors.grey)
                  )
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: isReplying ? 'Viết câu trả lời...' : 'Viết bình luận...',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 22,
                child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: () => _submitComment()),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
