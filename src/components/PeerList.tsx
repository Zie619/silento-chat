import React from 'react';

interface PeerListProps {
  peers: string[];
  onClose: () => void;
}

function PeerList({ peers, onClose }: PeerListProps) {
  const formatPeerId = (peerId: string) => {
    // Show first 8 characters for readability
    return peerId.length > 8 ? `${peerId.substring(0, 8)}...` : peerId;
  };

  const getConnectionIcon = () => (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <circle cx="12" cy="12" r="3"/>
      <path d="M12 1v6m0 6v6"/>
      <path d="M21 12h-6m-6 0H3"/>
    </svg>
  );

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && onClose()}>
      <div className="peer-list-modal">
        <div className="modal-header">
          <h3>Connected Peers</h3>
          <button className="close-button" onClick={onClose}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>

        <div className="modal-content">
          {peers.length === 0 ? (
            <div className="empty-peers">
              <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
              </svg>
              <h4>No peers connected</h4>
              <p>Share your room code with others to start chatting</p>
            </div>
          ) : (
            <div className="peer-list">
              <div className="peer-count">
                {peers.length} peer{peers.length !== 1 ? 's' : ''} connected
              </div>
              
              {peers.map((peerId, index) => (
                <div key={peerId} className="peer-item">
                  <div className="peer-avatar">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/>
                      <circle cx="12" cy="7" r="4"/>
                    </svg>
                  </div>
                  
                  <div className="peer-info">
                    <div className="peer-name">Peer {index + 1}</div>
                    <div className="peer-id">{formatPeerId(peerId)}</div>
                  </div>
                  
                  <div className="peer-status">
                    <div className="status-indicator connected"></div>
                    <span>Connected</span>
                  </div>
                </div>
              ))}
            </div>
          )}

          <div className="peer-info-section">
            <h4>About Peer Connections</h4>
            <ul>
              <li>All connections are direct peer-to-peer</li>
              <li>Messages are encrypted end-to-end</li>
              <li>No data passes through our servers</li>
              <li>Peers are identified by random IDs</li>
            </ul>
          </div>
        </div>
      </div>
    </div>
  );
}

export default PeerList;
