# Silento iOS App

This is the native iOS wrapper for the Silento anonymous chat application. The app uses WKWebView to display the web application with native iOS integration.

## Features

- **Native iOS App**: Full iOS app experience with proper launch screen and app icon
- **WKWebView Integration**: Loads the web app with iOS-specific optimizations
- **Safe Area Support**: Properly handles iPhone notches and safe areas
- **Permission Handling**: Manages camera and microphone permissions for media sharing
- **iOS-Style UI**: Automatically injects iOS-specific CSS for native look and feel
- **Error Handling**: Graceful error handling with retry functionality

## Requirements

- Xcode 15.0 or later
- iOS 15.0 or later
- macOS with Apple Silicon or Intel processor
- Development server running on localhost:3000

## Setup Instructions

### 1. Start the Development Servers

Before running the iOS app, make sure both servers are running:

```bash
# In the main project directory
npm run server    # Starts backend on port 5001
npm run client    # Starts frontend on port 3000
```

### 2. Open in Xcode

The project is already open in Xcode. If you need to open it manually:

```bash
cd ios
open Silento.xcodeproj
```

### 3. Select Target Device

In Xcode:
1. Select a simulator from the device dropdown (iPhone 16, iPhone 15 Pro, etc.)
2. Or connect a physical iOS device for testing

### 4. Build and Run

1. Click the "Play" button in Xcode or press `Cmd+R`
2. The app will build and launch on your selected device/simulator
3. The app will automatically load the web application from localhost:3000

## Project Structure

```
ios/
├── Silento.xcodeproj/          # Xcode project file
├── Silento/                    # Source code directory
│   ├── AppDelegate.swift       # App lifecycle management
│   ├── SceneDelegate.swift     # Scene management (iOS 13+)
│   ├── ViewController.swift    # Main view controller with WKWebView
│   ├── Info.plist             # App configuration and permissions
│   ├── Assets.xcassets/        # App icons and colors
│   └── Base.lproj/
│       └── LaunchScreen.storyboard  # Launch screen
└── README.md                   # This file
```

## Key Features Explained

### WKWebView Configuration

The app configures WKWebView with:
- JavaScript enabled
- Inline media playback
- Picture-in-picture support
- iOS-specific CSS injection for safe areas
- Touch optimization

### Permissions

The app requests permissions for:
- **Camera**: For taking photos/videos in chat
- **Microphone**: For voice messages and video calls
- **Photo Library**: For sharing existing photos

### iOS-Specific Styling

The app automatically injects CSS that:
- Handles safe area insets (notches, home indicator)
- Hides scrollbars for native feel
- Optimizes touch targets
- Disables text selection where appropriate

### Error Handling

The app includes error handling for:
- Network connection issues
- Server unavailability
- WebView loading failures
- JavaScript errors

## Development Notes

### Local Development

The app is configured to load from `http://localhost:3000`. For production deployment, you would:

1. Update the URL in `ViewController.swift`
2. Deploy your web app to a production server
3. Update the `NSAppTransportSecurity` settings in `Info.plist` if needed

### Debugging

To debug the web content:
1. Run the app in the iOS Simulator
2. Open Safari on your Mac
3. Go to Develop → [Simulator Name] → localhost
4. This opens Web Inspector for the WKWebView content

### App Store Deployment

For App Store submission:
1. Add proper app icons to `Assets.xcassets/AppIcon.appiconset/`
2. Update the bundle identifier in project settings
3. Configure code signing with your Apple Developer account
4. Update the server URL to your production endpoint
5. Test thoroughly on physical devices

## Troubleshooting

### App Won't Load Content

1. **Check servers are running**: Ensure both backend (port 5001) and frontend (port 3000) are running
2. **Check network permissions**: Verify `NSAppTransportSecurity` settings in `Info.plist`
3. **Check simulator network**: iOS Simulator should have access to localhost

### Build Errors

1. **Clean build folder**: Product → Clean Build Folder in Xcode
2. **Reset simulator**: Device → Erase All Content and Settings
3. **Check Xcode version**: Ensure you're using Xcode 15.0 or later

### Permission Issues

1. **Reset permissions**: Settings → Privacy & Security → [Permission Type] → Silento → Reset
2. **Check Info.plist**: Ensure usage descriptions are present for camera/microphone

## Next Steps

1. **Add App Icons**: Create and add proper app icons in various sizes
2. **Customize Launch Screen**: Modify the launch screen design
3. **Add Push Notifications**: Integrate with APNs for message notifications
4. **Offline Support**: Add offline capabilities and caching
5. **App Store Optimization**: Prepare for App Store submission

## Support

For issues with the iOS app:
1. Check the Xcode console for error messages
2. Use Safari Web Inspector to debug web content
3. Verify server connectivity and CORS settings
4. Test on different iOS versions and devices 