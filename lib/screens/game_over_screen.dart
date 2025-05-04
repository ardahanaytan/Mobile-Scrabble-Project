import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/user_home_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class GameOverScreen extends StatelessWidget {
  final String kazanan;
  final List<Map<String, dynamic>> oyuncular;
  final String kullaniciAdi;
  final List<dynamic> eventLogs;
  final int kalanTasSayisi;

  const GameOverScreen({
    Key? key,
    required this.kazanan,
    required this.oyuncular,
    required this.kullaniciAdi,
    required this.eventLogs,
    required this.kalanTasSayisi,
  }) : super(key: key);

  Future<void> _goToUserHomeScreen(BuildContext context) async {
    final ip = dotenv.env['IP_ADDRESS'] ?? 'localhost';

    final response = await http.post(
      Uri.parse('http://$ip:3010/api/get-stats'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'nickname': kullaniciAdi,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      Navigator.pushReplacementNamed(
        context,
        UserHomeScreen.routeName,
        arguments: {
          'kullaniciAdi': data['kullaniciAdi'],
          'kazanilanOyun': data['kazanilanOyun'],
          'toplamOyun': data['toplamOyun'],
        },
      );
    } else {
      print('Kullanıcı bilgileri alınamadı');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Oyun Bitti")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView( // <<< BURAYA EKLEDİK
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Kazanan: $kazanan 🎉",
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              const Text("Skor Tablosu:", style: TextStyle(fontSize: 18)),
              const SizedBox(height: 10),
              ...oyuncular.map((oyuncu) => ListTile(
                    title: Text(oyuncu['nickname']),
                    trailing: Text("Puan: ${oyuncu['points']}"),
                  )),
              const SizedBox(height: 20),
              Text("Kalan Taş Sayısı: $kalanTasSayisi", style: const TextStyle(fontSize: 16)),

              const SizedBox(height: 16),
              const Text(
                'Oyun Olayları',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...eventLogs.map<Widget>((log) {
                final zaman = log[0].toString();
                final mesaj = log[1].toString();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text("🔔 $mesaj"),
                );
              }).toList(),

              const SizedBox(height: 20),
              Center(
                child: ElevatedButton(
                  onPressed: () => _goToUserHomeScreen(context),
                  child: const Text("Anasayfaya Dön"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
