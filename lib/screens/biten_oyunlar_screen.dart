import 'package:flutter/material.dart';

class BitenOyunlarScreen extends StatelessWidget {
  final String kullaniciAdi;
  final int kazanilanOyun;
  final int toplamOyun;

  const BitenOyunlarScreen({
    Key? key,
    required this.kullaniciAdi,
    required this.kazanilanOyun,
    required this.toplamOyun,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double basariYuzdesi = toplamOyun > 0
        ? (kazanilanOyun / toplamOyun) * 100
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Biten Oyunlar"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi kutusu
          Container(
            height: 120,
            padding: const EdgeInsets.all(16),
            color: Colors.blueGrey.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Kullanıcı: $kullaniciAdi",
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                ),
                const SizedBox(height: 8),
                Text(
                  "Başarı Yüzdesi: %${basariYuzdesi.toStringAsFixed(1)}",
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ],
            ),
          ),

          // Ortada "Biten Oyun Bulunamadı" yazısı
          const Expanded(
            child: Center(
              child: Text(
                "Biten Oyun Bulunamadı",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
