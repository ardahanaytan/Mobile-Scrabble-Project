import 'package:flutter/material.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
//import 'package:flutter_application_1/screens/game_screen.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:provider/provider.dart';
//import 'package:flutter_application_1/resources/socket_client.dart';

class AktifOyunlarScreen extends StatefulWidget {
  final String kullaniciAdi;
  final int kazanilanOyun;
  final int toplamOyun;

  const AktifOyunlarScreen({
    Key? key,
    required this.kullaniciAdi,
    required this.kazanilanOyun,
    required this.toplamOyun,
  }) : super(key: key);

  @override
  State<AktifOyunlarScreen> createState() => _AktifOyunlarScreenState();
}

class _AktifOyunlarScreenState extends State<AktifOyunlarScreen> {
  List<dynamic> activeRooms = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchActiveRooms();

    final _socketClient = SocketClient.instance.socket!;

    _socketClient.on('joinRoomSuccess', (room) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(room);
      Navigator.pushNamed(
        context,
        '/game-screen',
        arguments: {
          'kullaniciAdi': widget.kullaniciAdi, // doğru nicki gönderiyorsun
        },
      );
    });

    _socketClient.on('errorJoin', (data) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Katılma hatası'))
      );
    });
  }


  Future<void> fetchActiveRooms() async {
    try {
      final ip = dotenv.env['IP_ADDRESS'] ?? 'localhost';
      final response = await http.get(Uri.parse('http://$ip:3010/api/active-rooms?nickname=${widget.kullaniciAdi}'));

      if (response.statusCode == 200) {
        final List<dynamic> rooms = json.decode(response.body);
        setState(() {
          activeRooms = rooms;
          isLoading = false;
        });
      } else {
        throw Exception('Aktif odalar çekilemedi.');
      }
    } catch (e) {
      print('Hata: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void joinRoom(String roomId, String nickname) {
    final _socketClient = SocketClient.instance.socket!;
    _socketClient.emit('joinRoom', {
      'roomId': roomId,
      'nickname': nickname,
    });
  }


  @override
  Widget build(BuildContext context) {
    double basariYuzdesi = widget.toplamOyun > 0
        ? (widget.kazanilanOyun / widget.toplamOyun) * 100
        : 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text("Aktif Oyunlar"),
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

          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : activeRooms.isEmpty
                    ? const Center(
                        child: Text(
                          "Aktif Oyun Bulunamadı",
                          style: TextStyle(fontSize: 18, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: activeRooms.length,
                        itemBuilder: (context, index) {
                          final room = activeRooms[index];
                          return ListTile(
                            title: Text("Oda: ${room['roomName']}"),
                            subtitle: Text("Oyuncu Sayısı: ${room['players'].length}/2"),
                            trailing: ElevatedButton(
                              onPressed: () {
                                joinRoom(room['_id'], widget.kullaniciAdi);
                              }, 
                              child: const Text('Odaya Katıl'),
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
