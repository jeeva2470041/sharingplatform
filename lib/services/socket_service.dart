import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class SocketService {
  late io.Socket socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void initSocket() {
    // Replace with your actual server IP
    // For Android Emulator use: http://10.0.2.2:3000
    // For iOS Simulator use: http://localhost:3000
    // For Real Device use: http://YOUR_PC_IP:3000
    const String serverUrl = 'http://localhost:3000'; 

    socket = io.io(serverUrl, io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    socket.connect();

    socket.onConnect((_) {
      debugPrint('Connected to socket server');
      _isConnected = true;
    });

    socket.onDisconnect((_) {
      debugPrint('Disconnected from socket server');
      _isConnected = false;
    });

    socket.onConnectError((data) {
      debugPrint('Connect Error: $data');
    });
  }

  void joinRoom(String itemId) {
    if (!_isConnected) {
      socket.connect();
    }
    socket.emit('joinRoom', itemId);
  }

  void sendMessage(String itemId, String senderId, String text) {
    socket.emit('sendMessage', {
      'itemId': itemId,
      'senderId': senderId,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  void disconnect() {
    socket.disconnect();
  }
}
