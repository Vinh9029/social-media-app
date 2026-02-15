import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/search_screen.dart';
import 'screens/messages_screen.dart';
import 'screens/notification_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp();
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

class NotificationService {
  static final List<Map<String, dynamic>> notifications = [];
  static bool hasNewNotification = false;

  static Future<void> initFCM(BuildContext context) async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    String? token = await messaging.getToken();
    // TODO: Gửi token này lên backend qua API /api/users/fcm-token
    print('FCM Token: $token');

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        notifications.insert(0, {
          'title': message.notification!.title ?? '',
          'body': message.notification!.body ?? '',
          'avatar': message.data['avatar'] ?? '',
          'isNew': true,
        });
        hasNewNotification = true;
        // Hiển thị snackbar hoặc cập nhật UI
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.notification!.title ?? 'Có thông báo mới!')),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // TODO: Điều hướng đến trang liên quan nếu cần
    });
  }
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
        cardColor: Colors.white,
        dividerColor: Colors.grey.shade300,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black),
        ),
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF111827), // slate-900
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardColor: const Color(0xFF1E293B),
        dividerColor: Colors.grey,
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
        ),
      ),
      home: const AuthWrapper(),
      routes: {
        '/profile': (context) {
          final userId = ModalRoute.of(context)!.settings.arguments as String?;
          return ProfileScreen(userId: userId);
        },
      },
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
  bool _hasNewNotification = false;

  @override
  void initState() {
    super.initState();
    NotificationService.initFCM(context);
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      setState(() {
        _hasNewNotification = true;
      });
    });
  }
  
  // Đảm bảo thứ tự các màn hình khớp với NavigationBar bên dưới
  final List<Widget> _screens = [
    HomeScreen(key: HomeScreen.globalKey),
    const SearchScreen(), // Index 1: Khám phá
    const MessagesScreen(), // Index 2: Tin nhắn
    const ProfileScreen(),
  ];

  void _navigateToExplore() {
    setState(() => _currentIndex = 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // Chỉ hiện AppBar ở trang Home, các trang khác tự xử lý AppBar của riêng mình (như Profile)
      appBar: _currentIndex == 0 
          ? AppBar(
              title: GestureDetector(
                onTap: () {
                  // Scroll về đầu trang HomeScreen
                  if (_currentIndex == 0 && _screens[0] is HomeScreen) {
                    final homeKey = HomeScreen.globalKey;
                    if (homeKey.currentState != null) {
                      homeKey.currentState!.scrollToTop();
                    }
                  }
                },
                child: const Text('BlogSocial', style: TextStyle(color: Colors.blue)),
              ),
              actions: [
                IconButton(icon: const Icon(LucideIcons.search), onPressed: _navigateToExplore),
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.bell),
                      onPressed: () async {
                        setState(() => _hasNewNotification = false);
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
                      },
                    ),
                    if (_hasNewNotification || NotificationService.hasNewNotification)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
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
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 1,
        indicatorColor: isDark ? Colors.blue.withOpacity(0.2) : Colors.blue.withOpacity(0.1),
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
