import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:provider/provider.dart';
import 'package:string_validator/string_validator.dart';

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
  // Map to store tiles placed on the board during the current turn
  // Key: (row, col), Value: letter
  Map<(int, int), String> _temporaryPlacedTiles = {};
  // Keep track of rack indices used in the current temporary placement
  Set<int> _usedRackIndices = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        calculateRemainingTime();
      }
    });

    final socket = SocketClient.instance.socket!;
    socket.on('updateRoom', (updatedRoom) {
      if (mounted) {
        // When room updates (likely opponent's move or initial load), clear temporary state
        setState(() {
          _temporaryPlacedTiles.clear();
          _usedRackIndices.clear();
        });
        Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(updatedRoom);
      }
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

    if (roomData['players'] == null || roomData['boardState'] == null) {
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
                  // Check if a tile was temporarily placed here
                  String? placedLetter = _temporaryPlacedTiles[(row, col)];
                  String boardLetter = boardState[row][col]; // Original letter from server state
                  String displayLetter = placedLetter ?? boardLetter; // Show placed tile if exists
                  String type = tileTypes[row][col];

                  Color backgroundColor;
                  Widget? textChild; // Use Widget? to allow null for icon

                  // Determine background based on tile type
                  if(isAlpha(boardLetter) || (boardLetter == 'Ç' || boardLetter == 'Ö' || boardLetter == 'İ' || boardLetter == 'Ş' || boardLetter == 'Ü' || boardLetter == 'Ğ' || boardLetter == ' ')) {
                    // Confirmed letter on a normal tile
                    backgroundColor = Colors.pink; // Use a distinct color for confirmed letters
                  }
                  else
                  {
                    switch (type) {
                    case 'K²':
                      backgroundColor = Colors.green; // Lighter blue for H²
                      textChild = const Text('K²', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                      break;
                    case 'K³':
                      backgroundColor = Colors.brown; // Lighter blue for H²
                      textChild = const Text('K³', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                      break;
                    case 'H²':
                      backgroundColor = Colors.blue; // Lighter blue for H²
                      textChild = const Text('H²', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                      break;
                    case 'H³':
                      backgroundColor = Colors.purple; // Lighter indigo for H³
                      textChild = const Text('H³', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                      break;
                    case '⭐':
                      backgroundColor = Colors.yellow; // Center star
                      textChild = const Icon(Icons.star, color: Colors.orange, size: 16);
                      break;
                    default: // Normal tile
                      backgroundColor = Colors.white;
                      textChild = null; // No special text/icon needed initially
                    }
                  }

                  // If there's a letter (either from board state or temporary placement), display it
                  Widget displayContent;
                  if (placedLetter != null) {
                    // If a tile is temporarily placed here
                    displayContent = Text(
                      placedLetter, // Always show the placed letter
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black), // Black text
                    );
                  } else if (boardLetter.isNotEmpty) {
                    // If the square has a letter from the server state (already confirmed move)
                    displayContent = Text(
                      boardLetter,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), // Default text color (likely black)
                    );
                  }
                   else {
                    // If square is empty and no temporary tile, show the tile type text/icon if it exists
                    displayContent = textChild ?? const SizedBox.shrink();
                  }


                  // Data type for DragTarget is now Map<String, dynamic>
                  return DragTarget<Map<String, dynamic>>(
                    builder: (context, candidateData, rejectedData) {
                      // Determine background color
                      Color currentBackgroundColor = backgroundColor;
                      if (candidateData.isNotEmpty) {
                        currentBackgroundColor = Colors.yellow.shade200; // Highlight potential drop
                      } else if (placedLetter != null) {
                        currentBackgroundColor = Colors.red; // Solid blue for placed tile
                      }

                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26, width: 0.5),
                          color: currentBackgroundColor, // Use the determined background color
                        ),
                        child: Center(
                          child: displayContent, // Shows placed letter (black), board letter, or tile type
                        ),
                      );
                    },
                    onWillAccept: (data) {
                      // Allow drop only if the square is empty (both original and temporary)
                      // and the data is the expected type (Map)
                      return data != null && boardLetter.isEmpty && placedLetter == null;
                    },
                    onAccept: (data) {
                      // data is {'letter': String, 'rackIndex': int}
                      setState(() {
                        _temporaryPlacedTiles[(row, col)] = data['letter']!;
                        _usedRackIndices.add(data['rackIndex']!);

                      });
                    },
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
                myPlayer['rack'].length, // Assuming rack is a List<String>
                (index) {
                  final letter = myPlayer['rack'][index];
                  final bool isPlaced = _usedRackIndices.contains(index);

                  // If the tile at this index is already placed on the board, show a placeholder
                  if (isPlaced) {
                    return Container(
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300, // Placeholder color
                        borderRadius: BorderRadius.circular(8),
                      ),
                    );
                  }

                  // Otherwise, show the draggable tile
                  // Data is now a Map
                  return Draggable<Map<String, dynamic>>(
                    data: {'letter': letter, 'rackIndex': index},
                    feedback: Material( // Need Material for text style during drag
                      // Remove transparency, let the container handle color
                      elevation: 4.0, // Keep elevation for visual lift
                      child: Container(
                        width: 45, // Slightly larger feedback
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.red, // Match original tile color
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 5)] // Keep shadow
                        ),
                        child: Center(
                          child: Text(
                            letter,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black), // Ensure text color is black
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Container( // Placeholder when dragging
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Container( // The tile itself
                      width: 40,
                      height: 40,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: Offset(1,1))]
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (isMyTurn)
            ElevatedButton(
              onPressed: () {
                // TODO: Implement the logic to send placed tiles to the server
                print("Hamleyi Onayla tıklandı!");
                print("Yerleştirilen Taşlar: $_temporaryPlacedTiles");

                if (_temporaryPlacedTiles.isNotEmpty) {
                   final socket = SocketClient.instance.socket!;
                   // Prepare data for the server
                   List<Map<String, dynamic>> placedTilesData = _temporaryPlacedTiles.entries.map((entry) {
                     return {
                       'letter': entry.value,
                       'row': entry.key.$1, // Using record syntax .$1 for row
                       'col': entry.key.$2, // Using record syntax .$2 for col
                     };
                   }).toList();

                   socket.emit('placeWord', {
                     'roomId': roomData['_id'],
                     'nickname': widget.kullaniciAdi, // Send nickname
                     'placedTiles': placedTilesData,
                   });

                   // Clear temporary placements after sending
                   // Clear temporary placements AND used indices after sending
                   setState(() {
                     _temporaryPlacedTiles.clear();
                     _usedRackIndices.clear();
                   });
               } else {
                 // Show a message that no tiles were placed
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tahta üzerine hiç taş yerleştirmediniz.')),
                  );
                }
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