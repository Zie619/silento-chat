import React, { useState, useEffect } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';

type AppState = 'loading' | 'home' | 'createRoom' | 'joinRoom' | 'chat';

interface RoomInfo {
  roomId: string;
  clientId: string;
}

function App() {
  const [currentScreen, setCurrentScreen] = useState<AppState>('loading');
  const [roomInfo, setRoomInfo] = useState<RoomInfo | null>(null);

  useEffect(() => {
    console.log('Screen changed to:', currentScreen);
  }, [currentScreen]);

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
    console.log('Current screen:', currentScreen);
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
      
      case 'home':
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
                <button 
                  type="button"
                  className="action-btn primary" 
                  onClick={() => {
                    console.log('Create Room clicked');
                    setCurrentScreen('createRoom');
                  }}
                >
                  <div className="btn-content">
                    <div className="btn-icon">🔐</div>
                    <div className="btn-text">
                      <span className="action-btn-title">Create Private Room</span>
                      <span className="action-btn-subtitle">Start a secure conversation</span>
                    </div>
                  </div>
                </button>

                <button 
                  type="button"
                  className="action-btn" 
                  onClick={() => {
                    console.log('Join Room clicked');
                    setCurrentScreen('joinRoom');
                  }}
                >
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
      
      default:
        console.error('Unknown screen:', currentScreen);
        return null;
    }
  };

  return (
    <div className="app">
      <div style={{ position: 'fixed', top: 10, right: 10, zIndex: 1000, background: 'red', padding: '10px', borderRadius: '5px' }}>
        <div style={{ color: 'white', marginBottom: '5px' }}>Screen: {currentScreen}</div>
        <button 
          style={{ background: 'white', border: 'none', padding: '5px 10px', borderRadius: '3px', marginRight: '5px' }}
          onClick={() => setCurrentScreen('createRoom')}
        >
          Test Create
        </button>
        <button 
          style={{ background: 'white', border: 'none', padding: '5px 10px', borderRadius: '3px' }}
          onClick={() => setCurrentScreen('joinRoom')}
        >
          Test Join
        </button>
      </div>
      {renderContent()}
    </div>
  );
}

export default App;
