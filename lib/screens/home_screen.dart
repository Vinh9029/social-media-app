import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config.dart';
import '../../models/post.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/post_card.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  final _postController = TextEditingController();
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final response = await http.get(Uri.parse('$API_URL/api/posts'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _posts = data.map((json) => Post.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error fetching posts: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createPost() async {
    if (_postController.text.isEmpty && _selectedImage == null) return;
    
    setState(() => _isLoading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    String? imageUrl;

    // 1. Upload ảnh nếu có
    if (_selectedImage != null) {
      try {
        var request = http.MultipartRequest('POST', Uri.parse('$API_URL/api/upload/post'));
        request.headers['x-auth-token'] = token ?? '';
        request.files.add(await http.MultipartFile.fromPath('image', _selectedImage!.path));
        var res = await request.send();
        if (res.statusCode == 200) {
          var resString = await res.stream.bytesToString();
          imageUrl = json.decode(resString)['url'];
        }
      } catch (e) {
        print("Upload post image error: $e");
      }
    }

    // 2. Tạo bài viết
    try {
      await http.post(
        Uri.parse('$API_URL/api/posts'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? ''
        },
        body: json.encode({
          'content': _postController.text,
          'image_url': imageUrl
        }),
      );
      _postController.clear();
      setState(() => _selectedImage = null);
      _fetchPosts(); // Reload feed
    } catch (e) {
      print("Create post error: $e");
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _selectedImage = File(pickedFile.path));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: _fetchPosts,
      child: Column(
        children: [
          // Create Post Widget
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        decoration: const InputDecoration(
                          hintText: 'Bạn đang nghĩ gì?',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.image, color: Colors.blue), onPressed: _pickImage),
                    IconButton(icon: const Icon(Icons.send, color: Colors.blue), onPressed: _createPost),
                  ],
                ),
                if (_selectedImage != null)
                  Stack(
                    children: [
                      Image.file(_selectedImage!, height: 100),
                      Positioned(
                        right: 0,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => setState(() => _selectedImage = null),
                        ),
                      )
                    ],
                  )
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _posts.length,
              itemBuilder: (context, index) {
                return PostCard(post: _posts[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}