import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_application_1/screens/user_home_screen.dart'; // burası route atacağın yer

class LoginScreen extends StatefulWidget {
  static String routeName = '/login-screen';
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showAlert(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hata"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final ip = dotenv.env['IP_ADDRESS'] ?? 'localhost';
    final url = Uri.parse('http://${ip}:3010/api/login'); // backend login endpoint'in

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'email': email,
          'password': password,
        }),
      );

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200) {
        // Giriş başarılı → Anasayfaya yönlendir
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UserHomeScreen(
              kullaniciAdi: jsonResponse["kullaniciAdi"], // backend'den gelmeli
              kazanilanOyun: jsonResponse["kazanilanOyun"],
              toplamOyun: jsonResponse["toplamOyun"],
            ),
          ),
        );

      } else {
        _showAlert(jsonResponse['message'] ?? 'Giriş başarısız.');
      }
    } catch (e) {
      _showAlert("Sunucuya ulaşılamadı: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Giriş Yap"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "E-posta",
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Şifre",
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _login,
              child: const Text("Giriş Yap"),
            ),
          ],
        ),
      ),
    );
  }
}
