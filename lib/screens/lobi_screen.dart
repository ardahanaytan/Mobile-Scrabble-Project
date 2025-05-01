import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:flutter_application_1/screens/game_screen.dart';
import 'package:provider/provider.dart';

class LobbyScreen extends StatefulWidget {
  static String routeName = '/lobby-screen';
  final String kullaniciAdi;

  const LobbyScreen({Key? key, required this.kullaniciAdi}) : super(key: key);

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _socketClient = SocketClient.instance.socket!;

  @override
  void initState() {
    super.initState();

    _socketClient.on('matchFound', (room) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(room['room']);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(
          context,
          GameScreen.routeName,
          arguments: {
            'kullaniciAdi': widget.kullaniciAdi, // ✅ Artık tanımlı
          },
        );
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    _socketClient.off('matchFound');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text(
              'Rakip Bekleniyor...',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
