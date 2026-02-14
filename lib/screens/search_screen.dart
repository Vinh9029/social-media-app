import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_icons/lucide_icons.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config.dart';
import '../models/post.dart';
import '../models/user.dart';
import '../widgets/post_card.dart';
import 'profile_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<User> _userResults = [];
  List<Post> _postResults = [];
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _performSearch(_searchController.text);
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _userResults = [];
        _postResults = [];
      });
      return;
    }

    setState(() => _isLoading = true);

    try {
      String type = 'all';
      if (_tabController.index == 1) type = 'posts';
      if (_tabController.index == 2) type = 'users';

      final response = await http.get(
        Uri.parse('$API_URL/api/search?q=$query&type=$type'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _userResults = (data['users'] as List)
              .map((json) => User.fromJson(json))
              .toList();
          _postResults = (data['posts'] as List)
              .map((json) => Post.fromJson(json))
              .toList();
        });
      }
    } catch (e) {
      print("Search error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            hintText: 'Tìm kiếm bài viết, người dùng...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(color: Colors.black),
          autofocus: false,
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: 'Tất cả'),
            Tab(text: 'Bài viết'),
            Tab(text: 'Mọi người'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildAllResults(),
                _buildPostList(),
                _buildUserList(),
              ],
            ),
    );
  }

  Widget _buildAllResults() {
    if (_userResults.isEmpty && _postResults.isEmpty) {
      return const Center(child: Text('Không tìm thấy kết quả'));
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_userResults.isNotEmpty) ...[
            const Text('Mọi người', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ..._userResults.map((user) => _buildUserTile(user)),
            const SizedBox(height: 20),
          ],
          if (_postResults.isNotEmpty) ...[
            const Text('Bài viết', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 10),
            ..._postResults.map((post) => PostCard(post: post)),
          ],
        ],
      ),
    );
  }

  Widget _buildPostList() {
    if (_postResults.isEmpty) return const Center(child: Text('Không có bài viết nào'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _postResults.length,
      itemBuilder: (context, index) => PostCard(post: _postResults[index]),
    );
  }

  Widget _buildUserList() {
    if (_userResults.isEmpty) return const Center(child: Text('Không tìm thấy người dùng'));
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _userResults.length,
      itemBuilder: (context, index) => _buildUserTile(_userResults[index]),
    );
  }

  Widget _buildUserTile(User user) {
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: (user.avatar != null && user.avatar!.isNotEmpty)
            ? CachedNetworkImage(
                imageUrl: user.avatar!,
                imageBuilder: (context, imageProvider) => CircleAvatar(backgroundImage: imageProvider),
                placeholder: (context, url) => const CircleAvatar(child: CircularProgressIndicator(strokeWidth: 2)),
                errorWidget: (context, url, error) => const CircleAvatar(child: Icon(Icons.person)),
              )
            : const CircleAvatar(child: Icon(Icons.person)),
        title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('@${user.username}'),
        trailing: const Icon(LucideIcons.chevronRight, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileScreen(userId: user.id),
            ),
          );
        },
      ),
    );
  }
}