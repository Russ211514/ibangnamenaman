/**
 * Godot WebSocket Relay Server for Itch.io Multiplayer
 * 
 * Simple relay server that routes messages between game clients in rooms
 * 
 * Usage:
 *   npm install ws express cors
 *   node relay-server.js
 * 
 * Environment Variables:
 *   PORT: Server port (default: 8080)
 *   NODE_ENV: Set to 'production' for production deployment
 */

const WebSocket = require('ws');
const http = require('http');
const express = require('express');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

// In-memory storage for rooms
const rooms = new Map();
const clientRooms = new Map();

// CORS middleware
app.use(cors());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Stats endpoint
app.get('/stats', (req, res) => {
  const stats = {
    activeRooms: rooms.size,
    totalClients: clientRooms.size,
    rooms: Array.from(rooms.entries()).map(([code, clients]) => ({
      code,
      playerCount: clients.length
    }))
  };
  res.json(stats);
});

// WebSocket connection handler
wss.on('connection', (ws) => {
  const clientId = Math.random().toString(36).substr(2, 9);
  console.log(`[${new Date().toISOString()}] Client connected: ${clientId}`);

  let currentRoom = null;

  ws.on('message', (rawMessage) => {
    try {
      const message = JSON.parse(rawMessage.toString());
      handleMessage(ws, message, clientId, (room) => {
        currentRoom = room;
      });
    } catch (error) {
      console.error(`[${clientId}] Error processing message:`, error);
      ws.send(JSON.stringify({ type: 'error', message: 'Invalid message format' }));
    }
  });

  ws.on('close', () => {
    if (currentRoom && rooms.has(currentRoom)) {
      const roomClients = rooms.get(currentRoom);
      const index = roomClients.indexOf(ws);
      if (index > -1) {
        roomClients.splice(index, 1);
      }

      // Clean up empty rooms
      if (roomClients.length === 0) {
        rooms.delete(currentRoom);
        console.log(`[${new Date().toISOString()}] Room ${currentRoom} deleted (empty)`);
      } else {
        // Notify remaining players
        broadcast(currentRoom, JSON.stringify({ type: 'player_disconnected' }), ws);
      }
    }
    clientRooms.delete(ws);
    console.log(`[${new Date().toISOString()}] Client disconnected: ${clientId}`);
  });

  ws.on('error', (error) => {
    console.error(`[${clientId}] WebSocket error:`, error);
  });
});

/**
 * Handle incoming messages from clients
 */
function handleMessage(ws, message, clientId, setRoom) {
  switch (message.type) {
    case 'create_room':
      handleCreateRoom(ws, message, clientId, setRoom);
      break;

    case 'join_room':
      handleJoinRoom(ws, message, clientId, setRoom);
      break;

    case 'leave_room':
      handleLeaveRoom(ws, message, clientId);
      break;

    case 'game_message':
      handleGameMessage(ws, message, clientId);
      break;

    case 'ping':
      ws.send(JSON.stringify({ type: 'pong', timestamp: Date.now() }));
      break;

    default:
      console.warn(`[${clientId}] Unknown message type: ${message.type}`);
  }
}

/**
 * Create a new game room
 */
function handleCreateRoom(ws, message, clientId, setRoom) {
  const roomCode = message.room_code;
  const playerName = message.player_name || `Player${clientId}`;

  if (!roomCode) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room code required' }));
    return;
  }

  // Check if room already exists
  if (rooms.has(roomCode)) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room already exists' }));
    return;
  }

  // Create new room
  rooms.set(roomCode, [ws]);
  clientRooms.set(ws, { room: roomCode, name: playerName, isHost: true });
  setRoom(roomCode);

  console.log(`[${new Date().toISOString()}] Room created: ${roomCode} by ${playerName} (${clientId})`);
  
  ws.send(JSON.stringify({
    type: 'room_created',
    room_code: roomCode,
    message: `Room ${roomCode} created successfully`
  }));
}

/**
 * Join an existing game room
 */
function handleJoinRoom(ws, message, clientId, setRoom) {
  const roomCode = message.room_code;
  const playerName = message.player_name || `Player${clientId}`;

  if (!roomCode) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room code required' }));
    return;
  }

  if (!rooms.has(roomCode)) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
    return;
  }

  const roomClients = rooms.get(roomCode);

  // Check room capacity (max 2 players for your game)
  if (roomClients.length >= 2) {
    ws.send(JSON.stringify({ type: 'error', message: 'Room is full' }));
    return;
  }

  // Add client to room
  roomClients.push(ws);
  clientRooms.set(ws, { room: roomCode, name: playerName, isHost: false });
  setRoom(roomCode);

  console.log(`[${new Date().toISOString()}] ${playerName} joined room ${roomCode} (${clientId})`);

  // Notify all players in the room
  broadcast(roomCode, JSON.stringify({
    type: 'player_joined',
    player_name: playerName,
    total_players: roomClients.length
  }), null);

  ws.send(JSON.stringify({
    type: 'room_joined',
    room_code: roomCode,
    message: `Successfully joined room ${roomCode}`
  }));
}

/**
 * Leave a game room
 */
function handleLeaveRoom(ws, message, clientId) {
  const clientInfo = clientRooms.get(ws);
  if (!clientInfo) return;

  const roomCode = clientInfo.room;
  const roomClients = rooms.get(roomCode);

  if (roomClients) {
    const index = roomClients.indexOf(ws);
    if (index > -1) {
      roomClients.splice(index, 1);
    }

    if (roomClients.length === 0) {
      rooms.delete(roomCode);
      console.log(`[${new Date().toISOString()}] Room ${roomCode} deleted`);
    } else {
      broadcast(roomCode, JSON.stringify({ type: 'player_left' }), ws);
    }
  }

  clientRooms.delete(ws);
}

/**
 * Relay game messages to other players in the room
 */
function handleGameMessage(ws, message, clientId) {
  const clientInfo = clientRooms.get(ws);
  if (!clientInfo) {
    ws.send(JSON.stringify({ type: 'error', message: 'Not connected to a room' }));
    return;
  }

  const roomCode = clientInfo.room;
  broadcast(roomCode, rawMessage, ws);
}

/**
 * Broadcast a message to all clients in a room (optionally excluding sender)
 */
function broadcast(roomCode, message, excludeClient = null) {
  if (!rooms.has(roomCode)) return;

  const roomClients = rooms.get(roomCode);
  roomClients.forEach(client => {
    if (client !== excludeClient && client.readyState === WebSocket.OPEN) {
      client.send(message);
    }
  });
}

// Start server
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`
╔════════════════════════════════════════════════════╗
║   Godot WebSocket Relay Server                     ║
║   Status: Running                                  ║
║   URL: ws://localhost:${PORT}                        ║
║   Health: http://localhost:${PORT}/health           ║
║   Stats: http://localhost:${PORT}/stats             ║
╚════════════════════════════════════════════════════╝
  `);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\nShutting down server...');
  wss.clients.forEach(client => {
    client.close();
  });
  server.close(() => {
    console.log('Server closed');
    process.exit(0);
  });
});
