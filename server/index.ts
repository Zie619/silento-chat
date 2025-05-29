import express from 'express';
import http from 'http';
import cors from 'cors';
import { setupRoutes } from './routes.js';

const app = express();
const server = http.createServer(app);

// Environment configuration
const isDevelopment = process.env.NODE_ENV !== 'production';
const PORT = parseInt(process.env.PORT || '5001', 10);

// CORS configuration for production
const corsOptions = {
  origin: isDevelopment 
    ? ['http://localhost:3000', 'http://127.0.0.1:3000']
    : [
        'https://your-frontend-domain.com', // Replace with your actual frontend domain
        /^https:\/\/.*\.railway\.app$/, // Allow Railway preview deployments
        /^https:\/\/.*\.vercel\.app$/, // Allow Vercel deployments
        /^https:\/\/.*\.netlify\.app$/, // Allow Netlify deployments
      ],
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization']
};

// Middleware
app.use(cors(corsOptions));
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    environment: process.env.NODE_ENV || 'development'
  });
});

// Rate limiting middleware
const requestCounts = new Map<string, { count: number; resetTime: number }>();
const RATE_LIMIT = 100; // requests per minute
const RATE_WINDOW = 60 * 1000; // 1 minute

app.use((req: any, res: any, next: any) => {
  const clientIp = req.ip || req.socket?.remoteAddress || 'unknown';
  const now = Date.now();
  
  const clientData = requestCounts.get(clientIp);
  if (!clientData || now > clientData.resetTime) {
    requestCounts.set(clientIp, { count: 1, resetTime: now + RATE_WINDOW });
    return next();
  }
  
  if (clientData.count >= RATE_LIMIT) {
    return res.status(429).json({ error: 'Rate limit exceeded' });
  }
  
  clientData.count++;
  next();
});

// Setup routes and WebSocket
setupRoutes(app, server);

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
});

// Cleanup interval for rate limiting
setInterval(() => {
  const now = Date.now();
  for (const [ip, data] of requestCounts.entries()) {
    if (now > data.resetTime) {
      requestCounts.delete(ip);
    }
  }
}, 60000);

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('SIGTERM received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});

process.on('SIGINT', () => {
  console.log('SIGINT received, shutting down gracefully');
  server.close(() => {
    console.log('Process terminated');
  });
});
