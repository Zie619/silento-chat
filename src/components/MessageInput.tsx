import React, { useState, useRef } from 'react';

interface MessageInputProps {
  onSendMessage: (message: string) => void;
  disabled?: boolean;
}

function MessageInput({ onSendMessage, disabled = false }: MessageInputProps) {
  const [message, setMessage] = useState('');
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    
    const trimmedMessage = message.trim();
    if (trimmedMessage && !disabled) {
      onSendMessage(trimmedMessage);
      setMessage('');
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSubmit(e);
    }
  };

  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Check file size (limit to 10MB)
    if (file.size > 10 * 1024 * 1024) {
      alert('File too large. Maximum size is 10MB.');
      event.target.value = '';
      return;
    }

    // Handle file upload logic here
    console.log('File selected:', file.name);
    
    // Reset file input
    event.target.value = '';
  };

  const capturePhoto = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' } 
      });
      
      // Create video element for preview
      const video = document.createElement('video');
      video.srcObject = stream;
      video.play();
      
      // Show capture modal (simplified for now)
      console.log('Photo capture initiated');
      
      // Clean up stream
      setTimeout(() => {
        stream.getTracks().forEach(track => track.stop());
      }, 1000);
      
    } catch (error) {
      alert('Camera access denied or not available');
    }
  };

  const recordVideo = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' }, 
        audio: true 
      });
      
      console.log('Video recording initiated');
      
      // Clean up stream for now
      setTimeout(() => {
        stream.getTracks().forEach(track => track.stop());
      }, 1000);
      
    } catch (error) {
      alert('Camera/microphone access denied or not available');
    }
  };

  const recordVoice = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      console.log('Voice recording initiated');
      
      // Clean up stream for now
      setTimeout(() => {
        stream.getTracks().forEach(track => track.stop());
      }, 1000);
      
    } catch (error) {
      alert('Microphone access denied or not available');
    }
  };

  return (
    <>
      <div className="text-input-area">
        <input 
          type="text" 
          className="message-input" 
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type your message..." 
          maxLength={500}
          disabled={disabled}
        />
        <button 
          className="btn-send" 
          onClick={handleSubmit}
          disabled={disabled || !message.trim()}
          title="Send message"
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="22" y1="2" x2="11" y2="13"></line>
            <polygon points="22,2 15,22 11,13 2,9"></polygon>
          </svg>
        </button>
      </div>
      
      <div className="media-actions">
        <input 
          type="file" 
          ref={fileInputRef}
          accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.txt,.zip,.rar,.7z" 
          style={{ display: 'none' }} 
          onChange={handleFileSelect}
        />
        
        <button 
          className="btn-media-action" 
          onClick={() => fileInputRef.current?.click()} 
          title="Upload file"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"></path>
          </svg>
          <span>Files</span>
        </button>
        
        <button 
          className="btn-media-action" 
          onClick={capturePhoto} 
          title="Take photo"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
            <circle cx="12" cy="13" r="4"></circle>
          </svg>
          <span>Photo</span>
        </button>
        
        <button 
          className="btn-media-action" 
          onClick={recordVideo} 
          title="Record video"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polygon points="23,7 16,12 23,17"></polygon>
            <rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect>
          </svg>
          <span>Video</span>
        </button>
        
        <button 
          className="btn-media-action" 
          onClick={recordVoice} 
          title="Record voice"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path>
            <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
            <line x1="12" y1="19" x2="12" y2="23"></line>
            <line x1="8" y1="23" x2="16" y2="23"></line>
          </svg>
          <span>Voice</span>
        </button>
      </div>
    </>
  );
}

export default MessageInput;
