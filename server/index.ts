import express from 'express';
import http from 'http';
import cors from 'cors';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';
import { setupRoutes } from './routes.js';

const app = express();
const server = http.createServer(app);

// Get directory paths for ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Environment configuration
const isDevelopment = process.env.NODE_ENV !== 'production';
const PORT = parseInt(process.env.PORT || '5001', 10);

// CORS configuration for production
const corsOptions = {
  origin: isDevelopment 
    ? ['http://localhost:3000', 'http://127.0.0.1:3000']
    : [
        'https://silento-backend.onrender.com', // Your actual backend domain
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

// Serve static files from React build (production only)
if (!isDevelopment) {
  // Try multiple possible paths for the React build
  const possiblePaths = [
    path.resolve(process.cwd(), 'dist'),
    path.resolve(__dirname, '..', '..', 'dist'),
    path.resolve(__dirname, '..', 'dist'),
    path.resolve('/opt/render/project/src/dist')
  ];
  
  let buildPath = possiblePaths[0]; // default
  
  // Find the correct path that exists
  for (const testPath of possiblePaths) {
    try {
      if (fs.existsSync(testPath) && fs.existsSync(path.join(testPath, 'index.html'))) {
        buildPath = testPath;
        break;
      }
    } catch (e) {
      // ignore errors, continue checking
    }
  }
  
  console.log(`Serving static files from: ${buildPath}`);
  console.log(`Current working directory: ${process.cwd()}`);
  console.log(`Server __dirname: ${__dirname}`);
  console.log(`Checking if index.html exists: ${fs.existsSync(path.join(buildPath, 'index.html'))}`);
  
  app.use(express.static(buildPath));
}

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

// Setup API routes and WebSocket
setupRoutes(app, server);

// Serve React app for all non-API routes (production only)
if (!isDevelopment) {
  app.get('*', (req, res) => {
    const indexPath = path.resolve(process.cwd(), 'dist', 'index.html');
    console.log(`Serving React app from: ${indexPath}`);
    res.sendFile(indexPath);
  });
}

server.listen(PORT, '0.0.0.0', () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  if (!isDevelopment) {
    console.log(`Frontend served from: ${path.resolve(process.cwd(), 'dist')}`);
  }
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
