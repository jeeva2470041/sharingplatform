import 'package:socket_io_client/socket_io_client.dart' as IO;

class SocketService {
  late IO.Socket socket;
  bool _isConnected = false;

  bool get isConnected => _isConnected;

  void initSocket() {
    // Replace with your actual server IP
    // For Android Emulator use: http://10.0.2.2:3000
    // For iOS Simulator use: http://localhost:3000
    // For Real Device use: http://YOUR_PC_IP:3000
    const String serverUrl = 'http://localhost:3000'; 

    socket = IO.io(serverUrl, IO.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .build());

    socket.connect();

    socket.onConnect((_) {
      print('Connected to socket server');
      _isConnected = true;
    });

    socket.onDisconnect((_) {
      print('Disconnected from socket server');
      _isConnected = false;
    });

    socket.onConnectError((data) {
      print('Connect Error: $data');
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
