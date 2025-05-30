import React, { useState, useEffect } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';
import LoadingScreen from './components/LoadingScreen';

type AppState = 'loading' | 'home' | 'create' | 'join' | 'chat';

interface RoomInfo {
  roomId: string;
  clientId: string;
}

// SVG Logo Component
const SilentoLogo = () => (
  <svg width="300" height="90" viewBox="0 0 400 120" xmlns="http://www.w3.org/2000/svg">
    <style>
      {`
        .glow {
          font-family: Arial, sans-serif;
          font-weight: bold;
          font-size: 64px;
          fill: #B9F8FF;
          text-anchor: middle;
          dominant-baseline: middle;
          filter: drop-shadow(0 0 8px #B9F8FF) drop-shadow(0 0 12px #00E0FF);
        }
      `}
    </style>
    <rect width="100%" height="100%" fill="none"/>
    <text x="200" y="60" className="glow">Silento</text>
  </svg>
);

function App() {
  const [state, setState] = useState<AppState>('loading');
  const [roomInfo, setRoomInfo] = useState<RoomInfo | null>(null);

  // Initialize app with loading screen
  useEffect(() => {
    const initializeApp = async () => {
      // Simulate app initialization
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Generate unique client ID
      const storedClientId = sessionStorage.getItem('clientId');
      if (!storedClientId) {
        const newClientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        sessionStorage.setItem('clientId', newClientId);
      }
      
      setState('home');
    };

    initializeApp();
  }, []);

  const handleRoomCreated = (roomId: string) => {
    const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
    setRoomInfo({ roomId, clientId });
    setState('chat');
  };

  const handleRoomJoined = (roomId: string) => {
    const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
    setRoomInfo({ roomId, clientId });
    setState('chat');
  };

  const handleLeaveRoom = () => {
    setRoomInfo(null);
    setState('home');
  };

  const renderContent = () => {
    switch (state) {
      case 'loading':
        return <LoadingScreen />;
      case 'create':
        return <CreateRoom onRoomCreated={handleRoomCreated} onBack={() => setState('home')} />;
      case 'join':
        return <JoinRoom onRoomJoined={handleRoomJoined} onBack={() => setState('home')} />;
      case 'chat':
        return roomInfo ? (
          <ChatRoom 
            roomId={roomInfo.roomId} 
            clientId={roomInfo.clientId}
            onLeave={handleLeaveRoom}
          />
        ) : null;
      default:
        return (
          <div className="home-screen ios-fade-in">
            <div className="home-content">
              <div className="app-header">
                <SilentoLogo />
                <p>Anonymous ephemeral messaging</p>
              </div>
              
              <div className="home-actions">
                <button 
                  className="primary-button ios-haptic"
                  onClick={() => setState('create')}
                >
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <circle cx="12" cy="12" r="10"/>
                    <line x1="12" y1="8" x2="12" y2="16"/>
                    <line x1="8" y1="12" x2="16" y2="12"/>
                  </svg>
                  Create Room
                </button>
                <button 
                  className="secondary-button ios-haptic"
                  onClick={() => setState('join')}
                >
                  <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
                    <polyline points="10,17 15,12 10,7"/>
                    <line x1="15" y1="12" x2="3" y2="12"/>
                  </svg>
                  Join Room
                </button>
              </div>
              
              <div className="home-footer">
                <p>No registration required • No data stored • Completely anonymous</p>
                <div className="warning ios-scale-in">
                  <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/>
                    <line x1="12" y1="9" x2="12" y2="13"/>
                    <line x1="12" y1="17" x2="12.01" y2="17"/>
                  </svg>
                  Leaving the app will end your session
                </div>
              </div>
            </div>
          </div>
        );
    }
  };

  return (
    <div className="app">
      {renderContent()}
    </div>
  );
}

export default App;
