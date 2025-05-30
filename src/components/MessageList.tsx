import React from 'react';
import { Message } from '../types';

interface MessageListProps {
  messages: Message[];
  currentUserId: string;
}

function MessageList({ messages, currentUserId }: MessageListProps) {
  const formatTime = (timestamp: number) => {
    return new Date(timestamp).toLocaleTimeString([], { 
      hour: '2-digit', 
      minute: '2-digit' 
    });
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const renderMessage = (message: Message) => {
    const isOwn = message.senderId === currentUserId;
    
    return (
      <div 
        key={message.id} 
        className={`message ${isOwn ? 'own' : 'other'}`}
      >
        {!isOwn && (
          <div className="message-sender">User {message.senderId.slice(-4)}</div>
        )}
        <div className="message-content">
          {message.type === 'text' && message.content}
          
          {message.type === 'image' && (
            <div className="message-media">
              {message.file ? (
                <>
                  <img 
                    src={URL.createObjectURL(message.file)} 
                    alt={message.content}
                    className="message-image"
                    onLoad={(e) => {
                      // Clean up object URL after image loads
                      setTimeout(() => {
                        URL.revokeObjectURL((e.target as HTMLImageElement).src);
                      }, 1000);
                    }}
                  />
                  <div className="media-info">
                    <span>📷 {message.content}</span>
                    <span>{formatFileSize(message.file.size)}</span>
                  </div>
                </>
              ) : (
                <div className="media-placeholder">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                    <circle cx="8.5" cy="8.5" r="1.5"/>
                    <polyline points="21,15 16,10 5,21"/>
                  </svg>
                  <span>{message.content}</span>
                </div>
              )}
            </div>
          )}
          
          {message.type === 'video' && (
            <div className="message-media">
              {message.file ? (
                <>
                  <video 
                    controls 
                    className="message-video"
                    src={URL.createObjectURL(message.file)}
                    onLoadedData={(e) => {
                      // Clean up object URL after video loads
                      setTimeout(() => {
                        URL.revokeObjectURL((e.target as HTMLVideoElement).src);
                      }, 1000);
                    }}
                  />
                  <div className="media-info">
                    <span>🎥 {message.content}</span>
                    <span>{formatFileSize(message.file.size)}</span>
                  </div>
                </>
              ) : (
                <div className="media-placeholder">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <polygon points="23 7 16 12 23 17 23 7"/>
                    <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
                  </svg>
                  <span>{message.content}</span>
                </div>
              )}
            </div>
          )}
          
          {message.type === 'audio' && (
            <div className="message-media">
              {message.file ? (
                <>
                  <audio 
                    controls 
                    className="message-audio"
                    src={URL.createObjectURL(message.file)}
                    onLoadedData={(e) => {
                      // Clean up object URL after audio loads
                      setTimeout(() => {
                        URL.revokeObjectURL((e.target as HTMLAudioElement).src);
                      }, 1000);
                    }}
                  />
                  <div className="media-info">
                    <span>🎤 {message.content}</span>
                    <span>{formatFileSize(message.file.size)}</span>
                  </div>
                </>
              ) : (
                <div className="media-placeholder">
                  <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                    <path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/>
                    <path d="M19 10v2a7 7 0 0 1-14 0v-2"/>
                  </svg>
                  <span>{message.content}</span>
                </div>
              )}
            </div>
          )}
        </div>
        
        <div className="message-time">{formatTime(message.timestamp)}</div>
      </div>
    );
  };

  if (messages.length === 0) {
    return (
      <div className="messages-area">
        <div className="empty-messages">
          <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.5">
            <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>
          </svg>
          <h3>No messages yet</h3>
          <p>Send a message to start the conversation</p>
        </div>
      </div>
    );
  }

  return (
    <div className="messages-area">
      {messages.map(renderMessage)}
    </div>
  );
}

export default MessageList;
