import { useState, useEffect, useCallback, useRef } from 'react';
import { WebRTCService } from '../services/webrtc';
import { WebSocketService } from '../services/websocket';

export function useWebRTC(roomId: string, clientId: string) {
  const [peers, setPeers] = useState<string[]>([]);
  const [isConnected, setIsConnected] = useState(false);
  const [connectionState, setConnectionState] = useState<'connecting' | 'connected' | 'disconnected' | 'failed'>('connecting');
  const [error, setError] = useState<string | null>(null);

  const webrtcRef = useRef<WebRTCService | null>(null);
  const websocketRef = useRef<WebSocketService | null>(null);

  const initializeConnections = useCallback(async () => {
    try {
      setError(null);
      setConnectionState('connecting');

      // Initialize WebRTC service
      webrtcRef.current = new WebRTCService(clientId);
      
      // Initialize WebSocket service
      websocketRef.current = new WebSocketService(roomId, clientId);

      // Set up WebRTC event listeners
      const webrtc = webrtcRef.current;
      
      webrtc.addEventListener('peer-connected', (event: CustomEvent) => {
        console.log('Peer connected:', event.detail.peerId);
        setPeers(prev => {
          if (!prev.includes(event.detail.peerId)) {
            return [...prev, event.detail.peerId];
          }
          return prev;
        });
      });

      webrtc.addEventListener('peer-disconnected', (event: CustomEvent) => {
        console.log('Peer disconnected:', event.detail.peerId);
        setPeers(prev => prev.filter(id => id !== event.detail.peerId));
      });

      webrtc.addEventListener('message', (event: CustomEvent) => {
        const { message } = event.detail;
        window.dispatchEvent(new CustomEvent('webrtc-message', {
          detail: message
        }));
      });

      webrtc.addEventListener('ice-candidate', async (event: CustomEvent) => {
        const { peerId, candidate } = event.detail;
        websocketRef.current?.sendSignalingMessage('ice-candidate', peerId, candidate);
      });

      // Set up WebSocket event listeners
      const websocket = websocketRef.current;

      websocket.addEventListener('init-success', async (event: CustomEvent) => {
        console.log('WebSocket initialized, existing peers:', event.detail.peers);
        setIsConnected(true);
        setConnectionState('connected');

        // Initiate connections to existing peers
        for (const peerId of event.detail.peers) {
          try {
            const offer = await webrtc.createOffer(peerId);
            websocket.sendSignalingMessage('offer', peerId, offer);
          } catch (error) {
            console.error(`Error creating offer for peer ${peerId}:`, error);
          }
        }
      });

      websocket.addEventListener('peer-joined', async (event: CustomEvent) => {
        const { peerId } = event.detail;
        console.log('New peer joined:', peerId);
        
        // We don't initiate connection here, we wait for their offer
      });

      websocket.addEventListener('peer-left', (event: CustomEvent) => {
        const { peerId } = event.detail;
        console.log('Peer left:', peerId);
        setPeers(prev => prev.filter(id => id !== peerId));
      });

      websocket.addEventListener('signaling', async (event: CustomEvent) => {
        const { type, from, payload } = event.detail;
        
        try {
          switch (type) {
            case 'offer':
              const answer = await webrtc.createAnswer(from, payload);
              websocket.sendSignalingMessage('answer', from, answer);
              break;
              
            case 'answer':
              await webrtc.handleAnswer(from, payload);
              break;
              
            case 'ice-candidate':
              await webrtc.addIceCandidate(from, payload);
              break;
          }
        } catch (error) {
          console.error(`Error handling ${type} from ${from}:`, error);
        }
      });

      websocket.addEventListener('disconnected', () => {
        setIsConnected(false);
        setConnectionState('disconnected');
      });

      websocket.addEventListener('reconnected', () => {
        setIsConnected(true);
        setConnectionState('connected');
      });

      websocket.addEventListener('error', (event: CustomEvent) => {
        setError(event.detail.message);
        setConnectionState('failed');
      });

      // Connect to WebSocket
      await websocket.connect();

    } catch (error) {
      console.error('Error initializing connections:', error);
      setError(error instanceof Error ? error.message : 'Connection failed');
      setConnectionState('failed');
    }
  }, [roomId, clientId]);

  const sendMessage = useCallback(async (type: string, data: any, targetPeerId?: string) => {
    if (webrtcRef.current) {
      webrtcRef.current.sendMessage(type, data, targetPeerId);
    }
  }, []);

  // Initialize connections on mount
  useEffect(() => {
    initializeConnections();

    // Cleanup on unmount
    return () => {
      webrtcRef.current?.close();
      websocketRef.current?.close();
    };
  }, [initializeConnections]);

  // Update connection state based on peer connections
  useEffect(() => {
    if (isConnected && peers.length > 0) {
      setConnectionState('connected');
    } else if (isConnected) {
      setConnectionState('connected');
    }
  }, [isConnected, peers.length]);

  return {
    peers,
    isConnected,
    connectionState,
    error,
    sendMessage
  };
}
