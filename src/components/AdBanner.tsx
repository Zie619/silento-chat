import React, { useState, useEffect } from 'react';

interface AdBannerProps {
  onClose: () => void;
  isPremium: boolean;
}

function AdBanner({ onClose, isPremium }: AdBannerProps) {
  const [isVisible, setIsVisible] = useState(!isPremium);

  useEffect(() => {
    setIsVisible(!isPremium);
  }, [isPremium]);

  if (!isVisible) return null;

  const handleClose = () => {
    setIsVisible(false);
    onClose();
  };

  return (
    <div className="ad-banner">
      <div className="ad-content">
        <div className="ad-text">
          <h4>Enjoying Silento?</h4>
          <p>Remove ads forever for just $5 and support the development of privacy-focused messaging!</p>
        </div>
        <div className="ad-actions">
          <button 
            className="ad-upgrade-btn"
            onClick={() => {
              // Trigger the payment modal
              const event = new CustomEvent('openPaymentModal');
              window.dispatchEvent(event);
            }}
          >
            Remove Ads - $5
          </button>
          <button className="ad-close-btn" onClick={handleClose}>
            <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>
      </div>
    </div>
  );
}

export default AdBanner;