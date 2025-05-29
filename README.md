# Silento - Anonymous Chat App

A modern, anonymous peer-to-peer chat application with iOS-style design and native iOS app support.

## 🚀 Features

- **Anonymous Messaging**: No registration required, completely anonymous
- **Ephemeral Rooms**: Rooms expire after 5 minutes of inactivity
- **Real-time Communication**: WebSocket-based instant messaging
- **Media Sharing**: Share photos, videos, audio, and files
- **iOS-Style UI**: Beautiful iOS-inspired design with dark mode
- **Native iOS App**: WKWebView-based iOS app for device testing
- **P2P Architecture**: No data stored on servers, direct peer communication

## 🏗️ Architecture

### Backend (Node.js + TypeScript)
- **Express.js** server with WebSocket support
- **Room-based** chat system with automatic cleanup
- **Rate limiting** and security features
- **File sharing** through WebSocket messages
- **CORS enabled** for cross-origin requests

### Frontend (React + TypeScript)
- **React 19** with modern hooks
- **Vite** for fast development and building
- **iOS-style CSS** with system colors and typography
- **WebSocket client** for real-time communication
- **Media capture** and file upload support

### iOS App (Swift + WKWebView)
- **Native iOS wrapper** for the web app
- **WKWebView** with JavaScript bridge
- **Camera/microphone permissions** handling
- **iOS safe area** support
- **App Store ready** configuration

## 📱 Screenshots

The app features a beautiful iOS-style interface with:
- Dark mode design with iOS system colors
- Smooth animations and transitions
- Haptic feedback simulation
- iOS typography and spacing
- Safe area handling for modern devices

## 🛠️ Installation & Setup

### Prerequisites

- **Node.js 18+** and npm
- **Xcode 14+** (for iOS development)
- **iOS 15+** device or simulator

### Quick Start

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd MobileMessenger
   ```

2. **Install dependencies**:
   ```bash
   npm install
   ```

3. **Start the development servers**:
   ```bash
   npm run dev
   ```
   This starts both the backend (port 5000) and frontend (port 3000).

4. **Open in browser**:
   Navigate to `http://localhost:3000`

### iOS App Setup

1. **Open the Xcode project**:
   ```bash
   open ios/Silento.xcodeproj
   ```

2. **Configure signing**:
   - Select your Apple Developer Team
   - Ensure bundle identifier is unique

3. **Run on device**:
   - Connect your iOS device
   - Build and run (Cmd+R)

See [ios/README.md](ios/README.md) for detailed iOS setup instructions.

## 🎯 Usage

### Creating a Room
1. Click "Create Room"
2. Share the 6-character room code with others
3. Start chatting when others join

### Joining a Room
1. Click "Join Room"
2. Enter the 6-character room code
3. Start chatting immediately

### Features
- **Text Messages**: Type and send instant messages
- **Media Sharing**: Upload photos, videos, and files
- **Camera**: Take photos directly in the app
- **Voice Messages**: Record and share audio
- **Real-time Notifications**: See when users join/leave

## 🔧 Development

### Available Scripts

```bash
# Start both servers
npm run dev

# Start backend only
npm run server

# Start frontend only
npm run client

# Build for production
npm run build

# Preview production build
npm run preview
```

### Project Structure

```
MobileMessenger/
├── server/                 # Backend (Node.js + TypeScript)
│   ├── index.ts           # Main server file
│   ├── routes.ts          # API routes
│   ├── websocketHandler.ts # WebSocket logic
│   └── roomManager.ts     # Room management
├── src/                   # Frontend (React + TypeScript)
│   ├── components/        # React components
│   ├── hooks/            # Custom hooks
│   ├── services/         # API services
│   ├── types/            # TypeScript types
│   └── index.css         # iOS-style CSS
├── ios/                  # iOS App (Swift)
│   └── Silento/          # Xcode project
└── public/               # Static assets
```

### Key Technologies

- **Backend**: Node.js, Express, WebSocket (ws), TypeScript
- **Frontend**: React 19, Vite, TypeScript
- **iOS**: Swift, WKWebView, iOS 15+
- **Styling**: CSS with iOS design system
- **Real-time**: WebSocket for instant messaging

## 🔒 Security Features

- **Rate Limiting**: Prevents spam and abuse
- **Input Validation**: Sanitizes all user inputs
- **CORS Protection**: Configured for secure cross-origin requests
- **No Data Persistence**: Messages are not stored on servers
- **Room Expiration**: Automatic cleanup of inactive rooms
- **iOS Permissions**: Proper camera/microphone permission handling

## 🌐 Deployment

### Web App Deployment

1. **Build the project**:
   ```bash
   npm run build
   ```

2. **Deploy to your hosting service**:
   - Upload `dist/` folder for frontend
   - Deploy `server/` folder for backend
   - Configure environment variables

### iOS App Store

1. **Update production URL** in `ViewController.swift`
2. **Configure App Transport Security** for HTTPS
3. **Add app icons** and screenshots
4. **Submit to App Store** following Apple guidelines

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the ISC License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Apple** for iOS design inspiration
- **React** and **Vite** teams for excellent development tools
- **WebSocket** community for real-time communication standards

## 📞 Support

If you encounter any issues:

1. Check the [iOS README](ios/README.md) for iOS-specific troubleshooting
2. Ensure all dependencies are installed correctly
3. Verify that ports 3000 and 5000 are available
4. Check that your device and development machine are on the same network

---

**Silento** - Anonymous ephemeral messaging for the modern web and iOS. 