import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:provider/provider.dart';

List<List<String>> tileTypes = [
   ['K³', '', '', 'H²', '', '', '', 'K³', '', '', '', 'H²', '', '', 'K³'],
   ['', 'K²', '', '', '', 'H³', '', '', '', 'H³', '', '', '', 'K²', ''],
   ['', '', 'K²', '', '', '', 'H²', '', 'H²', '', '', '', 'K²', '', ''],
   ['H²', '', '', 'K²', '', '', '', 'H²', '', '', '', 'K²', '', '', 'H²'],
   ['', '', '', '', 'K²', '', '', '', '', '', 'K²', '', '', '', ''],
   ['', 'H³', '', '', '', 'H³', '', '', '', 'H³', '', '', '', 'H³', ''],
   ['', '', 'H²', '', '', '', 'H²', '', 'H²', '', '', '', 'H²', '', ''],
   ['K³', '', '', 'H²', '', '', '', '⭐', '', '', '', 'H²', '', '', 'K³'],
   ['', '', 'H²', '', '', '', 'H²', '', 'H²', '', '', '', 'H²', '', ''],
   ['', 'H³', '', '', '', 'H³', '', '', '', 'H³', '', '', '', 'H³', ''],
   ['', '', '', '', 'K²', '', '', '', '', '', 'K²', '', '', '', ''],
   ['H²', '', '', 'K²', '', '', '', 'H²', '', '', '', 'K²', '', '', 'H²'],
   ['', '', 'K²', '', '', '', 'H²', '', 'H²', '', '', '', 'K²', '', ''],
   ['', 'K²', '', '', '', 'H³', '', '', '', 'H³', '', '', '', 'K²', ''],
   ['K³', '', '', 'H²', '', '', '', 'K³', '', '', '', 'H²', '', '', 'K³'],
 ];

class GameScreen extends StatefulWidget {
  static String routeName = '/game-screen';
  final String kullaniciAdi;

  const GameScreen({Key? key, required this.kullaniciAdi}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int remainingSeconds = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      calculateRemainingTime();
    });

    final socket = SocketClient.instance.socket!;
    socket.on('updateRoom', (updatedRoom) {
      Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(updatedRoom);
    });
  }

  void calculateRemainingTime() {
    final roomData = Provider.of<RoomDataProvider>(context, listen: false).roomData;
    if (roomData.isEmpty || roomData['lastMoveTime'] == null || roomData['turnTimeLimit'] == null) return;

    final lastMoveTime = DateTime.parse(roomData['lastMoveTime']);
    final turnTimeLimit = roomData['turnTimeLimit'];
    final now = DateTime.now();
    final elapsed = now.difference(lastMoveTime).inSeconds;

    setState(() {
      remainingSeconds = (turnTimeLimit - elapsed).clamp(0, turnTimeLimit);
    });

    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) calculateRemainingTime();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Burada hiçbir şey yapmana gerek yok!
    // Kullanıcı adı zaten widget.kullaniciAdi olarak hazır.
  }

  @override
  Widget build(BuildContext context) {
    final roomData = Provider.of<RoomDataProvider>(context).roomData;

    if (roomData.isEmpty || roomData['players'] == null || roomData['boardState'] == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final players = roomData['players'];
    final boardState = List<List<String>>.from(
      roomData['boardState'].map((row) => List<String>.from(row)),
    );

    //final mySocketId = SocketClient.instance.socket!.id;
    final myNickname = widget.kullaniciAdi;

    final myPlayer = players.firstWhere(
      (player) => player['nickname'] == myNickname,
      orElse: () => null,
    );

    if (myPlayer == null) {
      return const Scaffold(
        body: Center(child: Text('Oyuncu bulunamadı')),
      );
    }

    final currentTurnSocketId = players[roomData['turnIndex']]['socketID'];
    final currentTurnNickname = players[roomData['turnIndex']]['nickname'];
    final isMyTurn = myNickname == currentTurnNickname;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrabble Oyun Ekranı'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: players.map<Widget>((player) {
                return Column(
                  children: [
                    Text(
                      player['nickname'],
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        decoration: player['socketID'] == currentTurnSocketId
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                    Text('Puan: ${player['points']}'),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kalan Süre: ${formatSeconds(remainingSeconds)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 15,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: 15 * 15,
                itemBuilder: (context, index) {
                  int row = index ~/ 15;
                  int col = index % 15;
                  String letter = boardState[row][col];
                  String type = tileTypes[row][col];
 
                  Color backgroundColor;
                  Widget child;
 
                  switch (type) {
                    case 'K²':
                      backgroundColor = Colors.green;
                      child = const Text('K²', style: TextStyle(fontWeight: FontWeight.bold));
                      break;
                    case 'K³':
                      backgroundColor = Colors.brown;
                      child = const Text('K³', style: TextStyle(fontWeight: FontWeight.bold));
                      break;
                    case 'H²':
                      backgroundColor = Colors.blue;
                      child = const Text('H²', style: TextStyle(fontWeight: FontWeight.bold));
                      break;
                    case 'H³':
                      backgroundColor = Colors.purple;
                      child = const Text('H³', style: TextStyle(fontWeight: FontWeight.bold));
                      break;
                    case '⭐':
                      backgroundColor = Colors.yellow;
                      child = const Icon(Icons.star, color: Colors.orange);
                      break;
                    default:
                      backgroundColor = Colors.white;
                      child = Text(letter, style: const TextStyle(fontWeight: FontWeight.bold));
                  }

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      color: backgroundColor
                    ),
                    child: Center(
                      child: child,
                    ),
                  );
                },
              ),
            ),
          ),
          Container(
            height: 80,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                myPlayer['rack'].length,
                (index) => Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      myPlayer['rack'][index],
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isMyTurn)
            ElevatedButton(
              onPressed: () {
                final socket = SocketClient.instance.socket!;
                socket.emit('confirmMove', {'currentRoomId': roomData['_id']});
              },
              child: const Text('Hamleyi Onayla'),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  String formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}