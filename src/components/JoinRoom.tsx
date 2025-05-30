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
    
    // Keep the original case as entered by the user
    const trimmedCode = roomCode.trim();
    if (!trimmedCode) {
      setError('Please enter a room code');
      return;
    }

    setIsJoining(true);
    setError(null);

    try {
      // Simulate room join delay
      await new Promise(resolve => setTimeout(resolve, 800));
      
      // More flexible validation - allow alphanumeric with hyphens
      const roomPattern = /^[a-zA-Z0-9]+-[a-zA-Z0-9]+-[a-zA-Z0-9]+$/;
      if (!roomPattern.test(trimmedCode)) {
        // Also check if it's a simple 6-character code (legacy support)
        const legacyPattern = /^[A-Z0-9]{6}$/;
        if (!legacyPattern.test(trimmedCode.toUpperCase())) {
          throw new Error('Invalid room code format');
        }
      }
      
      onRoomJoined(trimmedCode);
    } catch (err) {
      setError('Invalid room code. Please check and try again.');
      setIsJoining(false);
    }
  };

  return (
    <div className="form-screen">
      <div className="form-header">
        <button className="back-button" onClick={onBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5m0 0l7 7m-7-7l7-7"/>
          </svg>
        </button>
        <h1 className="form-title">Join Room</h1>
        <div style={{ width: 40 }} /> {/* Spacer for centering */}
      </div>

      <form onSubmit={handleJoinRoom} className="form-content">
        <div className="form-group">
          <label className="form-label" htmlFor="roomCode">Room Code</label>
          <input
            id="roomCode"
            type="text"
            className="form-input"
            value={roomCode}
            onChange={(e) => {
              setRoomCode(e.target.value);
              setError(null);
            }}
            placeholder="e.g. swift-blue-eagle or ABC123"
            autoComplete="off"
            autoCorrect="off"
            autoCapitalize="off"
            spellCheck="false"
            disabled={isJoining}
          />
          <p className="form-hint">Enter the room code shared with you</p>
        </div>

        {error && (
          <div className="error-message">
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10"/>
              <line x1="12" y1="8" x2="12" y2="12"/>
              <line x1="12" y1="16" x2="12.01" y2="16"/>
            </svg>
            {error}
          </div>
        )}

        <div className="join-info">
          <div className="info-item">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/>
            </svg>
            <span>All messages are end-to-end encrypted</span>
          </div>
          <div className="info-item">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M20.84 4.61a5.5 5.5 0 0 0-7.78 0L12 5.67l-1.06-1.06a5.5 5.5 0 0 0-7.78 7.78l1.06 1.06L12 21.23l7.78-7.78 1.06-1.06a5.5 5.5 0 0 0 0-7.78z"/>
            </svg>
            <span>No personal information required</span>
          </div>
          <div className="info-item">
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
            <span>Room expires when everyone leaves</span>
          </div>
        </div>

        <button
          type="submit"
          className="form-submit"
          disabled={isJoining || !roomCode.trim()}
        >
          {isJoining ? (
            <>
              <span className="loading-spinner"></span>
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
