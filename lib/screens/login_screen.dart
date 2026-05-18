// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../service/api_service.dart';
import '../service/local_storage.dart';
import 'employee_screen.dart';
import 'security_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    debugPrint('🔐 ATTEMPTING LOGIN');

    final result = await ApiService.login(email, password);
    if (!mounted) return;

    setState(() => _isLoading = false);

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📊 LOGIN RESULT');
    debugPrint('Status: ${result['status']}');
    if (result['status'] != 'success') {
      debugPrint('Error: ${result['message']}');
      debugPrint('Code: ${result['code']}');
      debugPrint('StatusCode: ${result['statusCode']}');
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    if (result['status'] == 'success') {
      // حفظ بيانات المستخدم
      await LocalStorage.saveUserData(
        token: result['data']['token'],
        role: result['data']['role'],
        userId: result['data']['user_id'],
        name: result['data']['name'],
      );
      if (!mounted) return;

      debugPrint('✅ User data saved!');
      debugPrint('👤 Role: ${result['data']['role']}');

      if (result['data']['role'] == 'security') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SecurityScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const EmployeeScreen()),
        );
      }
    } else {
      String errorMessage = result['message'] ?? 'فشل تسجيل الدخول';

      // إضافة تفاصيل إضافية للتصحيح
      if (result['code'] != null) {
        errorMessage = '$errorMessage\nCode: ${result['code']}';
      }
      if (result['statusCode'] != null) {
        errorMessage = '$errorMessage\nHTTP: ${result['statusCode']}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contacts, size: 80, color: Colors.blue),
                  SizedBox(height: 16),
                  Text(
                    'اتصالاتي',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'تطبيق إدارة جهات الاتصال',
                    style: TextStyle(color: Colors.grey),
                  ),
                  SizedBox(height: 48),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'من فضلك أدخل البريد الإلكتروني';
                      }
                      if (!value.contains('@')) {
                        return 'أدخل بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور',
                      prefixIcon: Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'من فضلك أدخل كلمة المرور';
                      }
                      if (value.length < 4) {
                        return 'كلمة المرور قصيرة جداً';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text(
                              'تسجيل الدخول',
                              style: TextStyle(fontSize: 18),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
