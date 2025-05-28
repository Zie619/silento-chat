import React, { useState, useEffect } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';

type AppState = 'home' | 'create' | 'join' | 'chat';

interface RoomInfo {
  roomId: string;
  clientId: string;
}

function App() {
  const [state, setState] = useState<AppState>('home');
  const [roomInfo, setRoomInfo] = useState<RoomInfo | null>(null);

  // Generate unique client ID
  useEffect(() => {
    const storedClientId = sessionStorage.getItem('clientId');
    if (!storedClientId) {
      const newClientId = `client_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
      sessionStorage.setItem('clientId', newClientId);
    }
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
            <div className="home-content">
              <div className="app-header">
                <h1>Anonymous Chat</h1>
                <p>Ephemeral peer-to-peer messaging</p>
              </div>
              
              <div className="home-actions">
                <button 
                  className="primary-button"
                  onClick={() => setState('create')}
                >
                  Create Room
                </button>
                <button 
                  className="secondary-button"
                  onClick={() => setState('join')}
                >
                  Join Room
                </button>
              </div>
              
              <div className="home-footer">
                <p>No registration required • No data stored • Completely anonymous</p>
                <div className="warning">
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
