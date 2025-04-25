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

  void matchFoundListener(BuildContext context) {
    _socketClient.on('matchFound', (room) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(room);
      Navigator.pushNamed(context, GameScreen.routeName);
    });
  }
}
