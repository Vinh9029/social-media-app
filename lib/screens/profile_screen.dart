import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config.dart';
import '../models/user.dart';
import '../models/post.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../../widgets/post_card.dart';
import 'settings_screen.dart';
import 'chat_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId; // Nếu null thì là profile của chính mình

  const ProfileScreen({super.key, this.userId});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _profileUser;
  bool _isLoading = false;
  List<Post> _userPosts = [];
  List<Post> _userShares = [];

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _fetchUserPosts();
    _fetchUserShares();
  }

  Future<void> _fetchProfileData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    // Nếu không có userId hoặc userId trùng với user đang đăng nhập
    if (widget.userId == null || widget.userId == authProvider.user?.id) {
      setState(() {
        _profileUser = authProvider.user;
      });
      return;
    }

    // Fetch user khác
    setState(() => _isLoading = true);
    try {
      // Giả sử backend có endpoint /api/users/:id
      // Nếu chưa có, bạn cần thêm vào backend routes/users.js
      final response = await http.get(Uri.parse('$API_URL/api/users/${widget.userId}'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _profileUser = User.fromJson(data);
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchUserPosts() async {
    if (_profileUser == null) return;
    try {
      final response = await http.get(Uri.parse('$API_URL/api/posts/user/${_profileUser!.id}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userPosts = data.map((json) => Post.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Error fetching user posts: $e");
    }
  }

  Future<void> _fetchUserShares() async {
    if (_profileUser == null) return;
    try {
      final response = await http.get(Uri.parse('$API_URL/api/posts/shared/${_profileUser!.id}'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userShares = data.map((json) => Post.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Error fetching user shares: $e");
    }
  }

  Future<void> _uploadImage(ImageSource source, String type) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      final token = Provider.of<AuthProvider>(context, listen: false).token;
      
      try {
        var request = http.MultipartRequest('POST', Uri.parse('$API_URL/api/upload/$type'));
        request.headers['x-auth-token'] = token ?? '';
        request.files.add(await http.MultipartFile.fromPath(type == 'avatar' ? 'avatar' : 'cover', pickedFile.path));

        var response = await request.send();
        if (response.statusCode == 200) {
          // Reload profile after upload
          await Provider.of<AuthProvider>(context, listen: false).fetchUserProfile();
          _fetchProfileData();
        }
      } catch (e) {
        print("Upload error: $e");
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_profileUser == null) return;
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    
    try {
      final response = await http.put(
        Uri.parse('$API_URL/api/users/follow/${_profileUser!.id}'),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        _fetchProfileData(); // Reload to update counts
      }
    } catch (e) {
      print("Follow error: $e");
    }
  }

  void _navigateToChat() {
    if (_profileUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailScreen(
            partnerId: _profileUser!.id,
            partnerName: _profileUser!.name,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final currentUser = Provider.of<AuthProvider>(context).user;
    final user = _profileUser;
    final isMe = currentUser?.id == user?.id;
    final isDark = themeProvider.isDarkMode;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
        body: const Center(child: Text('Không tìm thấy người dùng')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF111827) : const Color(0xFFF9FAFB),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
            floating: false,
            pinned: true,
            leading: isMe ? null : const BackButton(color: Colors.white),
            actions: isMe
                ? [
                    IconButton(
                      icon: const Icon(LucideIcons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                      },
                    )
                  ]
                : null,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.topCenter,
                children: [
                  user.cover != null
                      ? CachedNetworkImage(
                          imageUrl: user.cover!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark
                                  ? [Colors.blueGrey.shade900, Colors.black]
                                  : [Colors.blue, Colors.indigo],
                            ),
                          ),
                        ),
                  Positioned(
                    top: 180,
                    child: GestureDetector(
                      onTap: isMe ? () => _uploadImage(ImageSource.gallery, 'avatar') : null,
                      child: Material(
                        elevation: 8,
                        shape: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 60,
                          backgroundImage: user.avatar != null
                              ? CachedNetworkImageProvider(user.avatar!)
                              : null,
                          child: user.avatar == null
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                      ),
                    ),
                  ),
                  if (isMe)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _uploadImage(ImageSource.gallery, 'cover'),
                        icon: const Icon(Icons.image, color: Colors.blue),
                        label: const Text("Đổi ảnh bìa", style: TextStyle(color: Colors.blue)),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  const SizedBox(height: 80),
                  Text(
                    user.name,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  Text(
                    '@${user.username}',
                    style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatItem('Followers', user.followersCount, isDark),
                      const SizedBox(width: 24),
                      _buildStatItem('Following', user.followingCount, isDark),
                    ],
                  ),
                  if (user.bio != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      user.bio!,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[200] : Colors.black),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!isMe)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Theo dõi', style: TextStyle(color: Colors.white)),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton(
                          onPressed: _navigateToChat,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            side: const BorderSide(color: Colors.blue),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                          child: const Text('Nhắn tin', style: TextStyle(color: Colors.blue)),
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  const Divider(),
                  // Bài viết
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Bài viết của bạn", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userPosts.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: _userPosts[index]);
                    },
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Bài bạn đã chia sẻ", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _userShares.length,
                    itemBuilder: (context, index) {
                      return PostCard(post: _userShares[index]);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, bool isDark) {
    return Column(
      children: [
        Text(count.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isDark ? Colors.white : Colors.black)),
        Text(label, style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}