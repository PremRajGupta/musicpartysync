const express = require('express');
const http = require('http');
const WebSocket = require('ws');
const cors = require('cors');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

const app = express();
app.use(cors());

const frontendUrl = process.env.FRONTEND_URL || 'https://music-party-clg-2026.web.app/';

app.get('/', (req, res) => {
  res.redirect(frontendUrl);
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Set up storage for uploaded songs
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
  fs.mkdirSync(uploadsDir);
}

const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'uploads/');
  },
  filename: function (req, file, cb) {
    // Keep the original filename but make it safe
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  }
});
const upload = multer({ storage: storage });

// Serve static files from 'uploads' directory
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

app.post('/upload', upload.single('song'), (req, res) => {
  if (!req.file) {
    return res.status(400).send('No file uploaded.');
  }
  
  const fileUrl = `/uploads/${req.file.filename}`;
  res.json({ url: fileUrl });
});

const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// Room state: { roomId: { hostId: ws, clients: [ws], state: { ... } } }
const rooms = new Map();

function generateRoomId() {
  return Math.random().toString(36).substring(2, 8).toUpperCase();
}

wss.on('connection', (ws) => {
  console.log('New client connected');
  let currentRoom = null;
  let isHost = false;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      console.log('Received:', data);

      if (data.type === 'create_room') {
        const roomId = generateRoomId();
        rooms.set(roomId, {
          host: ws,
          clients: new Set(),
          state: { status: 'paused', position: 0, timestamp: Date.now() }
        });
        currentRoom = roomId;
        isHost = true;
        ws.send(JSON.stringify({ type: 'room_created', roomId }));
        console.log(`Room ${roomId} created`);
      } 
      else if (data.type === 'join_room') {
        const roomId = data.roomId;
        if (rooms.has(roomId)) {
          const room = rooms.get(roomId);
          room.clients.add(ws);
          currentRoom = roomId;
          ws.send(JSON.stringify({ type: 'room_joined', roomId, state: room.state }));
          console.log(`Client joined room ${roomId}`);
        } else {
          ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
        }
      }
      else if (data.type === 'sync_state' && isHost && currentRoom) {
        const room = rooms.get(currentRoom);
        room.state = data.state;
        
        // Broadcast to clients
        const messageStr = JSON.stringify({ type: 'sync_state', state: room.state });
        for (let client of room.clients) {
          if (client.readyState === WebSocket.OPEN) {
            client.send(messageStr);
          }
        }
      }
    } catch (e) {
      console.error('Error parsing message', e);
    }
  });

  ws.on('close', () => {
    console.log('Client disconnected');
    if (currentRoom && rooms.has(currentRoom)) {
      const room = rooms.get(currentRoom);
      if (isHost) {
        // Host left, notify clients and delete room
        for (let client of room.clients) {
          if (client.readyState === WebSocket.OPEN) {
            client.send(JSON.stringify({ type: 'host_left' }));
          }
        }
        rooms.delete(currentRoom);
      } else {
        room.clients.delete(ws);
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server listening on port ${PORT}`);
});
