import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:provider/provider.dart';

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

    final mySocketId = SocketClient.instance.socket!.id;

    final myPlayer = players.firstWhere(
      (player) => player['socketID'] == mySocketId,
      orElse: () => null,
    );

    if (myPlayer == null) {
      return const Scaffold(
        body: Center(child: Text('Oyuncu bulunamadı')),
      );
    }

    final currentTurnSocketId = players[roomData['turnIndex']]['socketID'];
    final isMyTurn = mySocketId == currentTurnSocketId;

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

                  return Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      color: letter.isEmpty ? Colors.white : Colors.orange.shade100,
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
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