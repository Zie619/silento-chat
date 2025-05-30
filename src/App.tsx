import React, { useState, useEffect, useRef } from 'react';
import CreateRoom from './components/CreateRoom';
import JoinRoom from './components/JoinRoom';
import ChatRoom from './components/ChatRoom';

type AppState = 'loading' | 'home' | 'create' | 'join' | 'chat';

interface RoomInfo {
  roomId: string;
  clientId: string;
}

// Swipe gesture hook
function useSwipeGesture(onSwipeLeft?: () => void, onSwipeRight?: () => void) {
  const touchStartX = useRef<number | null>(null);
  const touchEndX = useRef<number | null>(null);
  
  useEffect(() => {
    const handleTouchStart = (e: TouchEvent) => {
      touchStartX.current = e.changedTouches[0].screenX;
    };
    
    const handleTouchEnd = (e: TouchEvent) => {
      touchEndX.current = e.changedTouches[0].screenX;
      handleSwipe();
    };
    
    const handleSwipe = () => {
      if (touchStartX.current === null || touchEndX.current === null) return;
      
      const deltaX = touchEndX.current - touchStartX.current;
      const threshold = 50; // minimum distance for swipe
      
      if (Math.abs(deltaX) > threshold) {
        if (deltaX > 0 && onSwipeRight) {
          onSwipeRight(); // Swipe right
        } else if (deltaX < 0 && onSwipeLeft) {
          onSwipeLeft(); // Swipe left
        }
      }
    };
    
    document.addEventListener('touchstart', handleTouchStart);
    document.addEventListener('touchend', handleTouchEnd);
    
    return () => {
      document.removeEventListener('touchstart', handleTouchStart);
      document.removeEventListener('touchend', handleTouchEnd);
    };
  }, [onSwipeLeft, onSwipeRight]);
}

// Modern Logo Component
const SilentoLogo = ({ size = 'large' }: { size?: 'small' | 'large' }) => {
  const fontSize = size === 'large' ? '48px' : '28px';
  const height = size === 'large' ? '60' : '40';
  
  return (
    <div className="logo-container" data-size={size}>
      <svg width="auto" height={height} viewBox="0 0 200 60" xmlns="http://www.w3.org/2000/svg">
        <defs>
          <linearGradient id="logoGradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor="#667eea" />
            <stop offset="100%" stopColor="#764ba2" />
          </linearGradient>
          <filter id="glow">
            <feGaussianBlur stdDeviation="3" result="coloredBlur"/>
            <feMerge>
              <feMergeNode in="coloredBlur"/>
              <feMergeNode in="SourceGraphic"/>
            </feMerge>
          </filter>
        </defs>
        <text x="100" y="40" 
          style={{
            fontFamily: '-apple-system, BlinkMacSystemFont, sans-serif',
            fontWeight: 700,
            fontSize,
            fill: 'url(#logoGradient)',
            textAnchor: 'middle',
            filter: 'url(#glow)'
          }}>
          Silento
        </text>
      </svg>
      <div className="logo-tagline">Secure • Private • Ephemeral</div>
    </div>
  );
};

// Minimalist Splash Screen
const SplashScreen = () => (
  <div className="splash-screen">
    <div className="splash-content">
      <SilentoLogo size="large" />
      <div className="splash-loader">
        <div className="loader-bar"></div>
      </div>
    </div>
  </div>
);

function App() {
  const [state, setState] = useState<AppState>('loading');
  const [roomInfo, setRoomInfo] = useState<RoomInfo | null>(null);
  const [previousState, setPreviousState] = useState<AppState | null>(null);

  // Add swipe gestures for navigation
  useSwipeGesture(
    undefined, // No swipe left action needed
    () => {
      // Swipe right to go back
      if (state === 'create' || state === 'join') {
        setState('home');
      } else if (state === 'chat' && previousState) {
        handleLeaveRoom();
      }
    }
  );

  useEffect(() => {
    const initializeApp = async () => {
      // Minimum loading time for smooth transition
      await new Promise(resolve => setTimeout(resolve, 1500));
      
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
    setPreviousState(state);
    setState('chat');
  };

  const handleRoomJoined = (roomId: string) => {
    const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
    setRoomInfo({ roomId, clientId });
    setPreviousState(state);
    setState('chat');
  };

  const handleLeaveRoom = () => {
    setRoomInfo(null);
    setState('home');
    setPreviousState(null);
  };

  const renderContent = () => {
    switch (state) {
      case 'loading':
        return <SplashScreen />;
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
            <div className="home-container">
              <div className="home-header">
                <SilentoLogo size="large" />
                <p className="home-subtitle">Anonymous messaging that disappears</p>
              </div>
              
              <div className="home-actions">
                <button 
                  className="action-button primary"
                  onClick={() => setState('create')}
                >
                  <div className="button-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <circle cx="12" cy="12" r="10"/>
                      <path d="M12 8v8m-4-4h8"/>
                    </svg>
                  </div>
                  <div className="button-content">
                    <span className="button-title">Create Room</span>
                    <span className="button-subtitle">Start a new secure conversation</span>
                  </div>
                </button>
                
                <button 
                  className="action-button secondary"
                  onClick={() => setState('join')}
                >
                  <div className="button-icon">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
                      <path d="M14 2v6a2 2 0 002 2h6"/>
                      <path d="M4 13.5V4a2 2 0 012-2h8.5L20 7.5V20a2 2 0 01-2 2h-5.5"/>
                      <path d="M3 13.5h8m0 0l-3-3m3 3l-3 3"/>
                    </svg>
                  </div>
                  <div className="button-content">
                    <span className="button-title">Join Room</span>
                    <span className="button-subtitle">Enter an existing conversation</span>
                  </div>
                </button>
              </div>
              
              <div className="home-footer">
                <div className="security-features">
                  <div className="feature">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
                    </svg>
                    <span>End-to-end encrypted</span>
                  </div>
                  <div className="feature">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <circle cx="12" cy="12" r="10"/>
                      <path d="M12 6v6l4 2"/>
                    </svg>
                    <span>Messages auto-delete</span>
                  </div>
                  <div className="feature">
                    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
                    </svg>
                    <span>No account needed</span>
                  </div>
                </div>
                <p className="disclaimer">All conversations are ephemeral and will be lost when you leave</p>
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
