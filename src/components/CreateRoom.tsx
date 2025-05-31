import React, { useState } from 'react';

interface CreateRoomProps {
  onRoomCreated: (roomId: string) => void;
  onBack: () => void;
}

function CreateRoom({ onRoomCreated, onBack }: CreateRoomProps) {
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generateRoomId = () => {
    // Generate 6-character alphanumeric room ID (e.g., ABC123)
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    let roomId = '';
    for (let i = 0; i < 6; i++) {
      roomId += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return roomId;
  };

  const handleCreateRoom = async () => {
    setIsCreating(true);
    setError(null);

    try {
      // Simulate room creation delay
      await new Promise(resolve => setTimeout(resolve, 800));
      
      const roomId = generateRoomId();
      onRoomCreated(roomId);
    } catch (err) {
      setError('Failed to create room. Please try again.');
      setIsCreating(false);
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
        <h1>Create Room</h1>
        <div className="header-spacer" />
      </div>

      <div className="content">
        <div className="info-section">
          <h2>Start a secure conversation</h2>
          <p>Create a private room with a unique code that you can share with others.</p>
        </div>

        <div className="features">
          <div className="feature-item">
            <div className="feature-icon">
              🔒
            </div>
            <div className="feature-text">
              <h3>End-to-End Encrypted</h3>
              <p>Your messages are secure</p>
            </div>
          </div>

          <div className="feature-item">
            <div className="feature-icon">
              ⏱️
            </div>
            <div className="feature-text">
              <h3>Temporary</h3>
              <p>Messages disappear when you leave</p>
            </div>
          </div>

          <div className="feature-item">
            <div className="feature-icon">
              👥
            </div>
            <div className="feature-text">
              <h3>Anonymous</h3>
              <p>No registration required</p>
            </div>
          </div>
        </div>

        {error && (
          <div className="error-box">
            <span>⚠️</span> {error}
          </div>
        )}

        <button
          className="primary-btn"
          onClick={handleCreateRoom}
          disabled={isCreating}
        >
          {isCreating ? (
            <>
              <span className="spinner"></span>
              Creating Room...
            </>
          ) : (
            'Create Room'
          )}
        </button>
      </div>
    </div>
  );
}

export default CreateRoom;
