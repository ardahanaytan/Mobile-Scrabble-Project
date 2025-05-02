import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class BitenOyunlarScreen extends StatefulWidget {
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
  State<BitenOyunlarScreen> createState() => _BitenOyunlarScreenState();
}

class _BitenOyunlarScreenState extends 
State<BitenOyunlarScreen> {
  List<dynamic> finishedRooms = [];
  bool isLoading = true;

  @override
  void initState(){
    super.initState();
    fetchFinishedRooms();
  }

  Future<void> fetchFinishedRooms()async {
    try{
      final ip = dotenv.env['IP_ADDRESS'] ?? 'localhost';
      final response = await http.get(Uri.parse('http://$ip:3010/api/finished-rooms?nickname=${widget.kullaniciAdi}'));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = json.decode(response.body);
        setState(() {
          finishedRooms = rooms;
          isLoading = false;
        });
      } else {
        throw Exception('Aktif odalar çekilemedi.');
      }

    }catch (e) {
      print('Hata: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    double basariYuzdesi = widget.toplamOyun > 0
        ? (widget.kazanilanOyun / widget.toplamOyun) * 100
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
                  "Kullanıcı: ${widget.kullaniciAdi}",
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

          // Oyun listesi
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : finishedRooms.isEmpty
                    ? const Center(
                        child: Text(
                          "Biten Oyun Bulunamadı",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: finishedRooms.length,
                        itemBuilder: (context, index) {
                          final room = finishedRooms[index];
                          final players = room['players'];
                          final playerText = players.length == 2
                              ? "${players[0]['nickname']} ${players[0]['points']} - ${players[1]['points']} ${players[1]['nickname']}"
                              : "Oyuncu sayısı yetersiz";
                          return Card(
                            elevation: 4,
                            color: room['winner'] == widget.kullaniciAdi 
                            ? Colors.green 
                            : Colors.red,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Oda: ${room['roomName']}",
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    playerText,
                                    style: const TextStyle(fontWeight: FontWeight.bold,fontSize: 14, color: Colors.white),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Kazanan 👑: ${room['winner']}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
