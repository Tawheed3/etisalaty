// lib/main.dart
import 'package:etisalaty/screens/employee_screen.dart';
import 'package:etisalaty/screens/security_screen.dart';
import 'package:etisalaty/service/local_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const enableLogs = bool.fromEnvironment('ETISALATY_ENABLE_LOGS');
  const enableContactLogs = bool.fromEnvironment('ETISALATY_TRACE_CONTACTS');

  if (!enableLogs && !enableContactLogs) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

  // دالة عامة لتسجيل الخروج وإعادة التوجيه
  static Future<void> logoutAndNavigate(BuildContext context) async {
    await LocalStorage.clearUserData();
    debugPrint('🗑️ User data cleared, redirecting to login...');

    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => LoginScreen()),
      (route) => false,
    );
  }
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اتصالاتي',
      debugShowCheckedModeBanner: false,
      navigatorKey: MyApp.navigatorKey,
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: FutureBuilder<bool>(
        future: _checkLoginStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasData && snapshot.data == true) {
            return FutureBuilder<String?>(
              future: LocalStorage.getUserRole(),
              builder: (context, roleSnapshot) {
                String? role = roleSnapshot.data;
                debugPrint('👤 User role: $role');

                if (role == 'security') {
                  return SecurityScreen();
                } else {
                  return EmployeeScreen();
                }
              },
            );
          } else {
            return LoginScreen();
          }
        },
      ),
    );
  }

  Future<bool> _checkLoginStatus() async {
    String? token = await LocalStorage.getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    return true;
  }
}
