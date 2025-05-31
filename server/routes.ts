import { Express, Request, Response } from 'express';
import { Server as HttpServer } from 'http';
import { WebSocketServer } from 'ws';
import multer from 'multer';
import path from 'path';
import crypto from 'crypto';
import { RoomManager } from './roomManager.js';
import { setupWebSocketHandler } from './websocketHandler.js';

const roomManager = new RoomManager();

// Configure multer for file uploads
const storage = multer.memoryStorage();
const upload = multer({
  storage: storage,
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
  fileFilter: (req: any, file: any, cb: any) => {
    // Allow images, videos, audio, and documents
    const allowedTypes = [
      'image/jpeg', 'image/png', 'image/gif', 'image/webp',
      'video/mp4', 'video/mov', 'video/avi', 'video/webm',
      'audio/mp3', 'audio/wav', 'audio/m4a', 'audio/aac',
      'application/pdf', 'text/plain'
    ];
    
    if (allowedTypes.includes(file.mimetype)) {
      cb(null, true);
    } else {
      cb(new Error('Invalid file type'));
    }
  }
});

// Store uploaded files temporarily (in production, use cloud storage)
const uploadedFiles = new Map<string, {
  buffer: Buffer;
  mimetype: string;
  originalname: string;
  uploadedAt: number;
}>();

// Clean up old files every hour
setInterval(() => {
  const oneHour = 60 * 60 * 1000;
  const now = Date.now();
  for (const [fileId, file] of uploadedFiles.entries()) {
    if (now - file.uploadedAt > oneHour) {
      uploadedFiles.delete(fileId);
    }
  }
}, 60 * 60 * 1000);

export function setupRoutes(app: Express, httpServer: HttpServer) {
  // File upload endpoint
  app.post('/api/upload', upload.single('file'), (req: any, res: any) => {
    try {
      if (!req.file) {
        return res.status(400).json({ error: 'No file uploaded' });
      }

      // Generate unique file ID
      const fileId = crypto.randomUUID();
      
      // Store file in memory (in production, upload to cloud storage)
      uploadedFiles.set(fileId, {
        buffer: req.file.buffer,
        mimetype: req.file.mimetype,
        originalname: req.file.originalname,
        uploadedAt: Date.now()
      });

      res.json({
        fileId,
        fileName: req.file.originalname,
        fileSize: req.file.size,
        mimeType: req.file.mimetype,
        url: `/api/file/${fileId}`
      });
    } catch (error) {
      console.error('Error uploading file:', error);
      res.status(500).json({ error: 'Failed to upload file' });
    }
  });

  // File download endpoint
  app.get('/api/file/:fileId', (req: any, res: any) => {
    try {
      const { fileId } = req.params;
      const file = uploadedFiles.get(fileId);
      
      if (!file) {
        return res.status(404).json({ error: 'File not found' });
      }

      res.set({
        'Content-Type': file.mimetype,
        'Content-Length': file.buffer.length,
        'Content-Disposition': `attachment; filename="${file.originalname}"`
      });
      
      res.send(file.buffer);
    } catch (error) {
      console.error('Error downloading file:', error);
      res.status(500).json({ error: 'Failed to download file' });
    }
  });

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

  app.post('/api/join-room', (req: any, res: any) => {
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

  app.get('/api/room/:roomId/status', (req: any, res: any) => {
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
