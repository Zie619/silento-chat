# 🚀 Quick Deployment Instructions

Since Railway hit the free plan limit, here are the best free alternatives:

## Option 1: Render (Recommended - Easiest)

1. **Go to [render.com](https://render.com)**
2. **Sign up with your GitHub account**
3. **Click "New +" → "Web Service"**
4. **Connect your GitHub repository** (this MobileMessenger repo)
5. **Configure the service:**
   - Name: `silento-backend`
   - Environment: `Node`
   - Build Command: `npm install`
   - Start Command: `npm start`
   - Plan: `Free`
6. **Add Environment Variable:**
   - Key: `NODE_ENV`
   - Value: `production`
7. **Click "Create Web Service"**

Render will automatically deploy your app and give you a URL like:
`https://silento-backend.onrender.com`

## Option 2: Vercel (Also Free)

1. **Go to [vercel.com](https://vercel.com)**
2. **Sign up with GitHub**
3. **Click "Import Project"**
4. **Select this repository**
5. **Add environment variable: `NODE_ENV=production`**
6. **Deploy**

## After Deployment

Once you get your deployment URL, update the iOS app:

1. **Open `ios/Silento/ViewController.swift`**
2. **Change line ~104:**
   ```swift
   // From:
   let urlString = "http://localhost:3000"
   
   // To:
   let urlString = "https://your-app-name.onrender.com"
   ```

3. **Rebuild and run the iOS app**

## Testing Your Deployment

Test the health endpoint:
```bash
curl https://your-app-name.onrender.com/health
```

You should see:
```json
{
  "status": "healthy",
  "timestamp": "2024-...",
  "environment": "production"
}
```

## Next Steps

1. Deploy the backend using Render (5 minutes)
2. Update the iOS app with the new URL
3. Test the app on your iPhone/simulator
4. Share the app with friends!

The backend will handle:
- ✅ Anonymous chat rooms
- ✅ Real-time messaging via WebSockets
- ✅ File/media sharing
- ✅ Rate limiting and security
- ✅ HTTPS automatically enabled 