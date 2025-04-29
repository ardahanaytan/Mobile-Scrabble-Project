import 'dart:async'; 
import 'package:flutter/material.dart';
import 'package:flutter/material.dart'; // Needed for Scaffold, Widgets etc.
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:flutter_application_1/resources/socket_methods.dart';
import 'package:flutter_application_1/utils/utils.dart'; // For showSnackBar
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

  const GameScreen({Key? key}) : super(key: key);

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int remainingSeconds = 0;
  final SocketMethods _socketMethods = SocketMethods();
  Timer? _timer; // Timer for periodic updates
  RoomDataProvider? _roomDataProvider; // Store provider reference
  Map<String, String> _temporaryPlacements = {}; // Key: "row,col", Value: letter
  List<String> _currentRack = []; // To manage rack during temporary placements


  @override
  void initState() {
    super.initState();
    // Setup listeners with callbacks
    _socketMethods.updateRoomListener((roomData) {
      if (mounted) { // Check if widget is still active
        print("[GameScreen] Received room update via callback. Turn: ${roomData['turnIndex']}");
        Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(roomData);
        // _handleRoomUpdate logic is now implicitly handled by Provider update triggering rebuilds
        // and the _resetTemporaryMoveState call within _handleRoomUpdate.
        // We might not need the explicit _handleRoomUpdate listener anymore if Provider handles it.
        // Let's keep _handleRoomUpdate for now as it resets state.
      }
    });
    _socketMethods.errorOccurredListener((errorData) {
      if (mounted) { // Check if widget is still active
         print("[GameScreen] Received error via callback: $errorData");
         showSnackBar(context, errorData.toString());
         _resetTemporaryMoveState(); // Reset state on error
      }
    });
    // Timer can also be started here
    _startTimer();
  }

    @override
    void didChangeDependencies() {
      super.didChangeDependencies();
      // Get the provider reference safely here
      final newProvider = Provider.of<RoomDataProvider>(context);

      // If the provider instance changes or is obtained for the first time
      if (newProvider != _roomDataProvider) {
        // Remove listener from the old provider, if it exists
        _roomDataProvider?.removeListener(_handleRoomUpdate);
        // Store the new provider reference
        _roomDataProvider = newProvider;
        // Add listener to the new provider
        _roomDataProvider?.addListener(_handleRoomUpdate);

        // Perform initial setup that depends on the provider data
        _initializeFromProviderData();
      }
    }
  void _initializeFromProviderData() {
     if (_roomDataProvider == null) return; // Should not happen if called from didChangeDependencies

     final roomData = _roomDataProvider!.roomData;
     final currentSocketId = SocketClient.instance.socket?.id;

     if (currentSocketId == null) {
        print("Error: Socket ID not available in _initializeFromProviderData");
        return;
     }

     if (roomData.isNotEmpty && roomData['players'] != null) {
        final myPlayer = roomData['players']?.firstWhere(
            (p) => p['socketID'] == currentSocketId,
            orElse: () => null);
        if (myPlayer != null && myPlayer['rack'] != null) {
          _initializeRack(List<String>.from(myPlayer['rack']));
        }
     }
     // Initial time calculation can also be triggered here if needed
     // calculateRemainingTime(); // Or let the timer handle the first calculation
  }
void _initializeRack(List<String> newRack) {
    if (mounted) {
      setState(() {
        print("[GameScreen _initializeRack] Initializing rack with: $newRack");
        _currentRack = List.from(newRack); // Create a copy
        _temporaryPlacements.clear(); // Clear temporary placements on rack update
      });
    }
  }

  void _updateCurrentRack(List<String> newRack) {
     // No need for WidgetsBinding here as it's called within setState in _handleRoomUpdate
     if (mounted) {
        print("[GameScreen _updateCurrentRack] Setting _currentRack to: $newRack");
        _currentRack = List.from(newRack);
     }
  }

  // Handle external room updates (e.g., opponent's move or self-move confirmation)
  void _handleRoomUpdate() {
      final roomData = Provider.of<RoomDataProvider>(context, listen: false);
      // Ensure socket ID is available
      final currentSocketId = SocketClient.instance.socket?.id;
       if (currentSocketId == null) return; // Cannot identify player
  
      final myPlayer = roomData.roomData['players']?.firstWhere(
          (p) => p['socketID'] == currentSocketId,
          orElse: () => null);
       if (myPlayer != null && myPlayer['rack'] != null) {
           // Check if the rack from provider is different from the current one
           // This indicates a new turn or rack update from server
           List<String> serverRack = List<String>.from(myPlayer['rack']);
           // Always reset temporary placements on any room update
           _resetTemporaryMoveState(serverRack);
       }
  }
  
   // Resets temporary placements and updates the current rack based on server data or error
   void _resetTemporaryMoveState([List<String>? serverRack]) {
      final roomData = Provider.of<RoomDataProvider>(context, listen: false);
      final currentSocketId = SocketClient.instance.socket?.id;
      if (currentSocketId == null) return;
  
      final myPlayer = roomData.roomData['players']?.firstWhere(
          (p) => p['socketID'] == currentSocketId,
          orElse: () => null);
       if (myPlayer != null && myPlayer['rack'] != null) {
           // Use provided serverRack if available, otherwise use the one from provider
           List<String> authoritativeRack = serverRack ?? List<String>.from(myPlayer['rack']);
           print("[GameScreen _resetTemporaryMoveState] Resetting state. Authoritative Rack: $authoritativeRack");
           if (mounted) {
             setState(() {
               _temporaryPlacements.clear(); // Clear temporary placements
               _currentRack = List.from(authoritativeRack); // Reset rack to authoritative state
             });
           }
       }
  }

    bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    if (identical(a, b)) return true;
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) return false;
    }
    return true;
  }

  // Helper to get current player index (Removed duplicate)
  int myPlayerIndex(Map<String, dynamic> roomData, String? mySocketId) {
    if (mySocketId == null || roomData['players'] == null) return -1; // Handle null socket ID
    return roomData['players'].indexWhere((p) => p['socketID'] == mySocketId);
  }


  @override
  void dispose() {
    _timer?.cancel(); // Cancel the timer
    // Clean up provider listener
    _roomDataProvider?.removeListener(_handleRoomUpdate);
    // Remove socket listeners
    _socketMethods.removeListeners();
    super.dispose();
  }

   void _startTimer() {
     _timer?.cancel(); // Cancel any existing timer
     _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) { // Check if widget is still mounted before proceeding
             calculateRemainingTime();
        } else {
            timer.cancel(); // Stop timer if widget is disposed
        }
     });
  }

  void calculateRemainingTime() {
    if (!mounted) return;
    final roomData = Provider.of<RoomDataProvider>(context, listen: false).roomData;
    if (roomData.isEmpty || roomData['lastMoveTime'] == null || roomData['turnTimeLimit'] == null) return;

     // Safely parse DateTime
    DateTime? lastMoveTime;
    try {
      lastMoveTime = DateTime.parse(roomData['lastMoveTime']);
    } catch (e) {
      print("Error parsing lastMoveTime: ${roomData['lastMoveTime']}");
      return; // Cannot calculate without valid time
    }
    final turnTimeLimit = roomData['turnTimeLimit'];
    // Ensure turnTimeLimit is an int
    if (turnTimeLimit is! int) {
        print("Error: turnTimeLimit is not an integer: $turnTimeLimit");
        return;
    }
    final now = DateTime.now();
    final elapsed = now.difference(lastMoveTime).inSeconds;

    setState(() {
      remainingSeconds = (turnTimeLimit - elapsed).clamp(0, turnTimeLimit);
    });

    if (remainingSeconds == 0 && mounted) {
        // TODO: Implement logic for time running out (e.g., skip turn)
        print("Time ran out!");
        // Potentially call a socket method to notify server about timeout
        // _socketMethods.skipTurnDueToTimeout(context, roomData['_id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomData = Provider.of<RoomDataProvider>(context).roomData;
    print("[GameScreen Build] Rebuilding. Turn index from provider: ${roomData['turnIndex']}");

    if (roomData.isEmpty || roomData['players'] == null || roomData['boardState'] == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final players = roomData['players'];
    final boardState = List<List<String>>.from(
      roomData['boardState'].map((row) => List<String>.from(row)),
    );
    final turnIndex = roomData['turnIndex'];
    final mySocketId = SocketClient.instance.socket!.id;

    // Handle case where socket ID might be null temporarily
    if (mySocketId == null) {
       return const Scaffold(
         body: Center(child: Text("Connecting...")), // Or a loading indicator
       );
    }

    final myPlayer = players.firstWhere((player) => player['socketID'] == mySocketId, orElse: () => null);

    if (myPlayer == null) {
      return const Scaffold(
        body: Center(child: Text('Oyuncu bulunamadı')),
      );
    }

    // Get current player index safely
    final currentPlayerIndex = myPlayerIndex(roomData, mySocketId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scrabble Oyun Ekranı'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Oyuncular Bilgisi
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(players.length, (index) {
                final points = players[index]['points'] ?? 0;
                return Column(
                  children: [
                    Text(
                      players[index]['nickname'] ?? '?',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        decoration: turnIndex == index
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                    Text('Puan: $points'),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          // Kalan Süre
          Text(
            'Kalan Süre: ${formatSeconds(remainingSeconds)}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          // Tahta (15x15 Grid)
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
                  String permanentLetter = boardState[row][col];
                  String? temporaryLetter = _temporaryPlacements["$row,$col"];
                  String displayLetter = temporaryLetter ?? permanentLetter; // Show temp letter if exists
                  String type = tileTypes[row][col];

                  Color backgroundColor;
                  Widget child;

                  switch (type) {
                    case 'K²':
                      backgroundColor = Colors.lightBlueAccent; // Example color
                      child = Text(displayLetter.isNotEmpty ? displayLetter : 'K²', style: TextStyle(fontWeight: FontWeight.bold, color: displayLetter.isNotEmpty ? Colors.black : Colors.white));
                      break;
                    case 'K³':
                      backgroundColor = Colors.blue; // Example color
                       child = Text(displayLetter.isNotEmpty ? displayLetter : 'K³', style: TextStyle(fontWeight: FontWeight.bold, color: displayLetter.isNotEmpty ? Colors.black : Colors.white));
                      break;
                    case 'H²':
                      backgroundColor = Colors.pinkAccent; // Example color
                       child = Text(displayLetter.isNotEmpty ? displayLetter : 'H²', style: TextStyle(fontWeight: FontWeight.bold, color: displayLetter.isNotEmpty ? Colors.black : Colors.white));
                      break;
                    case 'H³':
                      backgroundColor = Colors.redAccent; // Example color
                       child = Text(displayLetter.isNotEmpty ? displayLetter : 'H³', style: TextStyle(fontWeight: FontWeight.bold, color: displayLetter.isNotEmpty ? Colors.black : Colors.white));
                      break;
                    case '⭐':
                      backgroundColor = Colors.orangeAccent; // Example color
                      child = displayLetter.isNotEmpty
                          ? Text(displayLetter, style: const TextStyle(fontWeight: FontWeight.bold))
                          : const Icon(Icons.star, color: Colors.white);
                      break;
                    default: // Normal square
                      backgroundColor = Colors.brown.shade100; // Use a valid color like brown
                      child = Text(displayLetter, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18));
                  }

                  // Override background if temporarily placed
                   if (temporaryLetter != null) {
                       backgroundColor = Colors.green.shade200; // Color for temporary placement
                   }


                  return DragTarget<Map<String, dynamic>>( // Accept Map: {'letter': String, 'originIndex': int}
                    builder: (context, candidateData, rejectedData) {
                      // This is the widget that is displayed normally
                      return Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          color: backgroundColor,
                           // Indicate potential drop target
                          boxShadow: candidateData.isNotEmpty ? [
                              BoxShadow(color: Colors.black.withOpacity(0.5), spreadRadius: 1, blurRadius: 2)
                          ] : [],
                        ),
                        child: Center(child: child),
                      );
                    },
                    onWillAccept: (data) {
                      // Accept if it's my turn and the square is empty (no permanent or temporary letter)
                      return turnIndex == currentPlayerIndex && permanentLetter.isEmpty && temporaryLetter == null;
                    },
                    onAccept: (data) {
                      // Handle the accepted data (letter and its original index)
                      String letter = data['letter']!;
                      int originIndex = data['originIndex']!; // Index in _currentRack
                      String positionKey = "$row,$col";

                      print('Temporarily placed "$letter" from rack index $originIndex onto ($row, $col)');

                      setState(() {
                        // Add to temporary placements
                        _temporaryPlacements[positionKey] = letter;
                        // Remove from current rack representation by index
                         _currentRack.removeAt(originIndex);
                      });
                    },
                  );
                },
              ),
            ),
          ),
          // Rack (eldeki harfler)
          Container(
            height: 80,
            padding: const EdgeInsets.all(8.0),
            color: Colors.grey.shade200,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _currentRack.length, // Use the length of the local rack state
                (index) {
                  // Ensure index is still valid for safety, though length check should prevent error
                  if (index >= _currentRack.length) return Container(); // Should not happen now
                  final String letter = _currentRack[index];
                  final bool isMyTurn = turnIndex == currentPlayerIndex;

                  Widget tileWidget = Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      // Dim the color slightly if not the player's turn
                      color: isMyTurn ? Colors.amber.shade700 : Colors.amber.shade400,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: isMyTurn ? [
                        BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: Offset(1,1))
                      ] : [], // No shadow if not draggable
                    ),
                    child: Center(
                      child: Text(
                        letter,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  );
                if (isMyTurn) {
                    return Draggable<Map<String, dynamic>>(
                      data: {'letter': letter, 'originIndex': index},
                      feedback: Material( // Use Material for proper text rendering during drag
                         elevation: 4.0,
                         child: Container( // How the tile looks while dragging
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade600, // Drag feedback color
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Center(
                            child: Text(
                              letter,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                      childWhenDragging: Container( // How the original spot looks while dragging
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade200, // Placeholder color
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // The child is the tileWidget defined above
                      child: tileWidget,
                    );
                  } else {
                    // If not my turn, just return the non-draggable tile appearance
                    return tileWidget;
                  }
                }
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10.0),
            child: ElevatedButton(
              // Enable only if it's my turn, tiles are placed, and room ID exists
              onPressed: _temporaryPlacements.isNotEmpty &&
                           turnIndex == currentPlayerIndex && // Use safe index
                           roomData['_id'] != null
                  ? () {
                      // 1. Prepare data for server
                      final List<Map<String, dynamic>> placementsData =
                          _temporaryPlacements.entries.map((entry) {
                        final parts = entry.key.split(',');
                        final row = int.parse(parts[0]);
                        final col = int.parse(parts[1]);
                        final letter = entry.value;
                        return {'letter': letter, 'row': row, 'col': col};
                      }).toList();

                      print("Confirming move with placements: $placementsData");

                      // 2. Call socket method (context removed)
                      _socketMethods.confirmMove(
                        roomData['_id']!, // Use null assertion '!' as we checked
                        placementsData,
                      );

                      // 3. Wait for server 'updateRoom' event
                    }
                  : null, // Disable if conditions not met
              child: const Text('Hamleyi Onayla'),
              style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  textStyle: TextStyle(fontSize: 16)
              ),
            ),
          ),
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
