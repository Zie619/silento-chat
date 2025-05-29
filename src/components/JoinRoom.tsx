import React, { useState } from 'react';

interface JoinRoomProps {
  onRoomJoined: (roomId: string) => void;
  onBack: () => void;
}

function JoinRoom({ onRoomJoined, onBack }: JoinRoomProps) {
  const [roomId, setRoomId] = useState('');
  const [isJoining, setIsJoining] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleJoinRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    
    if (!roomId.trim()) {
      setError('Please enter a room code');
      return;
    }

    setIsJoining(true);
    setError(null);

    try {
      const clientId = sessionStorage.getItem('clientId') || `client_${Date.now()}`;
      
      const response = await fetch('/api/join-room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          roomId: roomId.trim().toUpperCase(),
          clientId: clientId
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to join room');
      }

      onRoomJoined(roomId.trim().toUpperCase());
    } catch (err) {
      console.error('Error joining room:', err);
      setError(err instanceof Error ? err.message : 'Failed to join room');
    } finally {
      setIsJoining(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (value.length <= 6) {
      setRoomId(value);
      setError(null);
    }
  };

  return (
    <div className="home-screen ios-fade-in">
      <div className="home-content">
        <div className="ios-nav-bar">
          <button className="secondary-button ios-haptic" onClick={onBack} style={{ 
            position: 'absolute', 
            left: '0', 
            padding: '8px 16px', 
            minHeight: 'auto',
            fontSize: 'var(--ios-font-size-callout)'
          }}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M19 12H5"/>
              <path d="M12 19l-7-7 7-7"/>
            </svg>
            Back
          </button>
          <div className="ios-nav-title">Join Room</div>
        </div>

        <div style={{ padding: 'var(--ios-spacing-xl)' }}>
          <div className="ios-card" style={{ 
            padding: 'var(--ios-spacing-xl)', 
            marginBottom: 'var(--ios-spacing-xl)',
            textAlign: 'center'
          }}>
            <div style={{ 
              width: '64px', 
              height: '64px', 
              background: 'var(--ios-system-blue)', 
              borderRadius: '50%', 
              display: 'flex', 
              alignItems: 'center', 
              justifyContent: 'center',
              margin: '0 auto var(--ios-spacing-lg)'
            }}>
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="white" strokeWidth="2">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="8.5" cy="7" r="4"/>
                <path d="M20 8v6"/>
                <path d="M23 11h-6"/>
              </svg>
            </div>
            <h3 style={{ 
              fontSize: 'var(--ios-font-size-title2)', 
              fontWeight: '600', 
              marginBottom: 'var(--ios-spacing-sm)',
              color: 'var(--ios-label)'
            }}>
              Enter Room Code
            </h3>
            <p style={{ 
              fontSize: 'var(--ios-font-size-callout)', 
              color: 'var(--ios-label-secondary)',
              lineHeight: '1.4'
            }}>
              Enter the 6-character room code shared by the room creator to join the conversation.
            </p>
          </div>

          <form onSubmit={handleJoinRoom}>
            <div style={{ marginBottom: 'var(--ios-spacing-lg)' }}>
              <label style={{ 
                display: 'block', 
                fontSize: 'var(--ios-font-size-subhead)', 
                fontWeight: '600',
                color: 'var(--ios-label)',
                marginBottom: 'var(--ios-spacing-sm)'
              }}>
                Room Code
              </label>
              <input
                type="text"
                value={roomId}
                onChange={handleInputChange}
                placeholder="ABC123"
                maxLength={6}
                className="ios-input"
                autoComplete="off"
                autoCapitalize="characters"
                style={{ 
                  textAlign: 'center',
                  fontSize: 'var(--ios-font-size-title2)',
                  fontWeight: '600',
                  letterSpacing: '4px'
                }}
              />
              <div style={{ 
                fontSize: 'var(--ios-font-size-caption1)', 
                color: 'var(--ios-label-tertiary)',
                marginTop: 'var(--ios-spacing-sm)',
                textAlign: 'center'
              }}>
                {roomId.length}/6 characters
              </div>
            </div>

            {error && (
              <div className="ios-status-error" style={{ 
                padding: 'var(--ios-spacing-md)', 
                borderRadius: 'var(--ios-radius-lg)',
                marginBottom: 'var(--ios-spacing-lg)',
                display: 'flex',
                alignItems: 'center',
                gap: 'var(--ios-spacing-sm)'
              }}>
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <circle cx="12" cy="12" r="10"/>
                  <line x1="15" y1="9" x2="9" y2="15"/>
                  <line x1="9" y1="9" x2="15" y2="15"/>
                </svg>
                {error}
              </div>
            )}

            <button 
              type="submit"
              className="primary-button ios-haptic"
              disabled={isJoining || roomId.length !== 6}
              style={{ width: '100%', marginBottom: 'var(--ios-spacing-xl)' }}
            >
              {isJoining ? (
                <>
                  <div style={{
                    width: '16px',
                    height: '16px',
                    border: '2px solid rgba(255,255,255,0.3)',
                    borderTop: '2px solid white',
                    borderRadius: '50%',
                    animation: 'spin 1s linear infinite'
                  }}></div>
                  Joining...
                </>
              ) : (
                'Join Room'
              )}
            </button>
          </form>

          <div className="ios-card" style={{ padding: 'var(--ios-spacing-lg)' }}>
            <h4 style={{ 
              fontSize: 'var(--ios-font-size-subhead)', 
              fontWeight: '600',
              color: 'var(--ios-label)',
              marginBottom: 'var(--ios-spacing-md)'
            }}>
              Tips
            </h4>
            <ul style={{ 
              listStyle: 'none', 
              padding: '0',
              fontSize: 'var(--ios-font-size-footnote)',
              color: 'var(--ios-label-secondary)',
              lineHeight: '1.4'
            }}>
              <li style={{ marginBottom: 'var(--ios-spacing-sm)' }}>• Room codes are case-insensitive</li>
              <li style={{ marginBottom: 'var(--ios-spacing-sm)' }}>• Only alphanumeric characters (A-Z, 0-9)</li>
              <li style={{ marginBottom: 'var(--ios-spacing-sm)' }}>• Rooms expire after 5 minutes of inactivity</li>
              <li>• You'll be notified when peers join or leave</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

export default JoinRoom;
