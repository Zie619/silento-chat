import React, { useState, useRef } from 'react';

interface MessageInputProps {
  onSendMessage: (message: string) => void;
  onSendMedia?: (file: File, type: 'image' | 'video' | 'audio') => void;
  disabled?: boolean;
}

function MessageInput({ onSendMessage, onSendMedia, disabled = false }: MessageInputProps) {
  const [message, setMessage] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [mediaStream, setMediaStream] = useState<MediaStream | null>(null);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [capturedMedia, setCapturedMedia] = useState<{file: File, preview: string, type: 'image' | 'video' | 'audio'} | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);

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

  const handleFileSelect = async (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    // Check file size (limit to 10MB)
    if (file.size > 10 * 1024 * 1024) {
      alert('File too large. Maximum size is 10MB.');
      event.target.value = '';
      return;
    }

    // Create preview URL
    const previewUrl = URL.createObjectURL(file);
    const fileType = file.type.startsWith('image/') ? 'image' : file.type.startsWith('video/') ? 'video' : 'audio';
    
    setCapturedMedia({
      file,
      preview: previewUrl,
      type: fileType as 'image' | 'video' | 'audio'
    });
    
    // Reset file input
    event.target.value = '';
  };

  const requestCameraPermission = async (): Promise<boolean> => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          facingMode: 'environment',
          width: { ideal: 1280 },
          height: { ideal: 720 }
        } 
      });
      
      // Test successful - close stream immediately
      stream.getTracks().forEach(track => track.stop());
      return true;
    } catch (error) {
      console.error('Camera permission denied:', error);
      return false;
    }
  };

  const requestMicrophonePermission = async (): Promise<boolean> => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      
      // Test successful - close stream immediately  
      stream.getTracks().forEach(track => track.stop());
      return true;
    } catch (error) {
      console.error('Microphone permission denied:', error);
      return false;
    }
  };

  const capturePhoto = async () => {
    try {
      const hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        alert('Camera access is required to take photos. Please enable camera permissions in your browser settings.');
        return;
      }

      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          facingMode: 'environment',
          width: { ideal: 1280 },
          height: { ideal: 720 }
        } 
      });
      
      // Create video element to capture frame
      const video = document.createElement('video');
      video.srcObject = stream;
      video.autoplay = true;
      video.playsInline = true;
      
      // Wait for video to be ready
      await new Promise<void>((resolve) => {
        video.onloadedmetadata = () => {
          video.play().then(() => resolve());
        };
      });

      // Wait a bit for camera to adjust
      await new Promise(resolve => setTimeout(resolve, 500));
      
      // Create canvas to capture the frame
      const canvas = document.createElement('canvas');
      const context = canvas.getContext('2d');
      
      if (context) {
        canvas.width = video.videoWidth;
        canvas.height = video.videoHeight;
        
        // Draw the video frame to canvas
        context.drawImage(video, 0, 0);
        
        // Convert to blob and create file
        const blob = await new Promise<Blob | null>((resolve) => {
          canvas.toBlob((blob) => resolve(blob), 'image/jpeg', 0.9);
        });
        
        if (blob) {
          const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
          const file = new File([blob], `photo-${timestamp}.jpg`, { type: 'image/jpeg' });
          const previewUrl = URL.createObjectURL(blob);
          
          setCapturedMedia({
            file,
            preview: previewUrl,
            type: 'image'
          });
        }
      }
      
      // Clean up
      stream.getTracks().forEach(track => track.stop());
      
    } catch (error) {
      console.error('Photo capture failed:', error);
      alert('Failed to access camera. Please check your permissions.');
    }
  };

  const recordVideo = async () => {
    try {
      const hasPermission = await requestCameraPermission();
      if (!hasPermission) {
        alert('Camera access is required to record video. Please enable camera permissions in your browser settings.');
        return;
      }

      if (isRecording) {
        // Stop recording
        if (mediaRecorder && mediaRecorder.state === 'recording') {
          mediaRecorder.stop();
        }
        return;
      }

      // Start recording
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { 
          facingMode: 'environment',
          width: { ideal: 1280 },
          height: { ideal: 720 }
        }, 
        audio: true 
      });
      
      setMediaStream(stream);
      
      const chunks: Blob[] = [];
      const recorder = new MediaRecorder(stream, {
        mimeType: 'video/webm'
      });
      
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };
      
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'video/webm' });
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const file = new File([blob], `video-${timestamp}.webm`, { type: 'video/webm' });
        const previewUrl = URL.createObjectURL(blob);
        
        setCapturedMedia({
          file,
          preview: previewUrl,
          type: 'video'
        });
        
        // Clean up
        stream.getTracks().forEach(track => track.stop());
        setMediaStream(null);
        setIsRecording(false);
      };
      
      setMediaRecorder(recorder);
      recorder.start();
      setIsRecording(true);
      
      // Auto-stop after 30 seconds
      setTimeout(() => {
        if (recorder.state === 'recording') {
          recorder.stop();
        }
      }, 30000);
      
    } catch (error) {
      console.error('Video recording failed:', error);
      alert('Failed to access camera/microphone. Please check your permissions.');
    }
  };

  const recordVoice = async () => {
    try {
      const hasPermission = await requestMicrophonePermission();
      if (!hasPermission) {
        alert('Microphone access is required to record voice. Please enable microphone permissions in your browser settings.');
        return;
      }

      if (isRecording) {
        // Stop recording
        if (mediaRecorder && mediaRecorder.state === 'recording') {
          mediaRecorder.stop();
        }
        return;
      }

      // Start recording
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      setMediaStream(stream);
      
      const chunks: Blob[] = [];
      const recorder = new MediaRecorder(stream);
      
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };
      
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const file = new File([blob], `voice-${timestamp}.webm`, { type: 'audio/webm' });
        const previewUrl = URL.createObjectURL(blob);
        
        setCapturedMedia({
          file,
          preview: previewUrl,
          type: 'audio'
        });
        
        // Clean up
        stream.getTracks().forEach(track => track.stop());
        setMediaStream(null);
        setIsRecording(false);
      };
      
      setMediaRecorder(recorder);
      recorder.start();
      setIsRecording(true);
      
      // Auto-stop after 60 seconds
      setTimeout(() => {
        if (recorder.state === 'recording') {
          recorder.stop();
        }
      }, 60000);
      
    } catch (error) {
      console.error('Voice recording failed:', error);
      alert('Failed to access microphone. Please check your permissions.');
    }
  };

  const handleSendMedia = () => {
    if (capturedMedia && onSendMedia) {
      onSendMedia(capturedMedia.file, capturedMedia.type);
      
      // Clean up
      URL.revokeObjectURL(capturedMedia.preview);
      setCapturedMedia(null);
    }
  };

  const handleCancelMedia = () => {
    if (capturedMedia) {
      URL.revokeObjectURL(capturedMedia.preview);
      setCapturedMedia(null);
    }
  };

  const getMediaIcon = (type: string) => {
    switch (type) {
      case 'image': return '📷';
      case 'video': return '🎥';
      case 'audio': return '🎤';
      default: return '📎';
    }
  };

  return (
    <div className="input-container">
      {capturedMedia && (
        <div className="media-preview-modal">
          <div className="media-preview-content">
            <div className="media-preview-header">
              <h3>Send {capturedMedia.type}?</h3>
              <button className="close-btn" onClick={handleCancelMedia}>×</button>
            </div>
            
            <div className="media-preview">
              {capturedMedia.type === 'image' && (
                <img src={capturedMedia.preview} alt="Captured" />
              )}
              {capturedMedia.type === 'video' && (
                <video src={capturedMedia.preview} controls />
              )}
              {capturedMedia.type === 'audio' && (
                <div className="audio-preview">
                  <div className="audio-icon">🎤</div>
                  <audio src={capturedMedia.preview} controls />
                  <p>Voice message</p>
                </div>
              )}
            </div>
            
            <div className="media-preview-info">
              <p>{capturedMedia.file.name}</p>
              <p>{(capturedMedia.file.size / 1024 / 1024).toFixed(1)}MB</p>
            </div>
            
            <div className="media-preview-actions">
              <button className="cancel-btn" onClick={handleCancelMedia}>
                Cancel
              </button>
              <button className="send-btn" onClick={handleSendMedia}>
                Send {capturedMedia.type}
              </button>
            </div>
          </div>
        </div>
      )}

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
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="22" y1="2" x2="11" y2="13"></line>
            <polygon points="22,2 15,22 11,13 2,9"></polygon>
          </svg>
        </button>
      </div>
      
      <div className="media-actions">
        <input 
          type="file" 
          ref={fileInputRef}
          accept="image/*,video/*,audio/*,.pdf,.doc,.docx,.txt" 
          style={{ display: 'none' }} 
          onChange={handleFileSelect}
        />
        
        <button 
          className="btn-media-action ios-haptic" 
          onClick={() => fileInputRef.current?.click()} 
          title="Upload file"
          disabled={disabled}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M14,2H6A2,2 0 0,0 4,4V20A2,2 0 0,0 6,22H18A2,2 0 0,0 20,20V8L14,2M18,20H6V4H13V9H18V20Z"></path>
          </svg>
          <span>File</span>
        </button>
        
        <button 
          className="btn-media-action ios-haptic" 
          onClick={capturePhoto} 
          title="Take photo"
          disabled={disabled}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
            <circle cx="12" cy="13" r="4"></circle>
          </svg>
          <span>Photo</span>
        </button>
        
        <button 
          className={`btn-media-action ios-haptic ${isRecording ? 'recording' : ''}`}
          onClick={recordVideo} 
          title={isRecording ? "Stop recording" : "Record video"}
          disabled={disabled}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            {isRecording ? (
              <rect x="6" y="6" width="12" height="12" rx="2" ry="2"></rect>
            ) : (
              <>
                <polygon points="23,7 16,12 23,17"></polygon>
                <rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect>
              </>
            )}
          </svg>
          <span>{isRecording ? 'Stop' : 'Video'}</span>
        </button>
        
        <button 
          className={`btn-media-action ios-haptic ${isRecording ? 'recording' : ''}`}
          onClick={recordVoice} 
          title={isRecording ? "Stop recording" : "Record voice"}
          disabled={disabled}
        >
          <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            {isRecording ? (
              <rect x="6" y="6" width="12" height="12" rx="2" ry="2"></rect>
            ) : (
              <>
                <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path>
                <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
                <line x1="12" y1="19" x2="12" y2="23"></line>
                <line x1="8" y1="23" x2="16" y2="23"></line>
              </>
            )}
          </svg>
          <span>{isRecording ? 'Stop' : 'Voice'}</span>
        </button>
      </div>
      
      {isRecording && (
        <div className="recording-indicator">
          <div className="recording-dot"></div>
          <span>Recording... Tap to stop</span>
        </div>
      )}
    </div>
  );
}

export default MessageInput;
