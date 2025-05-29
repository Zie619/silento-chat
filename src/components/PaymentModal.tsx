import React, { useState, useEffect } from 'react';

interface PaymentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

// Detect device type for payment options
const isMobile = () => {
  return /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(navigator.userAgent);
};

const isIOS = () => {
  return /iPad|iPhone|iPod/.test(navigator.userAgent);
};

const isAndroid = () => {
  return /Android/.test(navigator.userAgent);
};

function PaymentOptions({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const [isProcessing, setIsProcessing] = useState(false);
  const [stripeLink, setStripeLink] = useState<string>('');

  useEffect(() => {
    // Create Stripe payment link
    fetch('/api/create-payment-link', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ amount: 5 })
    })
    .then(res => res.json())
    .then(data => {
      if (data.url) {
        setStripeLink(data.url);
      }
    })
    .catch(err => console.error('Failed to create payment link:', err));
  }, []);

  const handleApplePay = async () => {
    if (!(window as any).ApplePaySession || !(window as any).ApplePaySession.canMakePayments()) {
      alert('Apple Pay is not available on this device');
      return;
    }

    setIsProcessing(true);
    try {
      // In a real implementation, you'd integrate with Apple Pay
      // For now, we'll simulate success after a delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      localStorage.setItem('premiumUser', 'true');
      onSuccess();
      onClose();
    } catch (error) {
      alert('Apple Pay failed. Please try another payment method.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleGooglePay = async () => {
    setIsProcessing(true);
    try {
      // In a real implementation, you'd integrate with Google Pay
      // For now, we'll simulate success after a delay
      await new Promise(resolve => setTimeout(resolve, 2000));
      localStorage.setItem('premiumUser', 'true');
      onSuccess();
      onClose();
    } catch (error) {
      alert('Google Pay failed. Please try another payment method.');
    } finally {
      setIsProcessing(false);
    }
  };

  const handleStripeLink = () => {
    if (stripeLink) {
      window.open(stripeLink, '_blank');
      // Set a timer to check if payment was completed
      const checkPayment = setInterval(() => {
        // In a real implementation, you'd check payment status via API
        // For now, we'll let user manually confirm
        if (confirm('Did you complete the payment? Click OK if yes, Cancel to try again.')) {
          localStorage.setItem('premiumUser', 'true');
          onSuccess();
          onClose();
          clearInterval(checkPayment);
        }
      }, 3000);
      
      // Clear interval after 2 minutes
      setTimeout(() => clearInterval(checkPayment), 120000);
    }
  };

  return (
    <div className="payment-options">
      <div className="payment-header">
        <h3>Remove Ads - $5.00</h3>
        <p>Choose your preferred payment method</p>
      </div>
      
      <div className="payment-methods">
        {isIOS() && (
          <button 
            onClick={handleApplePay}
            disabled={isProcessing}
            className="payment-method apple-pay"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
              <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
            </svg>
            {isProcessing ? 'Processing...' : 'Pay with Apple Pay'}
          </button>
        )}
        
        {isAndroid() && (
          <button 
            onClick={handleGooglePay}
            disabled={isProcessing}
            className="payment-method google-pay"
          >
            <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
              <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"/>
              <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"/>
              <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l2.85-2.22.81-.62z"/>
              <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z"/>
            </svg>
            {isProcessing ? 'Processing...' : 'Pay with Google Pay'}
          </button>
        )}
        
        <button 
          onClick={handleStripeLink}
          disabled={isProcessing || !stripeLink}
          className="payment-method stripe-link"
        >
          <svg width="24" height="24" viewBox="0 0 24 24" fill="currentColor">
            <path d="M13.976 9.15c-2.172-.806-3.356-1.426-3.356-2.409 0-.831.683-1.305 1.901-1.305 2.227 0 4.515.858 6.09 1.631l.89-5.494C18.252.975 15.697 0 12.165 0 9.667 0 7.589.654 6.104 1.872 4.56 3.147 3.757 4.992 3.757 7.218c0 4.039 2.467 5.76 6.476 7.219 2.585.92 3.445 1.574 3.445 2.583 0 .98-.84 1.545-2.354 1.545-1.875 0-4.965-.921-6.99-2.109l-.9 5.555C5.175 22.99 8.385 24 11.714 24c2.641 0 4.843-.624 6.328-1.813 1.664-1.305 2.525-3.236 2.525-5.732 0-4.128-2.524-5.851-6.591-7.305z"/>
          </svg>
          Pay with Card (Stripe)
        </button>
      </div>
      
      <div className="payment-footer">
        <p>Secure payment • One-time purchase • No subscription</p>
      </div>
      
      <button onClick={onClose} className="close-payment-btn">
        Cancel
      </button>
    </div>
  );
}

function PaymentModal({ isOpen, onClose, onSuccess }: PaymentModalProps) {
  if (!isOpen) return null;

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content" onClick={(e) => e.stopPropagation()}>
        <button className="modal-close" onClick={onClose}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="18" y1="6" x2="6" y2="18"/>
            <line x1="6" y1="6" x2="18" y2="18"/>
          </svg>
        </button>
        
        <PaymentOptions onClose={onClose} onSuccess={onSuccess} />
      </div>
    </div>
  );
}

export default PaymentModal;