const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

app.get('/', (req, res) => {
  res.send('Socket.IO Server is running. Connect via WebSocket client.');
});

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*", // Allow all origins for development
    methods: ["GET", "POST"]
  }
});

const chatHistory = {}; // In-memory store for chat messages

io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('joinRoom', (itemId) => {
    socket.join(itemId);
    console.log(`User ${socket.id} joined room: ${itemId}`);

    // Send previous messages if they exist
    if (chatHistory[itemId]) {
      socket.emit('previousMessages', chatHistory[itemId]);
    }
  });

  socket.on('sendMessage', (data) => {
    // data should contain: { itemId, senderId, text, timestamp }
    console.log('Message received:', data);

    // Store the new message
    if (!chatHistory[data.itemId]) {
      chatHistory[data.itemId] = [];
    }
    chatHistory[data.itemId].push(data);
    
    // Broadcast to everyone in the room (including sender)
    io.to(data.itemId).emit('receiveMessage', data);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`Socket.IO server running on http://localhost:${PORT}`);
});
