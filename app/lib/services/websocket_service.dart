import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:just_audio/just_audio.dart';

class WebSocketService extends ChangeNotifier {
  WebSocketChannel? _channel;
  String? currentRoom;
  bool isHost = false;
  
  // Player state variables
  String status = 'paused';
  double position = 0;
  String? currentSongUrl;
  
  final AudioPlayer audioPlayer = AudioPlayer();

  // Use the live Render backend URL
  final String serverHost = 'musicpartysync.onrender.com';
  String get serverWsUrl => 'wss://$serverHost';
  String get serverHttpUrl => 'https://$serverHost';

  int _lastSyncTime = 0;

  WebSocketService() {
    // Listen to local player position to update UI locally
    audioPlayer.positionStream.listen((pos) {
      if (isHost && status == 'playing') {
        position = pos.inMilliseconds / 1000.0;
        notifyListeners();
        // Sync position to clients every 3 seconds to avoid flooding
        int now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSyncTime > 3000) {
          _lastSyncTime = now;
          _sendSyncState(status, position);
        }
      }
    });
    
    audioPlayer.playerStateStream.listen((state) {
      if (!isHost) return;
      if (state.processingState == ProcessingState.completed) {
         syncState('paused', 0);
      }
    });
  }

  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(serverWsUrl));
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _handleMessage(data);
        },
        onError: (error) => print("WebSocket error: $error"),
        onDone: () => print("WebSocket connection closed"),
      );
    } catch (e) {
      print("Error connecting: $e");
    }
  }

  Future<void> _handleMessage(Map<String, dynamic> data) async {
    switch (data['type']) {
      case 'room_created':
        currentRoom = data['roomId'];
        isHost = true;
        notifyListeners();
        break;
      case 'room_joined':
        currentRoom = data['roomId'];
        isHost = false;
        await _updateState(data['state']);
        notifyListeners();
        break;
      case 'sync_state':
        await _updateState(data['state']);
        break;
      case 'host_left':
        currentRoom = null;
        isHost = false;
        await audioPlayer.stop();
        notifyListeners();
        break;
      case 'error':
        print("Error from server: ${data['message']}");
        break;
    }
  }

  Future<void> _updateState(Map<String, dynamic> state) async {
    // Handle new song URL
    String? newUrl = state['songUrl'];
    if (newUrl != null && newUrl != currentSongUrl) {
      currentSongUrl = newUrl;
      await audioPlayer.setUrl(serverHttpUrl + currentSongUrl!);
    }

    String newStatus = state['status'] ?? 'paused';
    double newPosition = (state['position'] ?? 0).toDouble();

    // Client syncing logic
    if (!isHost) {
      double currentPos = audioPlayer.position.inMilliseconds / 1000.0;
      // If position difference is more than 50ms, seek to sync precisely
      if ((currentPos - newPosition).abs() > 0.05) {
        await audioPlayer.seek(Duration(milliseconds: (newPosition * 1000).toInt()));
      }
      
      if (newStatus == 'playing' && audioPlayer.playing == false) {
        audioPlayer.play();
      } else if (newStatus == 'paused' && audioPlayer.playing == true) {
        audioPlayer.pause();
      }
    }
    
    status = newStatus;
    position = newPosition;
    notifyListeners();
  }

  void createRoom() {
    if (_channel == null) connect();
    _channel?.sink.add(jsonEncode({'type': 'create_room'}));
  }

  void joinRoom(String roomId) {
    if (_channel == null) connect();
    _channel?.sink.add(jsonEncode({'type': 'join_room', 'roomId': roomId}));
  }

  void syncState(String newStatus, double newPosition) {
    if (!isHost || currentRoom == null) return;
    
    status = newStatus;
    position = newPosition;
    
    if (newStatus == 'playing') {
      audioPlayer.play();
    } else {
      audioPlayer.pause();
    }
    
    _sendSyncState(newStatus, newPosition);
    notifyListeners();
  }
  
  void _sendSyncState(String s, double p) {
    _channel?.sink.add(jsonEncode({
      'type': 'sync_state',
      'state': {
        'status': s,
        'position': p,
        'songUrl': currentSongUrl,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      }
    }));
  }
  
  void updateSongUrl(String url) {
    currentSongUrl = url;
    audioPlayer.setUrl(serverHttpUrl + url);
    _sendSyncState('paused', 0);
    notifyListeners();
  }

  void leaveRoom() {
    _channel?.sink.close();
    _channel = null;
    currentRoom = null;
    audioPlayer.stop();
    notifyListeners();
  }
}
