import React from 'react';

interface LoadingScreenProps {
  message?: string;
}

function LoadingScreen({ message = "Loading Silento..." }: LoadingScreenProps) {
  return (
    <div className="loading-screen">
      <div className="loading-content">
        <div className="loading-logo">
          <img src="/splash.png" alt="Silento" className="loading-image" />
        </div>
        
        <div className="loading-spinner-container">
          <div className="loading-spinner-ring">
            <div></div>
            <div></div>
            <div></div>
            <div></div>
          </div>
        </div>
        
        <div className="loading-message">
          <h2>{message}</h2>
          <p>Connecting to secure chat network...</p>
        </div>
      </div>
      
      <div className="loading-footer">
        <p>End-to-end encrypted messaging</p>
      </div>
    </div>
  );
}

export default LoadingScreen; 