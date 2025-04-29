import 'dart:async';
// No Flutter imports needed here
import 'package:flutter_application_1/resources/socket_client.dart';
// No Provider or Utils import needed here

class SocketMethods {
  final _socketClient = SocketClient.instance.socket!;

  // Store listener references for potential removal
  // Use the correct type: dynamic Function(dynamic)?
  // socket_io_client expects dynamic Function(dynamic) for handlers
  dynamic Function(dynamic)? _updateRoomHandler;
  dynamic Function(dynamic)? _errorHandler;
  dynamic Function(dynamic)? _matchFoundHandler;

  void findMatch(String nickname, String selectedMode) {
    if (nickname.isNotEmpty) {
      _socketClient.emit('findMatch', {
        'nickname': nickname,
        'selectedMode': selectedMode,
      });
    }
  }

  // Listener setup now takes callbacks with 'dynamic' data type
  // The caller (widget) is responsible for type checking/casting and context safety
  // Callback type should match what the handler expects
  void matchFoundListener(dynamic Function(dynamic roomData) onMatchFound) {
     _matchFoundHandler = (room) {
        print("[SocketMethods] Received matchFound event.");
        onMatchFound(room); // Call the provided callback
     };
    // Pass the non-nullable handler
    if (_matchFoundHandler != null) {
      _socketClient.on('matchFound', _matchFoundHandler!);
    }
  }

  void updateRoomListener(dynamic Function(dynamic roomData) onUpdateRoom) {
     _updateRoomHandler = (data) {
        print("[SocketMethods] Received updateRoom event. Data: $data");
        if (data != null && data is Map && data.containsKey('room')) {
          onUpdateRoom(data['room']); // Call the provided callback
        } else {
          print("[SocketMethods] Received invalid updateRoom data structure: $data");
        }
     };
    if (_updateRoomHandler != null) {
      _socketClient.on('updateRoom', _updateRoomHandler!);
    }
  }

  void errorOccurredListener(dynamic Function(dynamic errorData) onError) {
     _errorHandler = (data) {
        print("[SocketMethods] Received error event. Data: $data");
        onError(data); // Call the provided callback
     };
    if (_errorHandler != null) {
      _socketClient.on('error', _errorHandler!);
    }
  }

  void confirmMove(String roomId, List<Map<String, dynamic>> placements) { // Removed BuildContext
     if (placements.isEmpty) {
       print("Cannot confirm empty move.");
       // Consider how to show feedback without context, maybe return a bool/Future?
       // Or rely on the error listener if server rejects empty move.
       return;
     }
    _socketClient.emit('confirmMove', {
      'roomId': roomId,
      'placements': placements,
    });
  }

  // Method to remove listeners (call from relevant screen's dispose)
  void removeListeners() {
      print("[SocketMethods] Removing listeners...");
      if (_updateRoomHandler != null) {
          _socketClient.off('updateRoom', _updateRoomHandler);
          _updateRoomHandler = null; // Clear reference
      }
      if (_errorHandler != null) {
          _socketClient.off('error', _errorHandler);
          _errorHandler = null; // Clear reference
      }
      if (_matchFoundHandler != null) {
          _socketClient.off('matchFound', _matchFoundHandler);
          _matchFoundHandler = null; // Clear reference
      }
      // Add other listeners if needed
  }
}
