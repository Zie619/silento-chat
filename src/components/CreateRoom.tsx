import React, { useState } from 'react';

interface CreateRoomProps {
  onRoomCreated: (roomId: string) => void;
  onBack: () => void;
}

function CreateRoom({ onRoomCreated, onBack }: CreateRoomProps) {
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleCreateRoom = async () => {
    setIsCreating(true);
    setError(null);

    try {
      const response = await fetch('/api/create-room', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || 'Failed to create room');
      }

      const data = await response.json();
      onRoomCreated(data.roomId);
    } catch (err) {
      console.error('Error creating room:', err);
      setError(err instanceof Error ? err.message : 'Failed to create room');
    } finally {
      setIsCreating(false);
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
        <h2>Create Room</h2>
      </div>

      <div className="room-content">
        <div className="create-room-info">
          <div className="info-icon">
            <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/>
            </svg>
          </div>
          <h3>Create New Chat Room</h3>
          <p>
            You'll receive a unique room code that others can use to join your conversation.
            The room will be automatically deleted after 5 minutes of inactivity.
          </p>
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
            className="primary-button"
            onClick={handleCreateRoom}
            disabled={isCreating}
          >
            {isCreating ? (
              <>
                <div className="loading-spinner"></div>
                Creating Room...
              </>
            ) : (
              'Create Room'
            )}
          </button>
        </div>

        <div className="room-features">
          <h4>Features</h4>
          <ul>
            <li>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 12l2 2 4-4"/>
                <circle cx="12" cy="12" r="10"/>
              </svg>
              Real-time messaging
            </li>
            <li>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 12l2 2 4-4"/>
                <circle cx="12" cy="12" r="10"/>
              </svg>
              Image sharing
            </li>
            <li>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 12l2 2 4-4"/>
                <circle cx="12" cy="12" r="10"/>
              </svg>
              Video file transfer
            </li>
            <li>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M9 12l2 2 4-4"/>
                <circle cx="12" cy="12" r="10"/>
              </svg>
              Peer-to-peer encryption
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}

export default CreateRoom;
