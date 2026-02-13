import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _changePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mật khẩu xác nhận không khớp')));
      return;
    }

    setState(() => _isLoading = true);
    final token = Provider.of<AuthProvider>(context, listen: false).token;

    try {
      final response = await http.put(
        Uri.parse('$API_URL/api/auth/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'x-auth-token': token ?? ''
        },
        body: json.encode({
          'currentPassword': _currentPasswordController.text,
          'newPassword': _newPasswordController.text
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đổi mật khẩu thành công')));
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      } else {
        final data = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Lỗi đổi mật khẩu')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lỗi kết nối')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Giao diện
          const Text('Giao diện', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          SwitchListTile(
            title: const Text('Chế độ tối (Dark Mode)'),
            value: themeProvider.isDarkMode,
            onChanged: (value) => themeProvider.toggleTheme(value),
          ),
          const Divider(height: 30),

          // Bảo mật
          const Text('Bảo mật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _currentPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu hiện tại',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Mật khẩu mới',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Xác nhận mật khẩu',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _changePassword,
            child: _isLoading ? const CircularProgressIndicator() : const Text('Đổi mật khẩu'),
          ),
        ],
      ),
    );
  }
}