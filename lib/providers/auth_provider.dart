import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../config.dart';
import '../../models/user.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _token;
  bool _isLoading = true;

  User? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _token != null;

  AuthProvider() {
    _loadUser();
  }

  Future<void> _loadUser() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    
    if (_token != null) {
      await fetchUserProfile();
    }
    
    _isLoading = false;
    notifyListeners();
  }

  Future<void> fetchUserProfile() async {
    try {
      final response = await http.get(
        Uri.parse('$API_URL/api/auth/me'),
        headers: {'x-auth-token': _token ?? ''},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _user = User.fromJson(data);
      } else {
        logout();
      }
    } catch (e) {
      print("Error fetching user: $e");
      logout();
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$API_URL/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _token = data['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', _token!);
        await fetchUserProfile();
        // Gửi FCM token lên backend
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null && _token != null) {
          await http.put(
            Uri.parse('$API_URL/api/users/fcm-token'),
            headers: {
              'Content-Type': 'application/json',
              'x-auth-token': _token!
            },
            body: json.encode({'token': fcmToken}),
          );
        }
        return true;
      }
    } catch (e) {
      print("Login error: $e");
    }
    return false;
  }

  Future<void> logout() async {
    _token = null;
    _user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    notifyListeners();
  }
}