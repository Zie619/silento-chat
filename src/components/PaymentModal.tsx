import React, { useState, useEffect } from 'react';
import { loadStripe } from '@stripe/stripe-js';
import { Elements, PaymentElement, useStripe, useElements } from '@stripe/react-stripe-js';

// @ts-ignore
const stripePublicKey = import.meta.env.VITE_STRIPE_PUBLIC_KEY;

if (!stripePublicKey) {
  throw new Error('Missing required Stripe key: VITE_STRIPE_PUBLIC_KEY');
}

const stripePromise = loadStripe(stripePublicKey);

interface PaymentModalProps {
  isOpen: boolean;
  onClose: () => void;
  onSuccess: () => void;
}

function PaymentForm({ onClose, onSuccess }: { onClose: () => void; onSuccess: () => void }) {
  const stripe = useStripe();
  const elements = useElements();
  const [isProcessing, setIsProcessing] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMessage(null);

    if (!stripe || !elements) {
      return;
    }

    setIsProcessing(true);

    try {
      const { error } = await stripe.confirmPayment({
        elements,
        confirmParams: {
          return_url: window.location.origin,
        },
        redirect: 'if_required',
      });

      if (error) {
        setErrorMessage(error.message || 'Payment failed');
      } else {
        // Payment successful
        localStorage.setItem('premiumUser', 'true');
        onSuccess();
        onClose();
      }
    } catch (err) {
      setErrorMessage('An unexpected error occurred');
    } finally {
      setIsProcessing(false);
    }
  };

  return (
    <form onSubmit={handleSubmit} className="payment-form">
      <div className="payment-header">
        <h3>Remove Ads - $5.00</h3>
        <p>Enjoy an ad-free experience forever!</p>
      </div>
      
      <div className="payment-element">
        <PaymentElement />
      </div>
      
      {errorMessage && (
        <div className="error-message">
          {errorMessage}
        </div>
      )}
      
      <div className="payment-actions">
        <button 
          type="button" 
          onClick={onClose}
          className="btn-secondary"
          disabled={isProcessing}
        >
          Cancel
        </button>
        <button 
          type="submit" 
          className="btn-primary"
          disabled={!stripe || isProcessing}
        >
          {isProcessing ? 'Processing...' : 'Pay $5.00'}
        </button>
      </div>
    </form>
  );
}

function PaymentModal({ isOpen, onClose, onSuccess }: PaymentModalProps) {
  const [clientSecret, setClientSecret] = useState<string>('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isOpen) {
      // Create payment intent for $5
      fetch('/api/create-payment-intent', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({ amount: 5 }), // $5.00
      })
        .then((res) => res.json())
        .then((data) => {
          if (data.clientSecret) {
            setClientSecret(data.clientSecret);
          } else {
            setError('Failed to initialize payment');
          }
        })
        .catch(() => {
          setError('Failed to connect to payment service');
        })
        .finally(() => {
          setLoading(false);
        });
    }
  }, [isOpen]);

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
        
        {loading && (
          <div className="loading-state">
            <div className="spinner"></div>
            <p>Loading payment...</p>
          </div>
        )}
        
        {error && (
          <div className="error-state">
            <p>{error}</p>
            <button onClick={onClose} className="btn-primary">Close</button>
          </div>
        )}
        
        {clientSecret && !loading && !error && (
          <Elements stripe={stripePromise} options={{ clientSecret }}>
            <PaymentForm onClose={onClose} onSuccess={onSuccess} />
          </Elements>
        )}
      </div>
    </div>
  );
}

export default PaymentModal;