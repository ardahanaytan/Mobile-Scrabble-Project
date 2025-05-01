import 'package:flutter/widgets.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:flutter_application_1/screens/game_screen.dart';
import 'package:provider/provider.dart';

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;

  void findMatch(String nickname, String selectedMode) {
    if (nickname.isNotEmpty) {
      _socketClient.emit('findMatch', {
        'nickname': nickname,
        'selectedMode': selectedMode,
      });
    }
  }

  void matchFoundListener(BuildContext context, String nickname) {
  _socketClient.on('matchFound', (room) {
    final roomData = room['room']; // 👈 Doğru veriyi al
    Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(roomData);

    final players = roomData['players'];

    final myPlayer = players.firstWhere(
      (p) => p['nickname'] == nickname,
      orElse: () => null,
    );

    if (myPlayer == null) {
      print("matchFoundListener: Oyuncu bulunamadı.");
      return;
    }

    Navigator.pushNamed(
      context,
      GameScreen.routeName,
      arguments: {
        'kullaniciAdi': myPlayer['nickname'],
      },
    );
  });
}


  void removeListeners() {}

  
}
