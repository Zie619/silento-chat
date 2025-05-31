import React, { useState, useRef, useEffect } from 'react';

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
  const [showCamera, setShowCamera] = useState(false);
  const [cameraMode, setCameraMode] = useState<'photo' | 'video'>('photo');
  const [recordingTime, setRecordingTime] = useState(0);
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user'); // Default to front camera
  
  const fileInputRef = useRef<HTMLInputElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Cleanup streams on unmount
  useEffect(() => {
    return () => {
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
      if (recordingTimerRef.current) {
        clearInterval(recordingTimerRef.current);
      }
    };
  }, [mediaStream]);

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

    // Check file size (limit to 25MB)
    if (file.size > 25 * 1024 * 1024) {
      alert('File too large. Maximum size is 25MB.');
      event.target.value = '';
      return;
    }

    // Create preview URL
    const previewUrl = URL.createObjectURL(file);
    
    // Better file type detection
    let fileType: 'image' | 'video' | 'audio';
    if (file.type.startsWith('image/')) {
      fileType = 'image';
    } else if (file.type.startsWith('video/')) {
      fileType = 'video';
    } else if (file.type.startsWith('audio/')) {
      fileType = 'audio';
    } else {
      // For non-media files, treat as generic file
      fileType = 'image'; // We'll show a file icon instead
    }
    
    setCapturedMedia({
      file,
      preview: previewUrl,
      type: fileType
    });
    
    // Reset file input
    event.target.value = '';
  };

  const startCamera = async (mode: 'photo' | 'video') => {
    console.log('Starting camera in mode:', mode, 'facing:', facingMode);
    try {
      // Check if getUserMedia is supported
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        console.error('getUserMedia not supported');
        alert('Camera access is not supported in this browser.');
        return;
      }

      const constraints: MediaStreamConstraints = {
        video: { 
          facingMode: facingMode,
          width: { ideal: 1280, max: 1920 },
          height: { ideal: 720, max: 1080 }
        },
        audio: mode === 'video' ? true : false
      };

      console.log('Requesting media with constraints:', constraints);

      // Try with ideal constraints first
      let stream: MediaStream;
      try {
        stream = await navigator.mediaDevices.getUserMedia(constraints);
        console.log('Got media stream with ideal constraints');
      } catch (error) {
        // Fallback to basic constraints if ideal ones fail
        console.warn('Ideal constraints failed, trying basic:', error);
        const basicConstraints: MediaStreamConstraints = {
          video: { facingMode: facingMode },
          audio: mode === 'video' ? true : false
        };
        stream = await navigator.mediaDevices.getUserMedia(basicConstraints);
        console.log('Got media stream with basic constraints');
      }

      setMediaStream(stream);
      setCameraMode(mode);
      setShowCamera(true);
      console.log('Camera interface should be visible now');
      
      // Set up video element with a delay to ensure proper initialization
      setTimeout(() => {
        if (videoRef.current && stream) {
          console.log('Setting up video element');
          videoRef.current.srcObject = stream;
          videoRef.current.play().then(() => {
            console.log('Video is playing');
          }).catch(err => {
            console.error('Video play failed:', err);
          });
        } else {
          console.error('Video ref or stream not available');
        }
      }, 100);
      
    } catch (error) {
      console.error('Camera access failed:', error);
      alert(`Failed to access camera: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const switchCamera = async () => {
    if (!mediaStream) return;
    
    // Stop current stream
    mediaStream.getTracks().forEach(track => track.stop());
    
    // Switch facing mode
    const newFacingMode = facingMode === 'user' ? 'environment' : 'user';
    setFacingMode(newFacingMode);
    
    // Restart camera with new facing mode
    setTimeout(() => {
      startCamera(cameraMode);
    }, 100);
  };

  const stopCamera = () => {
    if (mediaStream) {
      mediaStream.getTracks().forEach(track => track.stop());
      setMediaStream(null);
    }
    setShowCamera(false);
    setIsRecording(false);
    setRecordingTime(0);
    if (recordingTimerRef.current) {
      clearInterval(recordingTimerRef.current);
    }
  };

  const capturePhoto = async () => {
    if (!videoRef.current || !mediaStream) return;

    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d');
    
    if (context) {
      canvas.width = videoRef.current.videoWidth;
      canvas.height = videoRef.current.videoHeight;
      
      // Draw the video frame to canvas
      context.drawImage(videoRef.current, 0, 0);
      
      // Convert to blob and create file
      const blob = await new Promise<Blob | null>((resolve) => {
        canvas.toBlob((blob) => resolve(blob), 'image/jpeg', 0.9);
      });
      
      if (blob) {
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const file = new File([blob], `photo-${timestamp}.jpg`, { type: 'image/jpeg' });
        const previewUrl = URL.createObjectURL(blob);
        
        console.log('Photo captured:', file.name, 'Size:', file.size, 'Preview URL:', previewUrl);
        
        setCapturedMedia({
          file,
          preview: previewUrl,
          type: 'image'
        });
        
        stopCamera();
        console.log('Camera stopped, media preview should show now');
      }
    }
  };

  const startVideoRecording = () => {
    if (!mediaStream) return;

    const chunks: Blob[] = [];
    
    // Try different MIME types for better compatibility
    let mimeType = 'video/webm';
    if (!MediaRecorder.isTypeSupported('video/webm')) {
      if (MediaRecorder.isTypeSupported('video/mp4')) {
        mimeType = 'video/mp4';
      } else if (MediaRecorder.isTypeSupported('video/webm;codecs=vp8')) {
        mimeType = 'video/webm;codecs=vp8';
      } else {
        mimeType = ''; // Let browser choose
      }
    }

    const recorder = new MediaRecorder(mediaStream, mimeType ? { mimeType } : undefined);
    
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) {
        chunks.push(event.data);
      }
    };
    
    recorder.onstop = () => {
      const actualMimeType = recorder.mimeType || 'video/webm';
      const blob = new Blob(chunks, { type: actualMimeType });
      const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
      const extension = actualMimeType.includes('mp4') ? 'mp4' : 'webm';
      const file = new File([blob], `video-${timestamp}.${extension}`, { type: actualMimeType });
      const previewUrl = URL.createObjectURL(blob);
      
      setCapturedMedia({
        file,
        preview: previewUrl,
        type: 'video'
      });
      
      stopCamera();
    };
    
    recorder.onerror = (event) => {
      console.error('Recording error:', event);
      alert('Recording failed. Please try again.');
      stopCamera();
    };
    
    setMediaRecorder(recorder);
    recorder.start();
    setIsRecording(true);
    setRecordingTime(0);
    
    // Start timer
    recordingTimerRef.current = setInterval(() => {
      setRecordingTime(prev => prev + 1);
    }, 1000);
    
    // Auto-stop after 30 seconds
    setTimeout(() => {
      if (recorder.state === 'recording') {
        recorder.stop();
      }
    }, 30000);
  };

  const stopVideoRecording = () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.stop();
    }
    if (recordingTimerRef.current) {
      clearInterval(recordingTimerRef.current);
    }
  };

  const recordVoice = async () => {
    try {
      if (isRecording) {
        // Stop recording
        if (mediaRecorder && mediaRecorder.state === 'recording') {
          mediaRecorder.stop();
        }
        return;
      }

      // Check if getUserMedia is supported
      if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
        alert('Microphone access is not supported in this browser.');
        return;
      }

      // Start recording
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      setMediaStream(stream);
      
      const chunks: Blob[] = [];
      
      // Try different MIME types for better compatibility
      let mimeType = 'audio/webm';
      if (!MediaRecorder.isTypeSupported('audio/webm')) {
        if (MediaRecorder.isTypeSupported('audio/mp4')) {
          mimeType = 'audio/mp4';
        } else if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) {
          mimeType = 'audio/webm;codecs=opus';
        } else if (MediaRecorder.isTypeSupported('audio/ogg')) {
          mimeType = 'audio/ogg';
        } else {
          mimeType = ''; // Let browser choose
        }
      }

      const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
      
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) {
          chunks.push(event.data);
        }
      };
      
      recorder.onstop = () => {
        const actualMimeType = recorder.mimeType || 'audio/webm';
        const blob = new Blob(chunks, { type: actualMimeType });
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const extension = actualMimeType.includes('mp4') ? 'm4a' : 
                         actualMimeType.includes('ogg') ? 'ogg' : 'webm';
        const file = new File([blob], `voice-${timestamp}.${extension}`, { type: actualMimeType });
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
        setRecordingTime(0);
        if (recordingTimerRef.current) {
          clearInterval(recordingTimerRef.current);
        }
      };

      recorder.onerror = (event) => {
        console.error('Audio recording error:', event);
        alert('Audio recording failed. Please try again.');
        
        // Clean up on error
        stream.getTracks().forEach(track => track.stop());
        setMediaStream(null);
        setIsRecording(false);
        setRecordingTime(0);
        if (recordingTimerRef.current) {
          clearInterval(recordingTimerRef.current);
        }
      };
      
      setMediaRecorder(recorder);
      recorder.start();
      setIsRecording(true);
      setRecordingTime(0);
      
      // Start timer
      recordingTimerRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1);
      }, 1000);
      
      // Auto-stop after 60 seconds
      setTimeout(() => {
        if (recorder.state === 'recording') {
          recorder.stop();
        }
      }, 60000);
      
    } catch (error) {
      console.error('Voice recording failed:', error);
      alert(`Failed to access microphone: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  };

  const handleSendMedia = () => {
    console.log('handleSendMedia called', capturedMedia);
    console.log('onSendMedia function available:', !!onSendMedia);
    if (capturedMedia && onSendMedia) {
      console.log('Sending media:', capturedMedia.file.name, capturedMedia.type);
      onSendMedia(capturedMedia.file, capturedMedia.type);
      
      // Clean up
      URL.revokeObjectURL(capturedMedia.preview);
      setCapturedMedia(null);
      console.log('Media sent and cleaned up');
    } else {
      console.error('Cannot send media - missing data or callback', { 
        capturedMedia: !!capturedMedia, 
        onSendMedia: !!onSendMedia,
        capturedMediaType: capturedMedia?.type,
        fileName: capturedMedia?.file?.name
      });
    }
  };

  const handleCancelMedia = () => {
    console.log('Canceling media preview');
    if (capturedMedia) {
      URL.revokeObjectURL(capturedMedia.preview);
      setCapturedMedia(null);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="input-container">
      {/* Camera Interface */}
      {showCamera && (
        <div className="camera-interface">
          <div className="camera-header">
            <button className="camera-close-btn" onClick={stopCamera}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="6" x2="6" y2="18"></line>
                <line x1="6" y1="6" x2="18" y2="18"></line>
              </svg>
            </button>
            <span className="camera-title">
              {cameraMode === 'photo' ? 'Take Photo' : 'Record Video'}
            </span>
            <button className="camera-switch-btn" onClick={switchCamera}>
              <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M7 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V5a2 2 0 0 0-2-2h-2"/>
                <path d="M9 3a2 2 0 0 0-2 2v0a2 2 0 0 0 2 2h6a2 2 0 0 0 2-2v0a2 2 0 0 0-2-2"/>
                <circle cx="12" cy="13" r="3"/>
                <path d="M16 9h-1"/>
              </svg>
            </button>
          </div>
          
          <div className="camera-preview">
            <video 
              ref={videoRef} 
              autoPlay 
              playsInline 
              muted
              className="camera-video"
              style={{
                transform: facingMode === 'user' ? 'scaleX(-1)' : 'none'
              }}
            />
            
            {isRecording && (
              <div className="recording-overlay">
                <div className="recording-indicator-live">
                  <div className="recording-dot-live"></div>
                  <span>REC {formatTime(recordingTime)}</span>
                </div>
              </div>
            )}
          </div>
          
          <div className="camera-controls">
            {cameraMode === 'photo' ? (
              <button className="capture-btn" onClick={capturePhoto}>
                <div className="capture-btn-inner"></div>
              </button>
            ) : (
              <button 
                className={`capture-btn ${isRecording ? 'recording' : ''}`}
                onClick={isRecording ? stopVideoRecording : startVideoRecording}
              >
                <div className="capture-btn-inner"></div>
              </button>
            )}
          </div>
        </div>
      )}

      {/* Media Preview Modal */}
      {capturedMedia && (
        <div className="media-preview-modal-mobile">
          <div className="media-preview-content-mobile">
            <div className="media-preview-header-mobile">
              <h3>Send {capturedMedia.type}?</h3>
              <button className="close-btn-mobile" onClick={handleCancelMedia}>×</button>
            </div>
            
            <div className="media-preview-mobile">
              {capturedMedia.type === 'image' && (
                <img src={capturedMedia.preview} alt="Captured" className="preview-image" />
              )}
              {capturedMedia.type === 'video' && (
                <video src={capturedMedia.preview} controls className="preview-video" />
              )}
              {capturedMedia.type === 'audio' && (
                <div className="audio-preview-mobile">
                  <div className="audio-icon-mobile">🎤</div>
                  <audio src={capturedMedia.preview} controls className="audio-controls" />
                  <p>Voice message ({formatTime(Math.floor(capturedMedia.file.size / 16000))})</p>
                </div>
              )}
            </div>
            
            <div className="media-preview-info-mobile">
              <p>{capturedMedia.file.name}</p>
              <p>{(capturedMedia.file.size / 1024 / 1024).toFixed(1)}MB</p>
            </div>
            
            <div className="media-preview-actions-mobile">
              <button className="cancel-btn-mobile" onClick={handleCancelMedia}>
                Cancel
              </button>
              <button className="send-btn-mobile" onClick={handleSendMedia}>
                Send {capturedMedia.type}
              </button>
            </div>
          </div>
        </div>
      )}

      <div className="text-input-area">
        <textarea 
          className="message-input" 
          value={message}
          onChange={(e) => setMessage(e.target.value)}
          onKeyDown={handleKeyDown}
          placeholder="Type your message..." 
          maxLength={500}
          disabled={disabled}
          rows={1}
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
          className="btn-media-action" 
          onClick={() => fileInputRef.current?.click()} 
          title="Upload file"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M21.44 11.05l-9.19 9.19a6 6 0 01-8.49-8.49l9.19-9.19a4 4 0 015.66 5.66L9.64 16.2a2 2 0 01-2.83-2.83l8.49-8.49"></path>
          </svg>
          <span>File</span>
        </button>
        
        <button 
          className="btn-media-action" 
          onClick={() => startCamera('photo')} 
          title="Take photo"
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M23 19a2 2 0 01-2 2H3a2 2 0 01-2-2V8a2 2 0 012-2h4l2-3h6l2 3h4a2 2 0 012 2z"></path>
            <circle cx="12" cy="13" r="4"></circle>
          </svg>
          <span>Photo</span>
        </button>
        
        <button 
          className="btn-media-action"
          onClick={() => startCamera('video')} 
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
          className={`btn-media-action ${isRecording ? 'recording' : ''}`}
          onClick={recordVoice} 
          title={isRecording ? "Stop recording" : "Record voice"}
          disabled={disabled}
        >
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            {isRecording ? (
              <rect x="6" y="6" width="12" height="12" rx="2" ry="2"></rect>
            ) : (
              <>
                <path d="M12 1a3 3 0 00-3 3v8a3 3 0 006 0V4a3 3 0 00-3-3z"></path>
                <path d="M19 10v2a7 7 0 01-14 0v-2"></path>
                <line x1="12" y1="19" x2="12" y2="23"></line>
                <line x1="8" y1="23" x2="16" y2="23"></line>
              </>
            )}
          </svg>
          <span>{isRecording ? `${formatTime(recordingTime)}` : 'Voice'}</span>
        </button>
      </div>
      
      {isRecording && !showCamera && (
        <div className="recording-indicator">
          <div className="recording-dot"></div>
          <span>Recording voice... {formatTime(recordingTime)}</span>
        </div>
      )}
    </div>
  );
}

export default MessageInput;
