import 'package:flutter/material.dart';

class GameOverScreen extends StatelessWidget {
  final String kazanan;
  final List<Map<String, dynamic>> oyuncular;

  const GameOverScreen({
    Key? key,
    required this.kazanan,
    required this.oyuncular,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Oyun Bitti")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
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
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text("Anasayfaya Dön"),
            ),
          ],
        ),
      ),
    );
  }
}
