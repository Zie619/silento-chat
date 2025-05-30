import React, { useState, useEffect, useRef } from 'react';
import MessageList from './MessageList';
import MessageInput from './MessageInput';
import PeerList from './PeerList';
import FileUpload from './FileUpload';
import FileTransferProgress from './FileTransferProgress';
import { useWebRTC } from '../hooks/useWebRTC';
import { useFileTransfer } from '../hooks/useFileTransfer';
import { Message, FileTransfer } from '../types';

interface ChatRoomProps {
  roomId: string;
  clientId: string;
  onLeave: () => void;
}

function ChatRoom({ roomId, clientId, onLeave }: ChatRoomProps) {
  const [messages, setMessages] = useState<Message[]>();
  const [showPeerList, setShowPeerList] = useState(false);
  const [showFileUpload, setShowFileUpload] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const {
    peers,
    isConnected,
    connectionState,
    sendMessage: sendP2PMessage,
    error: webrtcError
  } = useWebRTC(roomId, clientId);

  const {
    activeTransfers,
    sendFile,
    error: transferError
  } = useFileTransfer(sendP2PMessage);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const handleSendMessage = async (content: string) => {
    const message: Message = {
      id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      type: 'text',
      content,
      senderId: clientId,
      timestamp: Date.now()
    };

    // Add to local messages immediately
    setMessages(prev => [...(prev || []), message]);

    // Send to peers
    await sendP2PMessage('message', message);
  };

  const handleSendMedia = async (file: File, type: 'image' | 'video' | 'audio') => {
    try {
      const message: Message = {
        id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type: type,
        content: file.name,
        senderId: clientId,
        timestamp: Date.now(),
        file: file
      };

      // Add to local messages
      setMessages(prev => [...(prev || []), message]);

      // Send file to all peers if available
      if (sendFile) {
        await sendFile(file, message.id);
      }
      
    } catch (error) {
      console.error('Error sending media:', error);
    }
  };

  const handleSendFile = async (file: File) => {
    try {
      const fileType = file.type.startsWith('image/') ? 'image' : 
                       file.type.startsWith('video/') ? 'video' : 
                       file.type.startsWith('audio/') ? 'audio' : 'image';
      
      await handleSendMedia(file, fileType as 'image' | 'video' | 'audio');
      setShowFileUpload(false);
    } catch (error) {
      console.error('Error sending file:', error);
    }
  };

  // Listen for incoming messages
  useEffect(() => {
    const handleIncomingMessage = (event: CustomEvent) => {
      const { type, data } = event.detail;
      
      if (type === 'message') {
        const message = data as Message;
        setMessages(prev => {
          const existing = prev || [];
          // Avoid duplicates
          if (existing.some(m => m.id === message.id)) {
            return existing;
          }
          return [...existing, message];
        });
      }
    };

    window.addEventListener('webrtc-message', handleIncomingMessage as EventListener);
    return () => window.removeEventListener('webrtc-message', handleIncomingMessage as EventListener);
  }, []);

  const handleLeave = () => {
    if (window.confirm('Are you sure you want to leave? This will end your session.')) {
      onLeave();
    }
  };

  const getConnectionStatus = () => {
    if (!isConnected) return 'Connecting...';
    if (peers.length === 0) return 'Waiting for peers...';
    return `${peers.length} peer${peers.length !== 1 ? 's' : ''} connected`;
  };

  return (
    <div className="chat-screen">
      <div className="chat-header">
        <div className="chat-header-content">
          <div className="room-info">
            <h2>{roomId}</h2>
            <div className="status-indicator">
              {getConnectionStatus()}
            </div>
          </div>
          
          <div style={{ display: 'flex', gap: 'var(--space-sm)', alignItems: 'center' }}>
            <button 
              className="peer-button"
              onClick={() => setShowPeerList(true)}
              title="View peers"
            >
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
                <circle cx="9" cy="7" r="4"/>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
              </svg>
              {peers.length > 0 && <span className="peer-count">{peers.length}</span>}
            </button>
            
            <button 
              className="btn-leave"
              onClick={handleLeave}
              title="Leave room"
            >
              Leave
            </button>
          </div>
        </div>
      </div>

      {(webrtcError || transferError) && (
        <div className="error-banner">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="8" x2="12" y2="12"/>
            <line x1="12" y1="16" x2="12.01" y2="16"/>
          </svg>
          {webrtcError || transferError}
        </div>
      )}

      <div className="chat-container">
        <div className="messages-area">
          <MessageList messages={messages || []} currentUserId={clientId} />
          <div ref={messagesEndRef} />
        </div>

        {activeTransfers.length > 0 && (
          <div className="transfer-container">
            {activeTransfers.map(transfer => (
              <FileTransferProgress key={transfer.id} transfer={transfer} />
            ))}
          </div>
        )}
      </div>

      <MessageInput 
        onSendMessage={handleSendMessage} 
        onSendMedia={handleSendMedia}
        disabled={!isConnected} 
      />

      {showPeerList && (
        <PeerList 
          peers={peers}
          onClose={() => setShowPeerList(false)}
        />
      )}

      {showFileUpload && (
        <FileUpload 
          onFileSelected={handleSendFile}
          onClose={() => setShowFileUpload(false)}
        />
      )}
    </div>
  );
}

export default ChatRoom;
