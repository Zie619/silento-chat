import React, { useState, useRef } from 'react';

interface MessageInputProps {
  onSendMessage: () => void;
  onSendFile: (file: File) => void;
  onMessageChange: (message: string) => void;
  message: string;
  disabled?: boolean;
}

function MessageInput({ onSendMessage, onSendFile, onMessageChange, message, disabled = false }: MessageInputProps) {
  const [isRecording, setIsRecording] = useState(false);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [mediaPreview, setMediaPreview] = useState<{file: File, url: string, type: 'image' | 'video' | 'audio'} | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const inputRef = useRef<HTMLTextAreaElement>(null);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      if (message.trim() && !disabled) {
        onSendMessage();
      }
    }
  };

  const handleFileSelect = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      const url = URL.createObjectURL(file);
      let type: 'image' | 'video' | 'audio' = 'image';
      
      if (file.type.startsWith('video/')) type = 'video';
      else if (file.type.startsWith('audio/')) type = 'audio';
      
      setMediaPreview({ file, url, type });
      e.target.value = '';
    }
  };

  const handlePhotoCapture = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ video: { facingMode: 'environment' } });
      const video = document.createElement('video');
      video.srcObject = stream;
      video.style.display = 'none';
      document.body.appendChild(video);
      
      await video.play();
      
      // Wait for video to be ready
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      const canvas = document.createElement('canvas');
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;
      const context = canvas.getContext('2d');
      
      if (context) {
        context.drawImage(video, 0, 0);
        
        canvas.toBlob((blob) => {
          if (blob) {
            const file = new File([blob], 'photo.jpg', { type: 'image/jpeg' });
            const url = URL.createObjectURL(blob);
            setMediaPreview({ file, url, type: 'image' });
          }
          
          // Cleanup
          stream.getTracks().forEach(track => track.stop());
          document.body.removeChild(video);
        }, 'image/jpeg', 0.8);
      }
    } catch (error) {
      console.error('Error capturing photo:', error);
      alert('Unable to access camera');
    }
  };

  const handleStartRecording = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      const recorder = new MediaRecorder(stream);
      const chunks: Blob[] = [];
      
      recorder.ondataavailable = (e) => {
        chunks.push(e.data);
      };
      
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        const file = new File([blob], 'recording.webm', { type: 'audio/webm' });
        const url = URL.createObjectURL(blob);
        setMediaPreview({ file, url, type: 'audio' });
        
        stream.getTracks().forEach(track => track.stop());
        setIsRecording(false);
        setMediaRecorder(null);
      };
      
      recorder.start();
      setMediaRecorder(recorder);
      setIsRecording(true);
    } catch (error) {
      console.error('Error starting recording:', error);
      alert('Unable to access microphone');
    }
  };

  const handleStopRecording = () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.stop();
    }
  };

  const recordVideo = async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({ 
        video: { facingMode: 'environment' }, 
        audio: true 
      });
      
      const recorder = new MediaRecorder(stream);
      const chunks: Blob[] = [];
      
      recorder.ondataavailable = (e) => {
        chunks.push(e.data);
      };
      
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'video/webm' });
        const file = new File([blob], 'video.webm', { type: 'video/webm' });
        const url = URL.createObjectURL(blob);
        setMediaPreview({ file, url, type: 'video' });
        
        stream.getTracks().forEach(track => track.stop());
      };
      
      recorder.start();
      
      // Auto-stop after 30 seconds
      setTimeout(() => {
        if (recorder.state === 'recording') {
          recorder.stop();
        }
      }, 30000);
    } catch (error) {
      console.error('Error recording video:', error);
      alert('Unable to access camera/microphone');
    }
  };

  const handleSendMedia = () => {
    if (mediaPreview) {
      onSendFile(mediaPreview.file);
      setMediaPreview(null);
    }
  };

  const renderMediaPreview = () => {
    if (!mediaPreview) return null;

    return (
      <div className="media-preview-modal">
        <div className="media-preview-content">
          <div className="media-preview-header">
            <h3>Preview</h3>
            <button className="close-btn" onClick={() => setMediaPreview(null)}>×</button>
          </div>
          
          <div className="media-preview">
            {mediaPreview.type === 'image' && (
              <img src={mediaPreview.url} alt="Preview" />
            )}
            {mediaPreview.type === 'video' && (
              <video src={mediaPreview.url} controls />
            )}
            {mediaPreview.type === 'audio' && (
              <div className="audio-preview">
                <span className="audio-icon">🎵</span>
                <audio src={mediaPreview.url} controls />
              </div>
            )}
          </div>
          
          <div className="media-preview-info">
            <span>Size: {(mediaPreview.file.size / 1024).toFixed(1)} KB</span>
            <span>{mediaPreview.type}</span>
          </div>
          
          <div className="media-preview-actions">
            <button className="cancel-btn" onClick={() => setMediaPreview(null)}>Cancel</button>
            <button className="send-btn" onClick={handleSendMedia}>Send</button>
          </div>
        </div>
      </div>
    );
  };

  return (
    <div className="input-container">
      <div className="text-input-area">
        <textarea
          ref={inputRef}
          className="message-input ios-input"
          placeholder="Type a message..."
          value={message}
          onChange={(e) => onMessageChange(e.target.value)}
          onKeyDown={handleKeyDown}
          disabled={disabled || isRecording}
          rows={1}
        />
        
        <button 
          className="btn-send ios-haptic" 
          onClick={onSendMessage} 
          disabled={!message.trim() || disabled || isRecording}
          title="Send message"
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <line x1="22" y1="2" x2="11" y2="13"></line>
            <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
          </svg>
        </button>
      </div>

      <div className="media-actions">
        <button 
          className="btn-media-action ios-haptic" 
          onClick={handlePhotoCapture} 
          title="Take photo"
          disabled={disabled}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M23 19a2 2 0 0 1-2 2H3a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h4l2-3h6l2 3h4a2 2 0 0 1 2 2z"></path>
            <circle cx="12" cy="13" r="4"></circle>
          </svg>
          <span>Photo</span>
        </button>
        
        <button 
          className="btn-media-action ios-haptic" 
          onClick={() => fileInputRef.current?.click()} 
          title="Attach file"
          disabled={disabled}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"></path>
          </svg>
          <span>File</span>
        </button>
        
        <button 
          className={`btn-media-action ios-haptic ${isRecording ? 'recording' : ''}`}
          onClick={isRecording ? handleStopRecording : handleStartRecording} 
          title={isRecording ? "Stop recording" : "Record audio"}
          disabled={disabled}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"></path>
            <path d="M19 10v2a7 7 0 0 1-14 0v-2"></path>
            <line x1="12" y1="19" x2="12" y2="23"></line>
            <line x1="8" y1="23" x2="16" y2="23"></line>
          </svg>
          <span>{isRecording ? 'Stop' : 'Audio'}</span>
        </button>
        
        <button 
          className="btn-media-action ios-haptic" 
          onClick={recordVideo} 
          title="Record video"
          disabled={disabled}
        >
          <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <polygon points="23 7 16 12 23 17 23 7"></polygon>
            <rect x="1" y="5" width="15" height="14" rx="2" ry="2"></rect>
          </svg>
          <span>Video</span>
        </button>
      </div>
      
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*,video/*,audio/*"
        onChange={handleFileSelect}
        style={{ display: 'none' }}
      />
      
      {isRecording && (
        <div className="recording-indicator">
          <span className="recording-dot"></span>
          Recording audio... Tap to stop
        </div>
      )}

      {renderMediaPreview()}
    </div>
  );
}

export default MessageInput;
