# iOS Build and Installation Guide

## Current Issues Fixed:
1. ✅ Updated network IP to current address (192.168.68.52:3000)
2. ✅ Generated all required app icon sizes
3. ✅ Splash screen is properly configured

## Building for Release (Outside Debug Mode)

### Option 1: TestFlight Distribution (Recommended)
1. **Archive the app:**
   ```bash
   cd ios
   xcodebuild -workspace Silento.xcodeproj -scheme Silento -configuration Release -archivePath build/Silento.xcarchive archive
   ```

2. **Export for App Store:**
   ```bash
   xcodebuild -exportArchive -archivePath build/Silento.xcarchive -exportPath build/AppStore -exportOptionsPlist exportOptions.plist
   ```

3. **Upload to App Store Connect** (requires Apple Developer account)

### Option 2: Ad-Hoc Distribution
1. **Register your device UDID** in Apple Developer portal
2. **Create provisioning profile** for ad-hoc distribution
3. **Archive and export** with ad-hoc profile

### Option 3: Development Build (No Apple Developer Account)
1. **Install via Xcode directly:**
   - Open `ios/Silento.xcodeproj` in Xcode
   - Connect your iPhone via USB
   - Select your device as target
   - Click "Run" button
   - Trust the developer certificate on your device

### Current Network Configuration:
- **Dev Server**: Make sure `npm run client` is running
- **Network IP**: 192.168.68.52:3000 (automatically tries fallbacks)
- **Fallback URLs**: localhost:3000, previous network IPs

## Troubleshooting:

### If app still doesn't load:
1. Check if Vite dev server is running: `npm run client`
2. Check your network IP: `ifconfig | grep "inet " | grep -v 127.0.0.1`
3. Update the IP in `ios/Silento/ViewController.swift` if changed

### If app icon doesn't appear:
1. Clean build folder in Xcode: Product → Clean Build Folder
2. Delete app from device and reinstall

### For Production Deployment:
1. Build React app: `npm run build`
2. Host the built files on a server
3. Update iOS app to point to the hosted URL instead of localhost

## Next Steps:
1. Test the current build with updated network IP
2. If working, consider hosting the React app on a server for production use
3. Set up Apple Developer account for official App Store distribution 