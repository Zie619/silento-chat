import React, { useState } from 'react';

interface RemoveAdsButtonProps {
  onOpenPayment: () => void;
  isPremium: boolean;
}

function RemoveAdsButton({ onOpenPayment, isPremium }: RemoveAdsButtonProps) {
  if (isPremium) {
    return null; // Don't show button if user already has premium
  }

  return (
    <button 
      className="remove-ads-button"
      onClick={onOpenPayment}
      title="Remove ads for $5"
    >
      <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="12" cy="12" r="10"/>
        <line x1="15" y1="9" x2="9" y2="15"/>
        <line x1="9" y1="9" x2="15" y2="15"/>
      </svg>
      Remove Ads
    </button>
  );
}

export default RemoveAdsButton;