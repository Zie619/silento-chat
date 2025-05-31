import React, { useState, useEffect, useRef } from 'react';

interface Message {
  id: string;
  type: 'text' | 'image' | 'video' | 'audio';
  content: string;
  senderId: string;
  timestamp: number;
  file?: File;
}

interface ChatRoomProps {
  roomId: string;
  clientId: string;
  onLeave: () => void;
}

function ChatRoom({ roomId, clientId, onLeave }: ChatRoomProps) {
  const [messages, setMessages] = useState<Message[]>([]);
  const [inputText, setInputText] = useState('');
  const [isRecording, setIsRecording] = useState(false);
  const [showCamera, setShowCamera] = useState(false);
  const [cameraMode, setCameraMode] = useState<'photo' | 'video'>('photo');
  const [facingMode, setFacingMode] = useState<'user' | 'environment'>('user');
  const [mediaStream, setMediaStream] = useState<MediaStream | null>(null);
  const [mediaRecorder, setMediaRecorder] = useState<MediaRecorder | null>(null);
  const [recordingTime, setRecordingTime] = useState(0);
  const [showPreview, setShowPreview] = useState(false);
  const [previewMedia, setPreviewMedia] = useState<{
    file: File;
    url: string;
    type: 'image' | 'video' | 'audio';
  } | null>(null);

  const messagesEndRef = useRef<HTMLDivElement>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);
  const recordingTimerRef = useRef<NodeJS.Timeout | null>(null);

  // Auto-scroll to bottom when new messages arrive
  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  // Cleanup on unmount
  useEffect(() => {
    return () => {
      if (mediaStream) {
        mediaStream.getTracks().forEach(track => track.stop());
      }
      if (recordingTimerRef.current) {
        clearInterval(recordingTimerRef.current);
      }
      if (previewMedia) {
        URL.revokeObjectURL(previewMedia.url);
      }
    };
  }, [mediaStream, previewMedia]);

  const addMessage = (content: string, type: 'text' | 'image' | 'video' | 'audio' = 'text', file?: File) => {
    const newMessage: Message = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type,
      content,
      senderId: clientId,
      timestamp: Date.now(),
      file
    };
    
    setMessages(prev => [...prev, newMessage]);
    console.log('Message added:', newMessage);
  };

  const handleSendText = () => {
    if (inputText.trim()) {
      addMessage(inputText.trim(), 'text');
      setInputText('');
    }
  };

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendText();
    }
  };

  // Camera Functions
  const startCamera = async (mode: 'photo' | 'video') => {
    try {
      console.log('Starting camera:', mode, facingMode);
      
      if (!navigator.mediaDevices?.getUserMedia) {
        alert('Camera not supported in this browser');
        return;
      }

      const constraints = {
        video: { facingMode },
        audio: mode === 'video'
      };

      const stream = await navigator.mediaDevices.getUserMedia(constraints);
      setMediaStream(stream);
      setCameraMode(mode);
      setShowCamera(true);

      setTimeout(() => {
        if (videoRef.current && stream) {
          videoRef.current.srcObject = stream;
          videoRef.current.play();
        }
      }, 100);

    } catch (error) {
      console.error('Camera error:', error);
      alert('Failed to access camera. Please check permissions.');
    }
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

  const switchCamera = () => {
    if (mediaStream) {
      mediaStream.getTracks().forEach(track => track.stop());
    }
    setFacingMode(prev => prev === 'user' ? 'environment' : 'user');
    setTimeout(() => startCamera(cameraMode), 100);
  };

  const capturePhoto = () => {
    if (!videoRef.current) return;

    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d');
    
    if (context) {
      canvas.width = videoRef.current.videoWidth;
      canvas.height = videoRef.current.videoHeight;
      context.drawImage(videoRef.current, 0, 0);
      
      canvas.toBlob((blob) => {
        if (blob) {
          const file = new File([blob], `photo-${Date.now()}.jpg`, { type: 'image/jpeg' });
          const url = URL.createObjectURL(blob);
          
          setPreviewMedia({ file, url, type: 'image' });
          setShowPreview(true);
          stopCamera();
        }
      }, 'image/jpeg', 0.9);
    }
  };

  const startVideoRecording = () => {
    if (!mediaStream) return;

    const chunks: Blob[] = [];
    const recorder = new MediaRecorder(mediaStream);
    
    recorder.ondataavailable = (event) => {
      if (event.data.size > 0) chunks.push(event.data);
    };
    
    recorder.onstop = () => {
      const blob = new Blob(chunks, { type: 'video/webm' });
      const file = new File([blob], `video-${Date.now()}.webm`, { type: 'video/webm' });
      const url = URL.createObjectURL(blob);
      
      setPreviewMedia({ file, url, type: 'video' });
      setShowPreview(true);
      stopCamera();
    };
    
    setMediaRecorder(recorder);
    recorder.start();
    setIsRecording(true);
    setRecordingTime(0);
    
    recordingTimerRef.current = setInterval(() => {
      setRecordingTime(prev => prev + 1);
    }, 1000);
  };

  const stopVideoRecording = () => {
    if (mediaRecorder && mediaRecorder.state === 'recording') {
      mediaRecorder.stop();
    }
    if (recordingTimerRef.current) {
      clearInterval(recordingTimerRef.current);
    }
  };

  // Audio Recording
  const toggleAudioRecording = async () => {
    if (isRecording) {
      if (mediaRecorder && mediaRecorder.state === 'recording') {
        mediaRecorder.stop();
      }
      return;
    }

    try {
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
      setMediaStream(stream);
      
      const chunks: Blob[] = [];
      const recorder = new MediaRecorder(stream);
      
      recorder.ondataavailable = (event) => {
        if (event.data.size > 0) chunks.push(event.data);
      };
      
      recorder.onstop = () => {
        const blob = new Blob(chunks, { type: 'audio/webm' });
        const file = new File([blob], `audio-${Date.now()}.webm`, { type: 'audio/webm' });
        const url = URL.createObjectURL(blob);
        
        setPreviewMedia({ file, url, type: 'audio' });
        setShowPreview(true);
        
        stream.getTracks().forEach(track => track.stop());
        setMediaStream(null);
        setIsRecording(false);
        setRecordingTime(0);
      };
      
      setMediaRecorder(recorder);
      recorder.start();
      setIsRecording(true);
      setRecordingTime(0);
      
      recordingTimerRef.current = setInterval(() => {
        setRecordingTime(prev => prev + 1);
      }, 1000);
      
    } catch (error) {
      alert('Microphone access failed');
    }
  };

  // File Upload
  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (file.size > 25 * 1024 * 1024) {
      alert('File too large. Maximum size is 25MB.');
      return;
    }

    const url = URL.createObjectURL(file);
    let type: 'image' | 'video' | 'audio';
    
    if (file.type.startsWith('image/')) type = 'image';
    else if (file.type.startsWith('video/')) type = 'video';
    else if (file.type.startsWith('audio/')) type = 'audio';
    else type = 'image'; // Default for other files

    setPreviewMedia({ file, url, type });
    setShowPreview(true);
    
    event.target.value = '';
  };

  // Preview Actions
  const sendMedia = () => {
    if (previewMedia) {
      addMessage(previewMedia.file.name, previewMedia.type, previewMedia.file);
      URL.revokeObjectURL(previewMedia.url);
      setPreviewMedia(null);
      setShowPreview(false);
    }
  };

  const cancelPreview = () => {
    if (previewMedia) {
      URL.revokeObjectURL(previewMedia.url);
      setPreviewMedia(null);
    }
    setShowPreview(false);
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  return (
    <div className="chat-room">
      {/* Header */}
      <div className="chat-header">
        <div className="room-info">
          <h2>Room: {roomId}</h2>
          <div className="status">Connected</div>
        </div>
        <button className="leave-btn" onClick={onLeave}>
          Leave Room
        </button>
      </div>

      {/* Messages Area */}
      <div className="messages-container">
        {messages.length === 0 ? (
          <div className="empty-state">
            <div className="empty-icon">💬</div>
            <h3>No messages yet</h3>
            <p>Send a message to start the conversation</p>
          </div>
        ) : (
          messages.map((message) => (
            <div key={message.id} className={`message ${message.senderId === clientId ? 'own' : 'other'}`}>
              <div className="message-content">
                {message.type === 'text' && message.content}
                
                {message.type === 'image' && message.file && (
                  <div className="media-message">
                    <img src={URL.createObjectURL(message.file)} alt="Shared image" />
                    <p>📷 {message.content}</p>
                  </div>
                )}
                
                {message.type === 'video' && message.file && (
                  <div className="media-message">
                    <video controls src={URL.createObjectURL(message.file)} />
                    <p>🎥 {message.content}</p>
                  </div>
                )}
                
                {message.type === 'audio' && message.file && (
                  <div className="media-message">
                    <audio controls src={URL.createObjectURL(message.file)} />
                    <p>🎤 {message.content}</p>
                  </div>
                )}
              </div>
              <div className="message-time">
                {new Date(message.timestamp).toLocaleTimeString()}
              </div>
            </div>
          ))
        )}
        <div ref={messagesEndRef} />
      </div>

      {/* Camera Interface */}
      {showCamera && (
        <div className="camera-overlay">
          <div className="camera-header">
            <button className="camera-btn" onClick={stopCamera}>✕</button>
            <span>{cameraMode === 'photo' ? 'Take Photo' : 'Record Video'}</span>
            <button className="camera-btn" onClick={switchCamera}>🔄</button>
          </div>
          
          <div className="camera-preview">
            <video 
              ref={videoRef} 
              autoPlay 
              playsInline 
              muted
              style={{ transform: facingMode === 'user' ? 'scaleX(-1)' : 'none' }}
            />
            
            {isRecording && (
              <div className="recording-indicator">
                <div className="rec-dot"></div>
                REC {formatTime(recordingTime)}
              </div>
            )}
          </div>
          
          <div className="camera-controls">
            {cameraMode === 'photo' ? (
              <button className="capture-btn" onClick={capturePhoto}>
                <div className="capture-inner"></div>
              </button>
            ) : (
              <button 
                className={`capture-btn ${isRecording ? 'recording' : ''}`}
                onClick={isRecording ? stopVideoRecording : startVideoRecording}
              >
                <div className="capture-inner"></div>
              </button>
            )}
          </div>
        </div>
      )}

      {/* Media Preview */}
      {showPreview && previewMedia && (
        <div className="preview-overlay">
          <div className="preview-modal">
            <div className="preview-header">
              <h3>Send {previewMedia.type}?</h3>
              <button onClick={cancelPreview}>✕</button>
            </div>
            
            <div className="preview-content">
              {previewMedia.type === 'image' && (
                <img src={previewMedia.url} alt="Preview" />
              )}
              {previewMedia.type === 'video' && (
                <video src={previewMedia.url} controls />
              )}
              {previewMedia.type === 'audio' && (
                <div className="audio-preview">
                  <div className="audio-icon">🎤</div>
                  <audio src={previewMedia.url} controls />
                </div>
              )}
            </div>
            
            <div className="preview-info">
              <p>{previewMedia.file.name}</p>
              <p>{formatFileSize(previewMedia.file.size)}</p>
            </div>
            
            <div className="preview-actions">
              <button className="cancel-btn" onClick={cancelPreview}>Cancel</button>
              <button className="send-btn" onClick={sendMedia}>Send</button>
            </div>
          </div>
        </div>
      )}

      {/* Input Area */}
      <div className="input-area">
        <div className="text-input">
          <textarea
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Type a message..."
            rows={1}
          />
          <button 
            className="send-text-btn"
            onClick={handleSendText}
            disabled={!inputText.trim()}
          >
            ➤
          </button>
        </div>
        
        <div className="media-buttons">
          <input
            type="file"
            ref={fileInputRef}
            accept="image/*,video/*,audio/*"
            style={{ display: 'none' }}
            onChange={handleFileSelect}
          />
          
          <button onClick={() => fileInputRef.current?.click()}>
            📎 File
          </button>
          
          <button onClick={() => startCamera('photo')}>
            📷 Photo
          </button>
          
          <button onClick={() => startCamera('video')}>
            🎥 Video
          </button>
          
          <button 
            className={isRecording ? 'recording' : ''}
            onClick={toggleAudioRecording}
          >
            {isRecording ? `⏹️ ${formatTime(recordingTime)}` : '🎤 Voice'}
          </button>
        </div>
      </div>
    </div>
  );
}

export default ChatRoom;
