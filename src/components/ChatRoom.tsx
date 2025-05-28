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

  const handleSendFile = async (file: File) => {
    try {
      const message: Message = {
        id: `msg_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
        type: file.type.startsWith('image/') ? 'image' : 'video',
        content: file.name,
        senderId: clientId,
        timestamp: Date.now(),
        file: file
      };

      // Add to local messages
      setMessages(prev => [...(prev || []), message]);

      // Send file to all peers
      await sendFile(file, message.id);
      
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
    return `Connected to ${peers.length} peer${peers.length !== 1 ? 's' : ''}`;
  };

  return (
    <div className="chat-room">
      <div className="chat-header">
        <div className="chat-header-info">
          <h2>Room {roomId}</h2>
          <div className="connection-status">
            <div className={`status-indicator ${isConnected ? 'connected' : 'connecting'}`}></div>
            {getConnectionStatus()}
          </div>
        </div>
        
        <div className="chat-header-actions">
          <button 
            className="icon-button"
            onClick={() => setShowPeerList(true)}
            title="View peers"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
            {peers.length > 0 && <span className="peer-count">{peers.length}</span>}
          </button>
          
          <button 
            className="icon-button"
            onClick={() => setShowFileUpload(true)}
            title="Share file"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
            </svg>
          </button>
          
          <button 
            className="icon-button leave-button"
            onClick={handleLeave}
            title="Leave room"
          >
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/>
              <polyline points="16,17 21,12 16,7"/>
              <line x1="21" y1="12" x2="9" y2="12"/>
            </svg>
          </button>
        </div>
      </div>

      {(webrtcError || transferError) && (
        <div className="error-banner">
          <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10"/>
            <line x1="15" y1="9" x2="9" y2="15"/>
            <line x1="9" y1="9" x2="15" y2="15"/>
          </svg>
          {webrtcError || transferError}
        </div>
      )}

      <div className="chat-content">
        <MessageList messages={messages || []} currentUserId={clientId} />
        <div ref={messagesEndRef} />
      </div>

      {activeTransfers.length > 0 && (
        <div className="file-transfers">
          {activeTransfers.map(transfer => (
            <FileTransferProgress key={transfer.id} transfer={transfer} />
          ))}
        </div>
      )}

      <MessageInput onSendMessage={handleSendMessage} disabled={!isConnected} />

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
