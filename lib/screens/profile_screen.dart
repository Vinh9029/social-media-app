import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config.dart';
import '../models/user.dart';
import '../../providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
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
    final currentUser = Provider.of<AuthProvider>(context).user;
    final user = _profileUser;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Không tìm thấy người dùng')));
    }

    final isMe = currentUser?.id == user.id;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            leading: isMe ? null : const BackButton(color: Colors.white),
            actions: isMe ? [
              IconButton(
                icon: const Icon(LucideIcons.settings, color: Colors.white),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                },
              )
            ] : null,
            flexibleSpace: FlexibleSpaceBar(
              background: user.cover != null
                  ? CachedNetworkImage(
                      imageUrl: user.cover!,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue, Colors.indigo],
                        ),
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  // Avatar overlap logic
                  Transform.translate(
                    offset: const Offset(0, -50),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: isMe ? () => _uploadImage(ImageSource.gallery, 'avatar') : null,
                          child: Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                ),
                                child: CircleAvatar(
                                  radius: 50,
                                  backgroundImage: user.avatar != null
                                      ? CachedNetworkImageProvider(user.avatar!)
                                      : null,
                                  child: user.avatar == null
                                      ? const Icon(Icons.person, size: 50)
                                      : null,
                                ),
                              ),
                              if (isMe)
                                const Positioned(
                                  bottom: 0, right: 0,
                                  child: CircleAvatar(radius: 16, backgroundColor: Colors.blue, child: Icon(Icons.camera_alt, size: 16, color: Colors.white)),
                                )
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '@${user.username}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatItem('Followers', user.followersCount),
                            const SizedBox(width: 24),
                            _buildStatItem('Following', user.followingCount),
                          ],
                        ),
                        if (user.bio != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                        const SizedBox(height: 20),
                        if (isMe)
                          OutlinedButton.icon(
                            onPressed: () {
                              Provider.of<AuthProvider>(context, listen: false).logout();
                            },
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text('Đăng xuất', style: TextStyle(color: Colors.red)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.red),
                            ),
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                                child: const Text('Theo dõi', style: TextStyle(color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              OutlinedButton(
                                onPressed: _navigateToChat,
                                child: const Text('Nhắn tin'),
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),
                        const Divider(),
                        if (isMe)
                          TextButton.icon(
                            onPressed: () => _uploadImage(ImageSource.gallery, 'cover'),
                            icon: const Icon(Icons.image),
                            label: const Text("Đổi ảnh bìa"),
                          ),
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text("Bài viết (Coming Soon)", style: TextStyle(fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count) {
    return Column(
      children: [
        Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
      ],
    );
  }
}