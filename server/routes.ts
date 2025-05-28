import { Express } from 'express';
import { Server as HttpServer } from 'http';
import { WebSocketServer } from 'ws';
import { RoomManager } from './roomManager.js';
import { setupWebSocketHandler } from './websocketHandler.js';

const roomManager = new RoomManager();

export function setupRoutes(app: Express, httpServer: HttpServer) {
  // REST API Routes
  app.post('/api/create-room', (req, res) => {
    try {
      const roomId = roomManager.createRoom();
      res.json({ roomId });
    } catch (error) {
      console.error('Error creating room:', error);
      res.status(500).json({ error: 'Failed to create room' });
    }
  });

  app.post('/api/join-room', (req, res) => {
    try {
      const { roomId, clientId } = req.body;
      
      if (!roomId || !clientId) {
        return res.status(400).json({ error: 'Room ID and client ID are required' });
      }

      if (typeof roomId !== 'string' || typeof clientId !== 'string') {
        return res.status(400).json({ error: 'Invalid room ID or client ID format' });
      }

      const room = roomManager.getRoom(roomId);
      if (!room) {
        return res.status(404).json({ error: 'Room not found' });
      }

      const peers = roomManager.addClientToRoom(roomId, clientId);
      res.json({ peers });
    } catch (error) {
      console.error('Error joining room:', error);
      res.status(500).json({ error: 'Failed to join room' });
    }
  });

  app.get('/api/room/:roomId/status', (req, res) => {
    try {
      const { roomId } = req.params;
      const room = roomManager.getRoom(roomId);
      
      if (!room) {
        return res.status(404).json({ error: 'Room not found' });
      }

      res.json({
        roomId,
        peerCount: room.clients.size,
        peers: Array.from(room.clients.keys()),
        createdAt: room.createdAt
      });
    } catch (error) {
      console.error('Error getting room status:', error);
      res.status(500).json({ error: 'Failed to get room status' });
    }
  });

  // WebSocket server setup on distinct path
  const wss = new WebSocketServer({ server: httpServer, path: '/ws' });
  setupWebSocketHandler(wss, roomManager);

  console.log('Routes and WebSocket server configured');
}
