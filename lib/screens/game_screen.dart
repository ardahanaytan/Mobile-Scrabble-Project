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
  // Store validation status for each temporarily placed tile's position
  // true = part of valid word(s), false = part of invalid word(s), null = not checked yet or not part of a word
  Map<(int, int), bool?> _tileValidationStatus = {};
  int _potentialScore = 0; // Score for the current temporary placement
  bool _isValidMove = false;

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
          _tileValidationStatus.clear(); // Clear validation status on update
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
                    backgroundColor = Colors.pink.shade300; // Use a distinct color for confirmed letters
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
                        currentBackgroundColor = Colors.yellow; // Highlight potential drop
                      } else if (placedLetter != null) {
                        currentBackgroundColor = Colors.yellow.shade300; // Solid blue for placed tile
                      }

                      // Determine border based on validation status
                      Border border = Border.all(color: Colors.black26, width: 0.5); // Default border
                      if (placedLetter != null) {
                        bool? isValid = _tileValidationStatus[(row, col)];
                        if (isValid == true) {
                          border = Border.all(color: Colors.green, width: 2.0); // Valid word tile
                        } else if (isValid == false) {
                          border = Border.all(color: Colors.red.shade300, width: 2.0); // Invalid word tile
                        }
                      }

                      return GestureDetector(
                        onTap: () {
                          // Eğer buraya geçici taş konduysa, geri al
                          if (_temporaryPlacedTiles.containsKey((row, col))) {
                            setState(() {
                              _usedRackIndices.removeWhere((i) =>
                                myPlayer['rack'][i] == _temporaryPlacedTiles[(row, col)]); // taş geri döner
                              _temporaryPlacedTiles.remove((row, col));
                              _tileValidationStatus.remove((row, col));
                              _potentialScore = 0;
                              _isValidMove = false;
                              _validateAndScoreMove(boardState);
                            });
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: border,
                            color: currentBackgroundColor,
                          ),
                          child: Center(
                            child: displayContent,
                          ),
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
                        // Trigger validation and scoring after a tile is placed
                        _validateAndScoreMove(boardState);
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
              onPressed: (_isValidMove && _temporaryPlacedTiles.isNotEmpty)
                  ? () {
                      print("Hamleyi Onayla tıklandı!");
                      print("Yerleştirilen Taşlar: $_temporaryPlacedTiles");

                      final socket = SocketClient.instance.socket!;
                      List<Map<String, dynamic>> placedTilesData = _temporaryPlacedTiles.entries.map((entry) {
                        return {
                          'letter': entry.value,
                          'row': entry.key.$1,
                          'col': entry.key.$2,
                        };
                      }).toList();

                      socket.emit('placeWord', {
                        'roomId': roomData['_id'],
                        'nickname': widget.kullaniciAdi,
                        'placedTiles': placedTilesData,
                      });

                      setState(() {
                        _temporaryPlacedTiles.clear();
                        _usedRackIndices.clear();
                        _tileValidationStatus.clear();
                        _potentialScore = 0;
                      });
                    }
                  : null, // buton devre dışı
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
    _tileValidationStatus.clear(); // Clear previous validation
    _potentialScore = 0;

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
    bool allWordsValid = true;
    Set<(int, int)> invalidWordCoords = {}; // Track coords belonging to invalid words

    for (var wordData in wordsFound) {
      // Use Turkish uppercasing for dictionary check
      String word = _toUpperCaseTurkish(wordData.word);
      bool isValid = _validWords.contains(word);
      print("Checking word: ${wordData.word} ($word) -> Valid: $isValid");

      if (!isValid) {
        allWordsValid = false;
        invalidWordCoords.addAll(wordData.coords);
      } else {
        // Calculate score for this valid word
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
              case 'K²': wordMultiplier *= 2; break;
              case 'K³': wordMultiplier *= 3; break;
              case 'H²': letterScore *= 2; break;
              case 'H³': letterScore *= 3; break;
              case '⭐': if (isFirstMove) letterScore *= 2; break; // Center star bonus only on first move
            }
          }
          wordScore += letterScore;
        }
        totalScore += (wordScore * wordMultiplier);
      }
    }

    // --- 4. Update UI State ---
    setState(() {
      _isValidMove = allWordsValid; // Update valid move status

      if (allWordsValid) {
        _potentialScore = totalScore;
        // Mark all temporarily placed tiles as valid
        for (var coord in _temporaryPlacedTiles.keys) {
           // Only mark as valid if not part of an invalid cross-word
           if (!invalidWordCoords.contains(coord)) {
               _tileValidationStatus[coord] = true;
           } else {
               _tileValidationStatus[coord] = false; // Part of an invalid word
           }
        }
         // If any part was invalid, reset score and mark all as invalid
         if (invalidWordCoords.isNotEmpty) {
             _potentialScore = 0;
             _markAllTemporaryTilesInvalid(updateState: false); // Already in setState
         }

      } else {
        _potentialScore = 0;
        // Mark tiles involved in invalid words as false, others as potentially true (if not involved)
         for (var coord in _temporaryPlacedTiles.keys) {
             if (invalidWordCoords.contains(coord)) {
                 _tileValidationStatus[coord] = false;
             } else {
                 // This tile might be part of a valid word, but another word was invalid.
                 // Keep it null or potentially mark true if needed elsewhere? For now, mark false.
                 _tileValidationStatus[coord] = false; // Simplification: if any word invalid, all placed tiles are marked red
             }
         }
      }
       print("Final Score: $_potentialScore, Validation Status: $_tileValidationStatus");
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


  // Helper to mark all temporary tiles as invalid
  void _markAllTemporaryTilesInvalid({bool updateState = true}) {
    Map<(int, int), bool?> newStatus = {};
    for (var coord in _temporaryPlacedTiles.keys) {
      newStatus[coord] = false;
    }
     if (updateState) {
        setState(() {
            _tileValidationStatus = newStatus;
            _potentialScore = 0;
        });
     } else {
         _tileValidationStatus = newStatus;
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