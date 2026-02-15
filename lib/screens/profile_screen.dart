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
  List<Post> _userSaved = []; // Thêm list saved posts
  int _selectedIndex = 0; // Tab index

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
    _fetchUserPosts();
    _fetchUserShares();
    _fetchUserSaved();
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

  Future<void> _fetchUserSaved() async {
    // Chỉ fetch saved posts nếu là profile của chính mình
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (widget.userId != null && widget.userId != authProvider.user?.id) return;

    try {
      final response = await http.get(Uri.parse('$API_URL/api/posts/saved'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _userSaved = data.map((json) => Post.fromJson(json)).toList();
        });
      }
    } catch (e) {
      print("Error fetching saved posts: $e");
    }
  }

  void _showImagePickerOptions(String type) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Chọn từ thư viện'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.gallery, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Chụp ảnh mới'),
                onTap: () {
                  Navigator.pop(context);
                  _uploadImage(ImageSource.camera, type);
                },
              ),
              ListTile(
                leading: const Icon(Icons.collections),
                title: const Text('Chọn từ bộ sưu tập đã tải lên'),
                onTap: () {
                  Navigator.pop(context);
                  _showCollectionPicker(type);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _uploadImage(ImageSource source, String type, {String? existingUrl}) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    
    // Nếu chọn từ collection (có URL sẵn)
    if (existingUrl != null) {
       // Gọi API update profile với URL có sẵn (cần backend hỗ trợ update avatar bằng string URL, 
       // hoặc ta tái sử dụng logic upload nhưng gửi URL. Ở đây giả định backend route upload/avatar chỉ nhận file.
       // Ta sẽ cần 1 route update profile riêng hoặc sửa route upload.
       // Đơn giản nhất: Gọi route update-profile trong users.js (đã tạo ở bước trước)
       // Nhưng route đó chưa handle avatar/cover url string.
       // Tạm thời ta bỏ qua logic update bằng URL string ở đây để tập trung vào upload file.
       // Để fix triệt để: Backend cần route PUT /api/users/me { avatar_url: "..." }
       return; 
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      
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

  Future<void> _showCollectionPicker(String type) async {
    final token = Provider.of<AuthProvider>(context, listen: false).token;
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/upload/collection'),
        headers: {'x-auth-token': token ?? ''},
      );
      if (response.statusCode == 200) {
        final List<dynamic> images = json.decode(response.body);
        if (!mounted) return;
        
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text("Bộ sưu tập của bạn", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Expanded(
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
                    itemCount: images.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          // Logic update avatar bằng URL (cần backend hỗ trợ update string URL)
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tính năng chọn từ collection đang được cập nhật backend")));
                        },
                        child: CachedNetworkImage(imageUrl: images[index], fit: BoxFit.cover),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) { print(e); }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Đã cập nhật trạng thái theo dõi!")),
        );
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
            expandedHeight: 220.0, 
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
                children: [
                  user.cover != null
                      ? CachedNetworkImage(
                          imageUrl: user.cover!,
                          fit: BoxFit.cover,
                          errorWidget: (context, url, error) => Container(color: Colors.grey),
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
                  if (isMe)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => _showImagePickerOptions('cover'),
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
                  // Avatar Overlap Logic
                  Transform.translate(
                    offset: const Offset(0, 5), // Đẩy avatar lên 60px (1/2 chiều cao 120px) để nằm chính giữa
                    child: Center(
                      child: GestureDetector(
                        onTap: isMe ? () => _showImagePickerOptions('avatar') : null,
                        child: Container(
                          padding: const EdgeInsets.all(4), // Viền trắng
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF111827) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          // Yêu cầu 2: Load data url ảnh từ database
                          child: ClipOval(
                            child: (user.avatar != null && user.avatar!.isNotEmpty)
                                ? CachedNetworkImage(
                                    imageUrl: user.avatar!,
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) => const Icon(Icons.person, size: 60),
                                  )
                                : const SizedBox(width: 120, height: 120, child: Icon(Icons.person, size: 60)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Thông tin Profile (đã trừ khoảng overlap bằng Transform)
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
                  
                  // Tabs
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildTabItem("Bài viết", 0, isDark),
                      _buildTabItem("Đã chia sẻ", 1, isDark),
                      if (isMe) _buildTabItem("Đã lưu", 2, isDark),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Content List
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _selectedIndex == 0 
                        ? _userPosts.length 
                        : (_selectedIndex == 1 ? _userShares.length : _userSaved.length),
                    itemBuilder: (context, index) {
                      final post = _selectedIndex == 0 
                          ? _userPosts[index] 
                          : (_selectedIndex == 1 ? _userShares[index] : _userSaved[index]);
                      return PostCard(post: post);
                    },
                  ),
                  if ((_selectedIndex == 0 && _userPosts.isEmpty) ||
                      (_selectedIndex == 1 && _userShares.isEmpty) ||
                      (_selectedIndex == 2 && _userSaved.isEmpty))
                    const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("Chưa có nội dung nào.", style: TextStyle(color: Colors.grey)),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String label, int index, bool isDark) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          border: isSelected ? Border(bottom: BorderSide(color: Colors.blue, width: 2)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.blue : (isDark ? Colors.grey : Colors.black54),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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