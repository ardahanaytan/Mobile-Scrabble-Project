import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/custom_button.dart';
import 'package:flutter_application_1/screens/yeni_oyun_screen.dart';
import 'package:flutter_application_1/screens/aktif_oyunlar_screen.dart';
import 'package:flutter_application_1/screens/biten_oyunlar_screen.dart';

class UserHomeScreen extends StatelessWidget {
  final String kullaniciAdi;
  final int kazanilanOyun;
  final int toplamOyun;

  const UserHomeScreen({
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
        title: const Text("Ana Sayfa"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Kullanıcı bilgisi kutusu (sabit yükseklik)
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

          // Butonları ortalamak için Expanded + Center
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomButton(
                    text: "Yeni Oyun",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => YeniOyunScreen(
                            kullaniciAdi: kullaniciAdi,
                            kazanilanOyun: kazanilanOyun,
                            toplamOyun: toplamOyun,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Aktif Oyunlar",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AktifOyunlarScreen(
                            kullaniciAdi: kullaniciAdi,
                            kazanilanOyun: kazanilanOyun,
                            toplamOyun: toplamOyun,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Biten Oyunlar",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BitenOyunlarScreen(
                            kullaniciAdi: kullaniciAdi,
                            kazanilanOyun: kazanilanOyun,
                            toplamOyun: toplamOyun,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
