# Deployment Guide for Silento Chat App

This guide will help you deploy the Silento backend server to various cloud platforms.

## Option 1: Railway (Recommended)

Railway is a modern deployment platform that's perfect for Node.js applications.

### Steps:

1. **Create a Railway account**
   - Go to [railway.app](https://railway.app)
   - Sign up with GitHub

2. **Install Railway CLI** (optional)
   ```bash
   npm install -g @railway/cli
   railway login
   ```

3. **Deploy via GitHub (Recommended)**
   - Push your code to GitHub
   - Connect your GitHub repository to Railway
   - Railway will automatically detect and deploy your Node.js app

4. **Deploy via CLI**
   ```bash
   railway login
   railway init
   railway up
   ```

5. **Configure Environment Variables**
   - In Railway dashboard, go to your project
   - Add environment variable: `NODE_ENV=production`
   - Railway automatically provides `PORT` variable

6. **Get your deployment URL**
   - Railway will provide a URL like: `https://your-app-name.railway.app`

## Option 2: Render

1. **Create account at [render.com](https://render.com)**

2. **Create a new Web Service**
   - Connect your GitHub repository
   - Build Command: `npm install`
   - Start Command: `npm start`

3. **Environment Variables**
   - Add `NODE_ENV=production`

## Option 3: Heroku

1. **Install Heroku CLI**
   ```bash
   npm install -g heroku
   heroku login
   ```

2. **Create Heroku app**
   ```bash
   heroku create your-app-name
   ```

3. **Deploy**
   ```bash
   git push heroku main
   ```

4. **Set environment variables**
   ```bash
   heroku config:set NODE_ENV=production
   ```

## Option 4: DigitalOcean App Platform

1. **Create account at [digitalocean.com](https://digitalocean.com)**
2. **Create new App**
3. **Connect GitHub repository**
4. **Configure build settings**
   - Build Command: `npm install`
   - Run Command: `npm start`

## After Deployment

### 1. Update iOS App

Once deployed, update the iOS app to use the production server:

```swift
// In ios/Silento/ViewController.swift, change:
let urlString = "http://localhost:3000"
// To:
let urlString = "https://your-deployed-backend.railway.app"
```

### 2. Update Frontend Configuration

If you deploy the frontend separately, update the API endpoint:

```javascript
// In your frontend code, change:
const API_URL = 'http://localhost:5001'
// To:
const API_URL = 'https://your-deployed-backend.railway.app'
```

### 3. Update CORS Settings

In `server/index.ts`, update the CORS origins to include your frontend domain:

```typescript
const corsOptions = {
  origin: [
    'https://your-frontend-domain.com', // Your actual frontend domain
    'https://your-app.railway.app',
    // ... other domains
  ],
  // ...
};
```

## Testing Your Deployment

1. **Health Check**
   ```bash
   curl https://your-app.railway.app/health
   ```

2. **WebSocket Connection**
   - Test with a WebSocket client
   - URL: `wss://your-app.railway.app`

3. **API Endpoints**
   ```bash
   # Test room creation
   curl -X POST https://your-app.railway.app/api/rooms \
     -H "Content-Type: application/json" \
     -d '{"roomId": "TEST123"}'
   ```

## Monitoring and Logs

### Railway
- View logs in Railway dashboard
- Monitor resource usage
- Set up alerts

### General Monitoring
- Use the `/health` endpoint for uptime monitoring
- Monitor WebSocket connections
- Track API response times

## Scaling Considerations

For production use, consider:

1. **Database**: Add a persistent database (PostgreSQL, MongoDB)
2. **Redis**: For session management and WebSocket scaling
3. **Load Balancing**: For multiple server instances
4. **CDN**: For static assets
5. **Monitoring**: Application performance monitoring (APM)

## Security Checklist

- ✅ HTTPS enabled (automatic on most platforms)
- ✅ CORS properly configured
- ✅ Rate limiting implemented
- ✅ Input validation in place
- ✅ No sensitive data in logs
- ✅ Environment variables for configuration

## Troubleshooting

### Common Issues:

1. **Port Issues**
   - Ensure your app listens on `process.env.PORT`
   - Bind to `0.0.0.0`, not `localhost`

2. **WebSocket Issues**
   - Check if platform supports WebSockets
   - Verify WSS (secure WebSocket) is used in production

3. **CORS Errors**
   - Update CORS origins to include your frontend domain
   - Check that credentials are properly configured

4. **Build Failures**
   - Ensure all dependencies are in `package.json`
   - Check Node.js version compatibility

### Getting Help:

- Check platform-specific documentation
- Review deployment logs
- Test locally with `NODE_ENV=production`
- Use the health check endpoint to verify deployment 