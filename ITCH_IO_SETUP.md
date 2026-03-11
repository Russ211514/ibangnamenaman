# Itch.io WebSocket Multiplayer Setup Guide

## Overview
The multiplayer code has been converted to support both traditional ENet (for desktop/local play) and WebSocket-based networking (for itch.io web hosting).

## Key Changes Made

### ✅ Automatic Detection
- The script automatically detects if running on web (`OS.get_name() == "Web"`)
- Automatically switches to WebSocket mode on web builds
- Falls back to ENet on desktop builds

### ✅ Dual Support
- **Desktop (ENet)**: Local network play on `127.0.0.1:9999` for testing
- **Web (WebSocket)**: Web-based play through a relay server

## Setting Up for Itch.io

### Option 1: Using a Public WebSocket Relay Server (Recommended for Beginners)

Services like these support WebSocket relay:
- **Nakama** (self-hosted or cloud)
- **PlayFab** (Microsoft Azure)
- **Firebase (Realtime Database)**
- **Colyseus** (Open-source multiplayer framework)

### Option 2: Self-Hosted WebSocket Relay Server

Here's a simple Node.js relay server example:

#### Server Setup (Node.js)

**1. Create a new folder for the server:**
```bash
mkdir godot-relay-server
cd godot-relay-server
npm init -y
npm install ws express
```

**2. Create `server.js`:**
```javascript
const WebSocket = require('ws');
const http = require('http');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

const rooms = {};
const clients = new Map();

wss.on('connection', (ws) => {
  console.log('Client connected');
  let currentRoom = null;

  ws.on('message', (message) => {
    try {
      const data = JSON.parse(message);
      
      if (data.type === 'create_room') {
        currentRoom = data.room_code;
        if (!rooms[currentRoom]) {
          rooms[currentRoom] = [];
        }
        rooms[currentRoom].push(ws);
        clients.set(ws, { room: currentRoom, name: data.player_name });
        console.log(`Room ${currentRoom} created by ${data.player_name}`);
      } 
      else if (data.type === 'join_room') {
        currentRoom = data.room_code;
        if (rooms[currentRoom]) {
          rooms[currentRoom].push(ws);
          clients.set(ws, { room: currentRoom, name: data.player_name });
          // Notify room that a player joined
          rooms[currentRoom].forEach(client => {
            if (client.readyState === WebSocket.OPEN) {
              client.send(JSON.stringify({
                type: 'player_joined',
                player_name: data.player_name
              }));
            }
          });
          console.log(`${data.player_name} joined room ${currentRoom}`);
        }
      }
      else if (data.type === 'game_message' && currentRoom && rooms[currentRoom]) {
        // Relay game messages to all players in the room
        rooms[currentRoom].forEach(client => {
          if (client.readyState === WebSocket.OPEN && client !== ws) {
            client.send(JSON.stringify(data));
          }
        });
      }
    } catch (e) {
      console.error('Error processing message:', e);
    }
  });

  ws.on('close', () => {
    const clientInfo = clients.get(ws);
    if (clientInfo && currentRoom && rooms[currentRoom]) {
      rooms[currentRoom] = rooms[currentRoom].filter(client => client !== ws);
      if (rooms[currentRoom].length === 0) {
        delete rooms[currentRoom];
      }
      console.log(`Client disconnected from room ${currentRoom}`);
    }
    clients.delete(ws);
  });
});

const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
  console.log(`WebSocket relay server running on ws://localhost:${PORT}`);
});
```

**3. Run the server:**
```bash
node server.js
```

### Updating the Godot Script for Your Server

Edit the `websocket_url` in [menu_&_server.gd](Scripts/menu_&_server.gd#L14):

```gdscript
@export var websocket_url = "ws://your-server.com:8080"  # Change to your server URL
```

## Deployment to Itch.io

### 1. Export as HTML5
- In Godot: File → Export Project
- Select HTML5 export template
- Make sure WebSocket is enabled in export settings

### 2. Host the WebSocket Relay Server
Options:
- **Heroku** (free tier): Deploy the Node.js relay server
- **AWS/DigitalOcean/Linode**: More reliable for production
- **Glitch.com**: Simple hosting with WebSocket support
- **Railway.app**: Easy deployment with automatic scaling

### 3. Update WebSocket URL
- Once your relay server is running, update the `websocket_url` in the script
- This should be the public URL of your relay server

### 4. Upload HTML5 Build to Itch.io
- Zip your exported HTML5 files
- Create a new project on itch.io
- Upload as "HTML" project type
- Enable "This file will be played in the browser"

## Testing

### Local Testing (Desktop)
- **ENet**: Host a game, join on localhost (both on same machine)

### Local Testing (WebSocket)
- Run the relay server locally: `ws://localhost:8080`
- Export as HTML5 and test in browser

### Production Testing on Itch.io
- Use your production WebSocket relay URL
- Store the URL in the `@export var websocket_url` or use environment variables

## Important Security Notes

⚠️ **For Production:**
1. **Add authentication** to prevent unauthorized access
2. **Validate room codes** on the server side
3. **Rate limit** connections per IP
4. **Use WSS (secure WebSocket)** instead of WS
5. **Add CORS headers** for cross-origin requests
6. **Validate all player input** on the server

## Code Structure

- **`_on_host_pressed()`**: Routes to WebSocket or ENet hosting
- **`_host_websocket()`**: Creates a room via WebSocket relay
- **`_on_join_pressed()`**: Routes to WebSocket or ENet joining
- **`_join_websocket()`**: Joins a room via WebSocket relay
- **`create_room()`**: RPC to create a room on the relay server
- **`join_room()`**: RPC to join a room on the relay server

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "WebSocket connection failed" | Check relay server URL and ensure server is running |
| Players can't see each other | Verify they're in the same room code |
| Connection dropped | Check network stability; implement reconnection logic |
| Room code mismatch | Ensure room codes are validated on server |

## URLs Reference

For production itch.io builds, you'll need:
- **WebSocket Relay Server**: `wss://your-relay-server.com:PORT`
- **Game Hosted On**: `https://yourname.itch.io/yourgame`

Both should be publicly accessible with proper CORS/security headers.
