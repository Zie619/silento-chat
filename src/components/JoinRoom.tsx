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
    <div className="room-screen">
      <div className="room-header">
        <button className="back-button" onClick={onBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5"/>
            <path d="M12 19l-7-7 7-7"/>
          </svg>
        </button>
        <h2>Join Room</h2>
      </div>

      <div className="room-content">
        <div className="join-room-info">
          <div className="info-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="8.5" cy="7" r="4"/>
              <path d="M20 8v6"/>
              <path d="M23 11h-6"/>
            </svg>
          </div>
          <h3>Enter Room Code</h3>
          <p>
            Enter the 6-character room code shared by the room creator to join the conversation.
          </p>
        </div>

        <form onSubmit={handleJoinRoom} className="join-form">
          <div className="input-group">
            <label htmlFor="roomId">Room Code</label>
            <input
              id="roomId"
              type="text"
              value={roomId}
              onChange={handleInputChange}
              placeholder="ABC123"
              maxLength={6}
              className="room-code-input"
              autoComplete="off"
              autoCapitalize="characters"
            />
            <div className="input-hint">
              {roomId.length}/6 characters
            </div>
          </div>

          {error && (
            <div className="error-message">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/>
                <line x1="15" y1="9" x2="9" y2="15"/>
                <line x1="9" y1="9" x2="15" y2="15"/>
              </svg>
              {error}
            </div>
          )}

          <div className="room-actions">
            <button 
              type="submit"
              className="primary-button"
              disabled={isJoining || roomId.length !== 6}
            >
              {isJoining ? (
                <>
                  <div className="loading-spinner"></div>
                  Joining...
                </>
              ) : (
                'Join Room'
              )}
            </button>
          </div>
        </form>

        <div className="join-tips">
          <h4>Tips</h4>
          <ul>
            <li>Room codes are case-insensitive</li>
            <li>Only alphanumeric characters (A-Z, 0-9)</li>
            <li>Rooms expire after 5 minutes of inactivity</li>
            <li>You'll be notified when peers join or leave</li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default JoinRoom;
