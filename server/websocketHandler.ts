import { WebSocketServer, WebSocket } from 'ws';
import { RoomManager } from './roomManager.js';

interface WebSocketMessage {
  type: string;
  roomId?: string;
  clientId?: string;
  from?: string;
  to?: string;
  payload?: any;
  message?: string;
  content?: string;  // Add content field for iOS app compatibility
  messageType?: string;  // Add messageType field
  mediaURL?: string;  // Add mediaURL field
  fileName?: string;  // Add fileName field (already exists but different purpose)
  timestamp?: number;
  transferId?: string;
  fileType?: string;
  fileSize?: number;
  fileData?: string;
  chunkIndex?: number;
  totalChunks?: number;
  chunkData?: string;
}

function handleChatMessage(message: WebSocketMessage, roomManager: RoomManager, currentRoomId: string) {
  if (!message.roomId || !message.clientId || !currentRoomId) {
    return;
  }

  // Handle both 'content' (from iOS app) and 'message' (legacy) fields
  const messageContent = (message as any).content || message.message;
  
  if (!messageContent) {
    console.error('No message content provided');
    return;
  }

  console.log(`📤 Broadcasting message from ${message.clientId} to room ${currentRoomId}: "${messageContent}"`);

  // Broadcast message to all clients in the room except the sender
  roomManager.broadcastToRoom(currentRoomId, {
    type: 'message',
    clientId: message.clientId,
    content: messageContent,  // Use 'content' for consistency with iOS app
    messageType: (message as any).messageType || 'text',
    mediaURL: (message as any).mediaURL || '',
    fileName: (message as any).fileName || '',
    timestamp: message.timestamp || Date.now()
  }, message.clientId);  // Exclude sender
}

function handleFileMessage(message: WebSocketMessage, roomManager: RoomManager, currentRoomId: string) {
  if (!message.roomId || !message.clientId || !currentRoomId) {
    return;
  }

  // Broadcast file message to all clients in the room except sender
  roomManager.broadcastToRoom(currentRoomId, message, message.clientId);
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
          
          case 'message':
            if (currentRoomId && currentClientId) {
              handleChatMessage(message, roomManager, currentRoomId);
            }
            break;
            
          case 'file-start':
          case 'file-offer':
          case 'file-chunk':
          case 'file-complete':
            if (currentRoomId && currentClientId) {
              handleFileMessage(message, roomManager, currentRoomId);
            }
            break;
          
          case 'offer':
          case 'answer':
          case 'ice-candidate':
            handleSignaling(message, roomManager);
            break;
          
          default:
            ws.send(JSON.stringify({ 
              type: 'error', 
              message: 'Unknown message type: ' + message.type 
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
