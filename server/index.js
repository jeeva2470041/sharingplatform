const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

app.get('/', (req, res) => {
  res.send('Socket.IO Server is running. Connect via WebSocket client.');
});

// Groq API Proxy Endpoint
app.post('/api/groq/chat', async (req, res) => {
  try {
    const { messages } = req.body;
    const apiKey = process.env.GROK_API_KEY;

    if (!apiKey) {
      return res.status(500).json({ error: 'GROK_API_KEY not configured on server' });
    }

    const fetch = (await import('node-fetch')).default;
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        messages: messages,
      }),
    });

    const data = await response.json();
    
    if (response.ok) {
      res.json(data);
    } else {
      res.status(response.status).json(data);
    }
  } catch (error) {
    console.error('Error proxying Groq request:', error);
    res.status(500).json({ error: error.message });
  }
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
    const room = String(itemId);
    socket.join(room);
    console.log(`User ${socket.id} joined room: ${room}`);

    // Send previous messages if they exist
    if (chatHistory[room]) {
      socket.emit('previousMessages', chatHistory[room]);
    }
  });

  socket.on('sendMessage', (data) => {
    // data should contain: { itemId, senderId, text, timestamp }
    console.log('Message received:', data);
    const room = String(data.itemId);

    // Store the new message
    if (!chatHistory[room]) {
      chatHistory[room] = [];
    }
    chatHistory[room].push(data);

    // Broadcast to everyone in the room (including sender)
    io.to(room).emit('receiveMessage', data);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});

const PORT = 3000;
server.listen(PORT, () => {
  console.log(`Socket.IO server running on http://localhost:${PORT}`);
});
