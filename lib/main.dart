import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/messages_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return MaterialApp(
      title: 'BlogSocial',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF9FAFB), // gray-50 giống web
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF111827), // slate-900
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    
    if (auth.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    return auth.isAuthenticated ? const MainScreen() : const LoginScreen();
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  
  // Đảm bảo thứ tự các màn hình khớp với NavigationBar bên dưới
  final List<Widget> _screens = [
    const HomeScreen(),
    const SearchScreen(), // Index 1: Khám phá
    const MessagesScreen(), // Index 2: Tin nhắn
    const ProfileScreen(),
  ];

  void _navigateToExplore() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Chỉ hiện AppBar ở trang Home, các trang khác tự xử lý AppBar của riêng mình (như Profile)
      appBar: _currentIndex == 0 
          ? AppBar(
              title: const Text('BlogSocial', style: TextStyle(color: Colors.blue)),
              actions: [
                IconButton(icon: const Icon(LucideIcons.search), onPressed: _navigateToExplore),
                IconButton(icon: const Icon(LucideIcons.bell), onPressed: () {}),
              ],
            ) 
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 1,
        indicatorColor: Colors.blue.withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.home),
            selectedIcon: Icon(LucideIcons.home, color: Colors.blue),
            label: 'Trang chủ',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.search),
            selectedIcon: Icon(LucideIcons.search, color: Colors.blue),
            label: 'Khám phá',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.messageCircle),
            selectedIcon: Icon(LucideIcons.messageCircle, color: Colors.blue),
            label: 'Tin nhắn',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.user),
            selectedIcon: Icon(LucideIcons.user, color: Colors.blue),
            label: 'Hồ sơ',
          ),
        ],
      ),
    );
  }
}
