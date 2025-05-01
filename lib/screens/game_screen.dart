import 'package:flutter/foundation.dart' show listEquals; // Import for listEquals
import 'package:flutter/material.dart';
import 'package:flutter_application_1/provider/room_data_provide.dart';
import 'package:flutter/services.dart' show rootBundle; // Import for loading assets
import 'package:flutter_application_1/resources/socket_client.dart';
import 'package:provider/provider.dart';
import 'package:string_validator/string_validator.dart';

// Define Letter Points (matching server/models/letter_points.js)
const Map<String, int> letterPoints = {
  'A': 1, 'B': 3, 'C': 4, 'Ç': 4, 'D': 3, 'E': 1, 'F': 7, 'G': 5, 'Ğ': 8,
  'H': 5, 'I': 2, 'İ': 1, 'J': 10, 'K': 1, 'L': 1, 'M': 2, 'N': 1, 'O': 2,
  'Ö': 7, 'P': 5, 'R': 1, 'S': 2, 'Ş': 4, 'T': 1, 'U': 2, 'Ü': 3, 'V': 7,
  'Y': 3, 'Z': 4
};

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
  Set<String> _validWords = {}; // To store the dictionary
  bool _dictionaryLoaded = false;
  // Store validation status for each temporarily placed tile's position (REMOVED - using word groups now)
  // Map<(int, int), bool?> _tileValidationStatus = {};
  int _potentialScore = 0; // Score for the current temporary placement
  // Store word groups for the painter: list of (list of coordinates, validity)
  List<({List<(int, int)> coords, bool isValid})> _validatedWordGroups = [];


  @override
  void initState() {
    super.initState();
    _loadDictionary(); // Load the dictionary when the widget initializes

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
          _validatedWordGroups.clear(); // Clear word groups on update
          _potentialScore = 0; // Reset potential score
        });
        Provider.of<RoomDataProvider>(context, listen: false).updateRoomData(updatedRoom);
      }
    });
  }

  Future<void> _loadDictionary() async {
    try {
      print("sözlük yükleniyor");
      // Ensure the path matches where you place the file in your assets folder
      final String content = await rootBundle.loadString('turkce_kelime_listesi.txt');
      print("cekildi!");
      // Use Turkish uppercasing for the dictionary
      final List<String> words = content.split('\n').map((word) => _toUpperCaseTurkish(word.trim())).where((word) => word.isNotEmpty).toList();
      setState(() {
        _validWords = words.toSet();
        _dictionaryLoaded = true;
        print("Dictionary loaded successfully: ${_validWords.length} words.");
      });
    } catch (e) {
      print("Error loading dictionary: $e");
      // Handle error appropriately, maybe show a message to the user
      setState(() {
        _dictionaryLoaded = false;
      });
    }
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

    // Also wait for the dictionary to load
    if (roomData['players'] == null || roomData['boardState'] == null || !_dictionaryLoaded) {
      return Scaffold(
        body: Center(
            child: _dictionaryLoaded
                ? const CircularProgressIndicator()
                : const Text("Sözlük yükleniyor...")),
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
              // Wrap GridView in a Stack to overlay the painter
              child: Stack(
                children: [
                  GridView.builder( // Base layer: Grid
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 15,
                      // No spacing needed here if painter draws borders correctly
                    ),
                    itemCount: 15 * 15,
                    itemBuilder: (context, index) {
                       int row = index ~/ 15;
                       int col = index % 15;
                       String? placedLetter = _temporaryPlacedTiles[(row, col)];
                       String boardLetter = boardState[row][col];
                       String displayLetter = placedLetter ?? boardLetter;
                       String type = tileTypes[row][col];
                       Color backgroundColor;
                       Widget? textChild;

                       // Determine background based on tile type
                       if(isAlpha(boardLetter) || (boardLetter == 'Ç' || boardLetter == 'Ö' || boardLetter == 'İ' || boardLetter == 'Ş' || boardLetter == 'Ü' || boardLetter == 'Ğ' || boardLetter == ' ')) {
                         // Confirmed letter on a normal tile
                         backgroundColor = Colors.pink.shade300; // Use a distinct color for confirmed letters
                       }
                       else
                       {
                         switch (type) {
                         case 'K²':
                           backgroundColor = Colors.green;
                           textChild = const Text('K²', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                           break;
                         case 'K³':
                           backgroundColor = Colors.brown;
                           textChild = const Text('K³', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                           break;
                         case 'H²':
                           backgroundColor = Colors.blue;
                           textChild = const Text('H²', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                           break;
                         case 'H³':
                           backgroundColor = Colors.purple;
                           textChild = const Text('H³', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.black54));
                           break;
                         case '⭐':
                           backgroundColor = Colors.yellow;
                           textChild = const Icon(Icons.star, color: Colors.orange, size: 16);
                           break;
                         default: // Normal tile
                           backgroundColor = Colors.white;
                           textChild = null;
                         }
                       }

                       // If there's a letter (either from board state or temporary placement), display it
                       Widget displayContent;
                       if (placedLetter != null) {
                         // If a tile is temporarily placed here
                         displayContent = Text(
                           placedLetter,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black),
                         );
                       } else if (boardLetter.isNotEmpty) {
                         // If the square has a letter from the server state
                         displayContent = Text(
                           boardLetter,
                           style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                         );
                       }
                        else {
                         // If square is empty and no temporary tile
                         displayContent = textChild ?? const SizedBox.shrink();
                       }

                       // Data type for DragTarget is now Map<String, dynamic>
                       return DragTarget<Map<String, dynamic>>(
                         builder: (context, candidateData, rejectedData) {
                            Color currentBackgroundColor = backgroundColor;
                            if (candidateData.isNotEmpty) {
                              currentBackgroundColor = Colors.yellow.shade200; // Highlight potential drop
                            } else if (placedLetter != null) {
                              // Use a different color for temporarily placed tiles if desired
                              currentBackgroundColor = Colors.yellow.shade300;
                            }

                            // Per-tile border logic removed

                            return Container(
                               decoration: BoxDecoration(
                                 border: Border.all(color: Colors.black26, width: 0.5), // Keep thin grid line
                                 color: currentBackgroundColor,
                               ),
                               child: Center(child: displayContent),
                             );
                         },
                         onWillAccept: (data) {
                           return data != null && boardLetter.isEmpty && placedLetter == null;
                         },
                         onAccept: (data) {
                           setState(() {
                             _temporaryPlacedTiles[(row, col)] = data['letter']!;
                             _usedRackIndices.add(data['rackIndex']!);
                             _validateAndScoreMove(boardState);
                           });
                         },
                       );
                    },
                  ),
                  LayoutBuilder( // Overlay layer: Painter
                    builder: (context, constraints) {
                      // Calculate cell size based on available width
                      double cellSize = constraints.maxWidth / 15;
                      return CustomPaint(
                        size: Size.infinite, // Take up the same space as the GridView
                        painter: _WordBorderPainter(
                          wordGroups: _validatedWordGroups,
                          cellSize: cellSize,
                        ),
                      );
                    }
                  ),
                ],
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
                          color: Colors.yellow.shade300, // Match original tile color
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
                        color: Colors.yellow.shade300,
                        borderRadius: BorderRadius.circular(8),
                         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 2, offset: Offset(1,1))]
                      ),
                      child: Center(
                        child: Text(
                          letter,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black),
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
                     _validatedWordGroups.clear(); // Clear word groups on submit
                     _potentialScore = 0; // Reset score on submit
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
          // Display potential score
          if (_potentialScore > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Potansiyel Puan: $_potentialScore',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.purple),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // --- Word Validation and Scoring Logic ---

  void _validateAndScoreMove(List<List<String>> boardState) {
    _validatedWordGroups.clear(); // Clear previous word groups
    _potentialScore = 0;
    bool placementValidButNoWord = false; // Declare at the top

    if (_temporaryPlacedTiles.isEmpty) {
      setState(() {}); // Update UI if tiles were removed
      return;
    }

    // --- 1. Basic Placement Validation & Word Finding ---
    List<(int, int)> placedCoords = _temporaryPlacedTiles.keys.toList();
    placedCoords.sort((a, b) { // Sort for easier processing
      int rowComp = a.$1.compareTo(b.$1);
      return rowComp == 0 ? a.$2.compareTo(b.$2) : rowComp;
    });

    bool isHorizontal = true;
    bool isVertical = true;
    int firstRow = placedCoords[0].$1;
    int firstCol = placedCoords[0].$2;

    for (int i = 1; i < placedCoords.length; i++) {
      if (placedCoords[i].$1 != firstRow) isHorizontal = false;
      if (placedCoords[i].$2 != firstCol) isVertical = false;
    }

    // Must be in a single line (or a single tile)
    if (!isHorizontal && !isVertical && placedCoords.length > 1) {
      _markAllTemporaryTilesInvalid();
      return;
    }
    // Check for gaps in the line
    if (isHorizontal && placedCoords.length > 1) {
      for (int i = 0; i < placedCoords.length - 1; i++) {
        if (placedCoords[i+1].$2 != placedCoords[i].$2 + 1) {
           // Check if gap is filled by existing board letter
           bool gapFilled = false;
           for (int c = placedCoords[i].$2 + 1; c < placedCoords[i+1].$2; c++) {
               if (boardState[firstRow][c].isNotEmpty) {
                   gapFilled = true;
                   break;
               }
           }
           if (!gapFilled) {
               _markAllTemporaryTilesInvalid(); // Gap detected
               return;
           }
        }
      }
    } else if (isVertical && placedCoords.length > 1) {
       for (int i = 0; i < placedCoords.length - 1; i++) {
        if (placedCoords[i+1].$1 != placedCoords[i].$1 + 1) {
           // Check if gap is filled by existing board letter
           bool gapFilled = false;
           for (int r = placedCoords[i].$1 + 1; r < placedCoords[i+1].$1; r++) {
               if (boardState[r][firstCol].isNotEmpty) {
                   gapFilled = true;
                   break;
               }
           }
           if (!gapFilled) {
               _markAllTemporaryTilesInvalid(); // Gap detected
               return;
           }
        }
      }
    }

    // --- 2. Find all words formed ---
    List<({String word, List<(int, int)> coords})> wordsFound = [];
    bool isFirstMove = boardState.every((row) => row.every((cell) => cell.isEmpty)); // Check if board is empty
    Set<(int, int)> allWordCoords = Set.from(placedCoords); // Keep track of all coords involved

    // Function to get letter at a coordinate (prioritizing temporary tiles)
    String getLetter(int r, int c) => _temporaryPlacedTiles[(r, c)] ?? boardState[r][c];

    // Find the main word (horizontal or vertical)
    if (isHorizontal || placedCoords.length == 1) { // Check horizontal word
        int startCol = firstCol;
        while (startCol > 0 && getLetter(firstRow, startCol - 1).isNotEmpty) {
            startCol--;
        }
        int endCol = firstCol;
         while (endCol < 14 && getLetter(firstRow, endCol + 1).isNotEmpty) {
            endCol++;
        }

        if (startCol != endCol || getLetter(firstRow, startCol).isNotEmpty) { // Word has length > 1 or single letter exists
            String word = "";
            List<(int, int)> coords = [];
            for (int c = startCol; c <= endCol; c++) {
                String letter = getLetter(firstRow, c);
                if (letter.isEmpty) break; // Should not happen if gap check worked
                word += letter;
                coords.add((firstRow, c));
                allWordCoords.add((firstRow, c));
            }
             // Ensure unique words only
             if (word.length > 1 && !wordsFound.any((w) => listEquals(w.coords, coords))) {
                 wordsFound.add((word: word, coords: coords));
             }
        }
    }
     if (isVertical || placedCoords.length == 1) { // Check vertical word (also check if single tile forms vertical word)
        int startRow = firstRow;
        while (startRow > 0 && getLetter(startRow - 1, firstCol).isNotEmpty) {
            startRow--;
        }
        int endRow = firstRow;
        while (endRow < 14 && getLetter(endRow + 1, firstCol).isNotEmpty) {
            endRow++;
        }

         if (startRow != endRow || getLetter(startRow, firstCol).isNotEmpty) { // Word has length > 1 or single letter exists
            String word = "";
            List<(int, int)> coords = [];
            for (int r = startRow; r <= endRow; r++) {
                 String letter = getLetter(r, firstCol);
                 if (letter.isEmpty) break;
                 word += letter;
                 coords.add((r, firstCol));
                 allWordCoords.add((r, firstCol));
            }
             // Ensure unique words only
             if (word.length > 1 && !wordsFound.any((w) => listEquals(w.coords, coords))) {
                 wordsFound.add((word: word, coords: coords));
             }
        }
    }


    // Find cross words (perpendicular to main placement axis if multiple tiles)
    if (placedCoords.length > 1) {
        for (var coord in placedCoords) {
            int r = coord.$1;
            int c = coord.$2;
            if (isHorizontal) { // Find vertical cross-words
                int startRow = r;
                while (startRow > 0 && getLetter(startRow - 1, c).isNotEmpty) startRow--;
                int endRow = r;
                while (endRow < 14 && getLetter(endRow + 1, c).isNotEmpty) endRow++;
                if (startRow != endRow) {
                    String word = "";
                    List<(int, int)> coords = [];
                    for (int cr = startRow; cr <= endRow; cr++) {
                        word += getLetter(cr, c);
                        coords.add((cr, c));
                        allWordCoords.add((cr, c));
                    }
                    // Ensure unique words only
                    if (word.length > 1 && !wordsFound.any((w) => listEquals(w.coords, coords))) {
                         wordsFound.add((word: word, coords: coords));
                    }
                }
            } else { // Find horizontal cross-words
                 int startCol = c;
                 while (startCol > 0 && getLetter(r, startCol - 1).isNotEmpty) startCol--;
                 int endCol = c;
                 while (endCol < 14 && getLetter(r, endCol + 1).isNotEmpty) endCol++;
                 if (startCol != endCol) {
                    String word = "";
                    List<(int, int)> coords = [];
                    for (int cc = startCol; cc <= endCol; cc++) {
                        word += getLetter(r, cc);
                        coords.add((r, cc));
                        allWordCoords.add((r, cc));
                        // Removed isConnected reference here
                    }
                     // Ensure unique words only
                     if (word.length > 1 && !wordsFound.any((w) => listEquals(w.coords, coords))) {
                         wordsFound.add((word: word, coords: coords));
                     }
                 }
            }
        }
    }

     // Check connection rule (must touch existing tile OR be first move on star)
     bool isConnectedToBoard = false; // Renamed for clarity
     bool centerCoveredByTemp = _temporaryPlacedTiles.containsKey((7, 7));

     if (!isFirstMove) {
         // Check if ANY temporary tile is adjacent to ANY existing tile on the ORIGINAL boardState
         for (var tempCoord in _temporaryPlacedTiles.keys) {
             int r = tempCoord.$1;
             int c = tempCoord.$2;
             // Check neighbors in original boardState
             if ((r > 0 && boardState[r - 1][c].isNotEmpty) ||
                 (r < 14 && boardState[r + 1][c].isNotEmpty) ||
                 (c > 0 && boardState[r][c - 1].isNotEmpty) ||
                 (c < 14 && boardState[r][c + 1].isNotEmpty)) {
                 isConnectedToBoard = true;
                 break; // Found a connection to the existing board
             }
         }
          if (!isConnectedToBoard) {
              print("Validation failed: Placed tiles do not connect to existing tiles on the board.");
              _markAllTemporaryTilesInvalid();
              return; // Stop validation if not connected
          }
     } else { // First move
         // Must cover the center star
         if (!centerCoveredByTemp && _temporaryPlacedTiles.isNotEmpty) {
             print("Validation failed: First move must cover the center star (7, 7).");
             _markAllTemporaryTilesInvalid();
             return;
         }
         // Connection rule is satisfied for the first move if center is covered
         isConnectedToBoard = true; // Mark as connected if first move covers center
     }

     // If we reach here, the placement is linear, without gaps, and connected correctly.

     // Check if at least one word was formed (length > 1)
     // Allow placement if connected/first move, even if no word > 1 formed *yet*.
     // The server should perform the final check that a valid word is ultimately formed.
     if (wordsFound.isEmpty && _temporaryPlacedTiles.isNotEmpty) {
          print("Validation failed: No word of length > 1 formed.");
         _markAllTemporaryTilesInvalid(); // Must form at least one word
         return;
     }


    // --- 3. Validate Words & Calculate Score ---
    int totalScore = 0;
    // Use new variables for word group logic
    bool overallPlacementValid = isConnectedToBoard; // Start with connection status
    List<({List<(int, int)> coords, bool isValid})> currentWordGroups = [];
    Set<(int, int)> allInvalidCoords = {}; // Track all coords part of *any* invalid word

    for (var wordData in wordsFound) {
      // Use Turkish uppercasing for dictionary check
      String word = _toUpperCaseTurkish(wordData.word);
      bool isWordValid = _validWords.contains(word);
      print("Checking word: ${wordData.word} ($word) -> Valid: $isWordValid");

      // Add to groups for painter
      currentWordGroups.add((coords: wordData.coords, isValid: isWordValid));

      if (!isWordValid) {
        overallPlacementValid = false; // If any word is invalid, the overall placement score is 0
        allInvalidCoords.addAll(wordData.coords);
      } else {
        // Calculate score only for valid words
        int wordScore = 0;
        int wordMultiplier = 1;
        for (var coord in wordData.coords) {
          int r = coord.$1; // Define r inside the loop
          int c = coord.$2; // Define c inside the loop
          // Use Turkish uppercasing for letter point lookup
          String letter = _toUpperCaseTurkish(getLetter(r, c));
          int letterScore = letterPoints[letter] ?? 0;
          String tileType = tileTypes[r][c];

          // Apply bonuses only if the tile was placed this turn
          if (_temporaryPlacedTiles.containsKey(coord)) {
            switch (tileType) {
              case 'K²': letterScore *= 2; break;
              case 'K³': letterScore *= 3; break;
              case 'H²': wordMultiplier *= 2; break;
              case 'H³': wordMultiplier *= 3; break;
              case '⭐': if (isFirstMove) wordMultiplier *= 2; break; // Center star bonus only on first move
            }
          }
          wordScore += letterScore;
        }
        totalScore += (wordScore * wordMultiplier);
      }
    }

    // --- 4. Determine Final State Values ---
    List<({List<(int, int)> coords, bool isValid})> finalValidatedWordGroups = currentWordGroups;
    int finalPotentialScore = totalScore;

    // Handle the case where placement is valid but no word > 1 formed
    if (placementValidButNoWord) {
        // Mark individual temporary tiles as 'valid' for the painter to draw green borders around them individually
         finalValidatedWordGroups = _temporaryPlacedTiles.keys.map((coord) => (coords: [coord], isValid: true)).toList();
         // overallPlacementValid = true; // Already true if connected
         finalPotentialScore = 0; // No score
    } else if (!overallPlacementValid) {
        // If any word was invalid OR connection failed earlier, ensure score is 0
        finalPotentialScore = 0;
        // Optionally, force all groups to red if *any* part is invalid:
        // finalValidatedWordGroups = currentWordGroups.map((g) => (coords: g.coords, isValid: false)).toList();
    }

    // --- 5. Update UI State ---
    setState(() {
       _validatedWordGroups = finalValidatedWordGroups;
       _potentialScore = finalPotentialScore;

       print("Final Score: $_potentialScore, Word Groups: $_validatedWordGroups");
    });
  }

  // Helper for Turkish-specific uppercasing
  String _toUpperCaseTurkish(String text) {
    const Map<String, String> turkishUpperMap = {
      'i': 'İ',
      'ı': 'I',
      'ğ': 'Ğ',
      'ü': 'Ü',
      'ş': 'Ş',
      'ö': 'Ö',
      'ç': 'Ç',
      'â': 'A',
      'î': 'İ',
      'û': 'U',
    };

  String result = text.split('').map((char) {
    final lowerChar = char.toLowerCase();
    return turkishUpperMap.containsKey(lowerChar)
        ? turkishUpperMap[lowerChar]!
        : char.toUpperCase();
  }).join();

  return result;
}


  // Helper to mark all temporary tiles as invalid (updates word groups for painter)
  void _markAllTemporaryTilesInvalid({bool updateState = true}) {
     List<({List<(int, int)> coords, bool isValid})> invalidGroups =
         _temporaryPlacedTiles.keys.map((coord) => (coords: [coord], isValid: false)).toList();

     if (updateState) {
        setState(() {
            _validatedWordGroups = invalidGroups; // Update word groups
            _potentialScore = 0;
        });
     } else {
         _validatedWordGroups = invalidGroups; // Update word groups
         _potentialScore = 0;
     }
  }

  // --- End Validation Logic ---


  String formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }
}
// --- Custom Painter for Word Borders ---

class _WordBorderPainter extends CustomPainter {
  final List<({List<(int, int)> coords, bool isValid})> wordGroups;
  final double cellSize; // Calculate this based on GridView size

  _WordBorderPainter({required this.wordGroups, required this.cellSize});

  @override
  void paint(Canvas canvas, Size size) {
    print("--- Painting Borders ---"); // Debug Start
    print("Cell Size: $cellSize");
    print("Word Groups Received: $wordGroups");

    final Paint greenPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0; // Make border slightly thicker

    final Paint redPaint = Paint()
      ..color = Colors.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0; // Make border slightly thicker

    for (var group in wordGroups) {
      if (group.coords.isEmpty) continue;

      // Find min/max row/col to determine bounding box
      int minRow = group.coords.first.$1;
      int maxRow = group.coords.first.$1;
      int minCol = group.coords.first.$2;
      int maxCol = group.coords.first.$2;

      for (var coord in group.coords) {
        minRow = coord.$1 < minRow ? coord.$1 : minRow;
        maxRow = coord.$1 > maxRow ? coord.$1 : maxRow;
        minCol = coord.$2 < minCol ? coord.$2 : minCol;
        maxCol = coord.$2 > maxCol ? coord.$2 : maxCol;
      }

      // Calculate rect coordinates based on cell size
      // Draw exactly on the outer boundaries of the bounding box
      final Rect rect = Rect.fromLTRB(
        minCol * cellSize,
        minRow * cellSize,
        (maxCol + 1) * cellSize,
        (maxRow + 1) * cellSize,
      );

      // Choose paint based on validity
      final Paint paintToUse = group.isValid ? greenPaint : redPaint;

      print("Painting Group: Coords=${group.coords}, Valid=${group.isValid}, Rect=$rect, Color=${group.isValid ? 'Green' : 'Red'}"); // Debug Paint

      // Draw the rectangle
      canvas.drawRect(rect, paintToUse);
    }
     print("--- End Painting Borders ---"); // Debug End
  }

  @override
  bool shouldRepaint(covariant _WordBorderPainter oldDelegate) {
    // Repaint if word groups or cell size change
    return oldDelegate.wordGroups != wordGroups || oldDelegate.cellSize != cellSize;
  }
}

// --- End Custom Painter ---