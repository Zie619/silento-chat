import React, { useState, useEffect } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';

type AppState = 'loading' | 'home' | 'createRoom' | 'joinRoom' | 'chat';

interface RoomInfo {
  roomId: string;
  clientId: string;
}

// Particle Background Component
const ParticleBackground = () => {
  return (
    <div className="particle-container">
      {[...Array(20)].map((_, i) => (
        <div key={i} className="particle" style={{
          left: `${Math.random() * 100}%`,
          animationDelay: `${Math.random() * 20}s`,
          animationDuration: `${20 + Math.random() * 20}s`
        }} />
      ))}
    </div>
  );
};

function App() {
  const [currentScreen, setCurrentScreen] = useState<AppState>('loading');
  const [roomInfo, setRoomInfo] = useState<RoomInfo | null>(null);

  useEffect(() => {
    const initializeApp = async () => {
      // Generate unique client ID
      const storedClientId = sessionStorage.getItem('clientId');
      if (!storedClientId) {
        const newClientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
        sessionStorage.setItem('clientId', newClientId);
      }
      
      // Simulate loading with minimum time for smooth experience
      await new Promise(resolve => setTimeout(resolve, 1800));
      setCurrentScreen('home');
    };

    initializeApp();
  }, []);

  const handleRoomCreated = (roomId: string) => {
    const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
    setRoomInfo({ roomId, clientId });
    setCurrentScreen('chat');
  };

  const handleRoomJoined = (roomId: string) => {
    const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
    setRoomInfo({ roomId, clientId });
    setCurrentScreen('chat');
  };

  const handleLeaveRoom = () => {
    setRoomInfo(null);
    setCurrentScreen('home');
  };

  const renderContent = () => {
    switch (currentScreen) {
      case 'loading':
        return (
          <div className="splash-screen">
            <div className="splash-content">
              <div className="logo-wrapper">
                <div className="splash-logo">Silento</div>
                <div className="logo-subtitle">Secure Messaging</div>
              </div>
              <div className="splash-loader">
                <div className="loader-bar"></div>
              </div>
              <div className="loading-text">Initializing secure connection...</div>
            </div>
          </div>
        );
      
      case 'createRoom':
        return <CreateRoom onRoomCreated={handleRoomCreated} onBack={() => setCurrentScreen('home')} />;
      
      case 'joinRoom':
        return <JoinRoom onRoomJoined={handleRoomJoined} onBack={() => setCurrentScreen('home')} />;
      
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
          <div className="home-screen">
            <div className="home-container">
              <div className="hero-section">
                <div className="logo-wrapper">
                  <div className="logo">Silento</div>
                  <div className="logo-subtitle">Secure Messaging</div>
                </div>
                <p className="tagline">Anonymous. Encrypted. Private.</p>
                <div className="feature-pills">
                  <span className="pill">End-to-End Encrypted</span>
                  <span className="pill">No Account Required</span>
                  <span className="pill">WebRTC Powered</span>
                </div>
              </div>

              <div className="home-actions">
                <button className="action-btn primary" onClick={() => setCurrentScreen('createRoom')}>
                  <div className="btn-content">
                    <div className="btn-icon">🔐</div>
                    <div className="btn-text">
                      <span className="action-btn-title">Create Private Room</span>
                      <span className="action-btn-subtitle">Start a secure conversation</span>
                    </div>
                  </div>
                </button>

                <button className="action-btn" onClick={() => setCurrentScreen('joinRoom')}>
                  <div className="btn-content">
                    <div className="btn-icon">🔗</div>
                    <div className="btn-text">
                      <span className="action-btn-title">Join Existing Room</span>
                      <span className="action-btn-subtitle">Enter room code to connect</span>
                    </div>
                  </div>
                </button>
              </div>

              <div className="security-info">
                <div className="security-item">
                  <span className="icon">🛡️</span>
                  <span className="label">Encrypted</span>
                </div>
                <div className="security-item">
                  <span className="icon">👤</span>
                  <span className="label">Anonymous</span>
                </div>
                <div className="security-item">
                  <span className="icon">🔒</span>
                  <span className="label">Secure</span>
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
