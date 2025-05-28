export interface Message {
  id: string;
  type: 'text' | 'image' | 'video';
  content: string;
  senderId: string;
  timestamp: number;
  file?: File;
}

export interface FileTransfer {
  id: string;
  fileName: string;
  fileSize: number;
  fileType: string;
  messageId: string;
  peerId: string;
  direction: 'incoming' | 'outgoing';
  status: 'preparing' | 'transferring' | 'completed' | 'error';
  progress: number;
  speed?: number;
  estimatedTime?: number;
  error?: string;
  startTime: number;
}

export interface FileChunk {
  id: string;
  messageId: string;
  index: number;
  total: number;
  data: ArrayBuffer;
  fileName: string;
  fileType: string;
  fileSize: number;
}

export interface Peer {
  id: string;
  connectionState: RTCPeerConnectionState;
  lastSeen: number;
}

export interface RoomState {
  roomId: string;
  clientId: string;
  peers: Peer[];
  isConnected: boolean;
  connectionState: 'connecting' | 'connected' | 'disconnected' | 'failed';
}

export interface WebRTCMessage {
  type: string;
  data: any;
  from: string;
  timestamp?: number;
}

export interface SignalingMessage {
  type: 'offer' | 'answer' | 'ice-candidate';
  from: string;
  to: string;
  payload: RTCSessionDescriptionInit | RTCIceCandidateInit;
}

export interface WebSocketMessage {
  type: string;
  roomId?: string;
  clientId?: string;
  from?: string;
  to?: string;
  payload?: any;
}
