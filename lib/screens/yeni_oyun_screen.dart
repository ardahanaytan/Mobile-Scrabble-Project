import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart'; // Import Provider
import 'package:flutter_application_1/resources/socket_methods.dart';
import 'package:flutter_application_1/screens/game_screen.dart'; // Import GameScreen for navigation
import 'package:flutter_application_1/screens/lobi_screen.dart';
import 'package:flutter_application_1/widgets/custom_button.dart';
import 'package:provider/provider.dart'; // Import Provider package

class YeniOyunScreen extends StatefulWidget {
  static String routeName = "/yeni-oyun";
  
  final String kullaniciAdi;
  final int kazanilanOyun;
  final int toplamOyun;
  
  const YeniOyunScreen({
    Key? key, 
    required this.kullaniciAdi,
    required this.kazanilanOyun,
    required this.toplamOyun,
    }) : super(key: key);

  @override
  // ignore: no_logic_in_create_state
  State<YeniOyunScreen> createState() => _YeniOyunScreenState();
}

class _YeniOyunScreenState extends State<YeniOyunScreen> {
  late final String kullaniciAdi;
  late final int kazanilanOyun;
  late final int toplamOyun;
  final SocketMethods _socketMethods = SocketMethods();

  @override
  void initState() {
    super.initState();
    kullaniciAdi = widget.kullaniciAdi;
    kazanilanOyun = widget.kazanilanOyun;
    toplamOyun = widget.toplamOyun;
    // Setup listener with callback
    _socketMethods.matchFoundListener((roomData) {
       // This callback will be triggered when a match is found by the server
       if (mounted && roomData is Map<String, dynamic>) {
         print("[YeniOyunScreen] Match found via callback. Navigating to GameScreen...");
         // Update provider
         Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(roomData);
         // Navigate to GameScreen, replacing LobbyScreen if user was sent there
         Navigator.pushNamedAndRemoveUntil(
           context,
           GameScreen.routeName,
           (route) => false, // Remove all previous routes
         );
       } else {
          print("[YeniOyunScreen] Match found callback received, but widget not mounted or data invalid.");
       }
    });
  }

  @override
  void dispose() {
    // Remove socket listeners when screen is disposed
    _socketMethods.removeListeners();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double basariYuzdesi = toplamOyun > 0
        ? (kazanilanOyun / toplamOyun) * 100
        : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Yeni Oyun"),
        centerTitle: true,
      ),
      body: Column(
        children: [
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
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CustomButton(
                    text: "Hızlı Oyun (2 dakika)",
                    onTap: () {
                      _socketMethods.findMatch(kullaniciAdi, "2dk");
                      Navigator.pushNamed(context, LobbyScreen.routeName);
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Hızlı Oyun (5 dakika)",
                    onTap: () {
                      _socketMethods.findMatch(kullaniciAdi, "5dk");
                      Navigator.pushNamed(context, LobbyScreen.routeName);
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Genişletilmiş Oyun (12 saat)",
                    onTap: () {
                      _socketMethods.findMatch(kullaniciAdi, "12saat");
                      Navigator.pushNamed(context, LobbyScreen.routeName);
                    },
                  ),
                  const SizedBox(height: 16),
                  CustomButton(
                    text: "Genişletilmiş Oyun (24 saat)",
                    onTap: () {
                      _socketMethods.findMatch(kullaniciAdi, "24saat");
                      Navigator.pushNamed(context, LobbyScreen.routeName);
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
