import React, { useState } from 'react';

interface CreateRoomProps {
  onRoomCreated: (roomId: string) => void;
  onBack: () => void;
}

function CreateRoom({ onRoomCreated, onBack }: CreateRoomProps) {
  const [isCreating, setIsCreating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const generateRoomId = () => {
    // Generate a memorable room ID with 3 random words
    const adjectives = ['swift', 'bright', 'quiet', 'bold', 'calm', 'clear', 'warm', 'cool', 'fresh', 'sharp'];
    const colors = ['blue', 'red', 'green', 'gold', 'silver', 'purple', 'orange', 'teal', 'coral', 'jade'];
    const animals = ['wolf', 'eagle', 'tiger', 'bear', 'fox', 'hawk', 'lion', 'deer', 'seal', 'lynx'];
    
    const randomItem = (arr: string[]) => arr[Math.floor(Math.random() * arr.length)];
    
    return `${randomItem(adjectives)}-${randomItem(colors)}-${randomItem(animals)}`;
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
    <div className="form-screen">
      <div className="form-header">
        <button className="back-button" onClick={onBack}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M19 12H5m0 0l7 7m-7-7l7-7"/>
          </svg>
        </button>
        <h1 className="form-title">Create Room</h1>
        <div style={{ width: 40 }} /> {/* Spacer for centering */}
      </div>

      <div className="form-content">
        <div className="form-info">
          <div className="info-card">
            <div className="info-icon">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="2" y="2" width="20" height="20" rx="5" ry="5"/>
                <path d="M12 8v4m0 4h.01"/>
              </svg>
            </div>
            <div className="info-content">
              <h3>Private & Secure</h3>
              <p>Your room will be protected with end-to-end encryption. Only people with the room code can join.</p>
            </div>
          </div>

          <div className="info-card">
            <div className="info-icon">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10"/>
                <path d="M12 6v6l4 2"/>
              </svg>
            </div>
            <div className="info-content">
              <h3>Temporary</h3>
              <p>Messages disappear when everyone leaves. No history is stored on any server.</p>
            </div>
          </div>

          <div className="info-card">
            <div className="info-icon">
              <svg width="32" height="32" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
              </svg>
            </div>
            <div className="info-content">
              <h3>Share Easily</h3>
              <p>Get a simple room code to share with others. No sign-up required.</p>
            </div>
          </div>
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

        <button
          className="form-submit"
          onClick={handleCreateRoom}
          disabled={isCreating}
        >
          {isCreating ? (
            <>
              <span className="loading-spinner"></span>
              Creating Room...
            </>
          ) : (
            'Create Secure Room'
          )}
        </button>
      </div>
    </div>
  );
}

export default CreateRoom;
