import React, { useState, useEffect } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';

type AppState = 'loading' | 'home' | 'create' | 'join' | 'chat';

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
  const [state, setState] = useState<AppState>('loading');
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
          <div className="home-screen">
            <ParticleBackground />
            <div className="home-container">
              <div className="hero-section">
                <div className="logo">Silento</div>
                <div className="tagline">Anonymous messaging that disappears</div>
                <div className="feature-pills">
                  <span className="pill">🔒 End-to-End Encrypted</span>
                  <span className="pill">👻 No Registration</span>
                  <span className="pill">💨 Auto-Delete</span>
                </div>
              </div>
              
              <div className="home-actions">
                <button 
                  className="action-btn primary"
                  onClick={() => setState('create')}
                >
                  <div className="btn-content">
                    <div className="btn-icon">
                      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <circle cx="12" cy="12" r="10"/>
                        <path d="M12 8v8m-4-4h8"/>
                      </svg>
                    </div>
                    <div className="btn-text">
                      <div className="action-btn-title">Create Room</div>
                      <div className="action-btn-subtitle">Start a new secure conversation</div>
                    </div>
                  </div>
                </button>
                
                <button 
                  className="action-btn"
                  onClick={() => setState('join')}
                >
                  <div className="btn-content">
                    <div className="btn-icon">
                      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/>
                        <polyline points="10 17 15 12 10 7"/>
                        <line x1="15" y1="12" x2="3" y2="12"/>
                      </svg>
                    </div>
                    <div className="btn-text">
                      <div className="action-btn-title">Join Room</div>
                      <div className="action-btn-subtitle">Enter an existing conversation</div>
                    </div>
                  </div>
                </button>
              </div>
              
              <div className="security-info">
                <div className="security-item">
                  <span className="icon">🔒</span>
                  <span className="label">Encrypted</span>
                </div>
                <div className="security-item">
                  <span className="icon">⏱️</span>
                  <span className="label">Temporary</span>
                </div>
                <div className="security-item">
                  <span className="icon">🙈</span>
                  <span className="label">Anonymous</span>
                </div>
              </div>
            </div>
            
            <div className="premium-badge">
              v2.0 Premium
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
