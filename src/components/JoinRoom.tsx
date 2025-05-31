import React, { useState } from 'react';

interface JoinRoomProps {
  onRoomJoined: (roomId: string) => void;
  onBack: () => void;
}

function JoinRoom({ onRoomJoined, onBack }: JoinRoomProps) {
  const [roomCode, setRoomCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [isJoining, setIsJoining] = useState(false);

  const handleJoinRoom = async (e: React.FormEvent) => {
    e.preventDefault();
    
    const code = roomCode.trim().toUpperCase();
    if (!code) {
      setError('Please enter a room code');
      return;
    }

    if (code.length !== 6) {
      setError('Room code must be 6 characters');
      return;
    }

    setIsJoining(true);
    setError(null);

    try {
      // Simulate room join delay
      await new Promise(resolve => setTimeout(resolve, 800));
      
      // Validate format: 6 alphanumeric characters
      const validPattern = /^[A-Z0-9]{6}$/;
      if (!validPattern.test(code)) {
        throw new Error('Invalid room code format');
      }
      
      onRoomJoined(code);
    } catch (err) {
      setError('Invalid room code. Please check and try again.');
      setIsJoining(false);
    }
  };

  const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value.toUpperCase().replace(/[^A-Z0-9]/g, '');
    if (value.length <= 6) {
      setRoomCode(value);
      setError(null);
    }
  };

  return (
    <div className="screen">
      <div className="header">
        <button className="back-btn" onClick={onBack}>
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5m0 0l7 7m-7-7l7-7"/>
          </svg>
        </button>
        <h1>Join Room</h1>
        <div className="header-spacer" />
      </div>

      <form onSubmit={handleJoinRoom} className="content">
        <div className="info-section">
          <h2>Enter room code</h2>
          <p>Ask the room creator for the 6-character code to join their conversation.</p>
        </div>

        <div className="input-group">
          <input
            type="text"
            className="room-input"
            value={roomCode}
            onChange={handleInputChange}
            placeholder="ABC123"
            maxLength={6}
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="characters"
            spellCheck={false}
            disabled={isJoining}
          />
          <div className="input-hint">{roomCode.length}/6 characters</div>
        </div>

        {error && (
          <div className="error-box">
            <span>⚠️</span> {error}
          </div>
        )}

        <div className="info-list">
          <div className="info-item">
            <span>🔐</span>
            <span>Encrypted connection</span>
          </div>
          <div className="info-item">
            <span>🙈</span>
            <span>No personal data collected</span>
          </div>
          <div className="info-item">
            <span>💨</span>
            <span>Messages disappear after session</span>
          </div>
        </div>

        <button
          type="submit"
          className="primary-btn"
          disabled={isJoining || roomCode.length !== 6}
        >
          {isJoining ? (
            <>
              <span className="spinner"></span>
              Joining Room...
            </>
          ) : (
            'Join Room'
          )}
        </button>
      </form>
    </div>
  );
}

export default JoinRoom;
