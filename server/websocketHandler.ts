import { WebSocketServer, WebSocket } from 'ws';
import { RoomManager } from './roomManager.js';

interface WebSocketMessage {
  type: string;
  roomId?: string;
  clientId?: string;
  from?: string;
  to?: string;
  payload?: any;
}

export function setupWebSocketHandler(wss: WebSocketServer, roomManager: RoomManager) {
  wss.on('connection', (ws: WebSocket, req) => {
    console.log('New WebSocket connection');
    
    let currentRoomId: string | null = null;
    let currentClientId: string | null = null;

    // Rate limiting for WebSocket messages
    let messageCount = 0;
    let resetTime = Date.now() + 60000; // 1 minute window
    const MESSAGE_LIMIT = 200; // messages per minute

    ws.on('message', (data: Buffer) => {
      try {
        // Rate limiting check
        const now = Date.now();
        if (now > resetTime) {
          messageCount = 0;
          resetTime = now + 60000;
        }
        
        if (messageCount >= MESSAGE_LIMIT) {
          ws.send(JSON.stringify({ 
            type: 'error', 
            message: 'Rate limit exceeded' 
          }));
          return;
        }
        messageCount++;

        const message: WebSocketMessage = JSON.parse(data.toString());
        
        // Validate message format
        if (!message.type || typeof message.type !== 'string') {
          ws.send(JSON.stringify({ 
            type: 'error', 
            message: 'Invalid message format' 
          }));
          return;
        }

        switch (message.type) {
          case 'init':
            handleInit(message, ws, roomManager);
            break;
          
          case 'offer':
          case 'answer':
          case 'ice-candidate':
            handleSignaling(message, roomManager);
            break;
          
          default:
            ws.send(JSON.stringify({ 
              type: 'error', 
              message: 'Unknown message type' 
            }));
        }

      } catch (error) {
        console.error('Error processing WebSocket message:', error);
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Invalid message format' 
        }));
      }
    });

    ws.on('close', () => {
      console.log('WebSocket connection closed');
      if (currentRoomId && currentClientId) {
        roomManager.removeClientFromRoom(currentRoomId, currentClientId);
        
        // Notify other peers that this client left
        roomManager.broadcastToRoom(currentRoomId, {
          type: 'peer-left',
          clientId: currentClientId
        }, currentClientId);
      }
    });

    ws.on('error', (error) => {
      console.error('WebSocket error:', error);
    });

    function handleInit(message: WebSocketMessage, ws: WebSocket, roomManager: RoomManager) {
      const { roomId, clientId } = message;
      
      if (!roomId || !clientId) {
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Room ID and client ID are required' 
        }));
        return;
      }

      // Validate input
      if (typeof roomId !== 'string' || typeof clientId !== 'string') {
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Invalid room ID or client ID format' 
        }));
        return;
      }

      const room = roomManager.getRoom(roomId);
      if (!room) {
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Room not found' 
        }));
        return;
      }

      // Store current connection info
      currentRoomId = roomId;
      currentClientId = clientId;

      // Add client to room
      const peers = roomManager.addClientToRoom(roomId, clientId, ws);
      
      // Send current peers to the new client
      ws.send(JSON.stringify({
        type: 'init-success',
        peers: peers.filter(id => id !== clientId)
      }));

      // Notify other peers about the new client
      roomManager.broadcastToRoom(roomId, {
        type: 'peer-joined',
        clientId: clientId
      }, clientId);

      console.log(`Client ${clientId} joined room ${roomId}`);
    }

    function handleSignaling(message: WebSocketMessage, roomManager: RoomManager) {
      const { from, to, payload, type } = message;
      
      if (!from || !to || !currentRoomId) {
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Invalid signaling message' 
        }));
        return;
      }

      const room = roomManager.getRoom(currentRoomId);
      if (!room) {
        ws.send(JSON.stringify({ 
          type: 'error', 
          message: 'Room not found' 
        }));
        return;
      }

      const targetWs = room.clients.get(to);
      if (targetWs && targetWs.readyState === WebSocket.OPEN) {
        try {
          targetWs.send(JSON.stringify({
            type,
            from,
            to,
            payload
          }));
        } catch (error) {
          console.error(`Error sending signaling message to ${to}:`, error);
          room.clients.delete(to);
        }
      }
    }
  });

  console.log('WebSocket handler configured');
}
