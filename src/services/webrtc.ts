export class WebRTCService {
  private localId: string;
  private connections = new Map<string, RTCPeerConnection>();
  private dataChannels = new Map<string, RTCDataChannel>();
  private eventTarget = new EventTarget();

  // ICE servers for STUN/TURN
  private iceServers = [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' },
    { urls: 'stun:stun2.l.google.com:19302' }
  ];

  constructor(clientId: string) {
    this.localId = clientId;
  }

  async createOffer(peerId: string): Promise<RTCSessionDescriptionInit> {
    const pc = this.createPeerConnection(peerId);
    
    // Create data channel for this peer
    const dataChannel = pc.createDataChannel('chat', {
      ordered: true
    });
    this.setupDataChannel(dataChannel, peerId);
    this.dataChannels.set(peerId, dataChannel);

    const offer = await pc.createOffer();
    await pc.setLocalDescription(offer);
    
    return offer;
  }

  async createAnswer(peerId: string, offer: RTCSessionDescriptionInit): Promise<RTCSessionDescriptionInit> {
    const pc = this.createPeerConnection(peerId);
    
    await pc.setRemoteDescription(offer);
    const answer = await pc.createAnswer();
    await pc.setLocalDescription(answer);
    
    return answer;
  }

  async handleAnswer(peerId: string, answer: RTCSessionDescriptionInit): Promise<void> {
    const pc = this.connections.get(peerId);
    if (pc && pc.signalingState === 'have-local-offer') {
      await pc.setRemoteDescription(answer);
    }
  }

  async addIceCandidate(peerId: string, candidate: RTCIceCandidateInit): Promise<void> {
    const pc = this.connections.get(peerId);
    if (pc && pc.remoteDescription) {
      try {
        await pc.addIceCandidate(candidate);
      } catch (error) {
        console.error('Error adding ICE candidate:', error);
      }
    }
  }

  sendMessage(type: string, data: any, targetPeerId?: string): void {
    const message = JSON.stringify({ type, data, from: this.localId });
    
    if (targetPeerId) {
      const dataChannel = this.dataChannels.get(targetPeerId);
      if (dataChannel && dataChannel.readyState === 'open') {
        dataChannel.send(message);
      }
    } else {
      // Broadcast to all connected peers
      for (const [peerId, dataChannel] of this.dataChannels.entries()) {
        if (dataChannel.readyState === 'open') {
          dataChannel.send(message);
        }
      }
    }
  }

  sendBinaryData(data: ArrayBuffer, targetPeerId: string): void {
    const dataChannel = this.dataChannels.get(targetPeerId);
    if (dataChannel && dataChannel.readyState === 'open') {
      dataChannel.send(data);
    }
  }

  getConnectedPeers(): string[] {
    const connectedPeers: string[] = [];
    for (const [peerId, dataChannel] of this.dataChannels.entries()) {
      if (dataChannel.readyState === 'open') {
        connectedPeers.push(peerId);
      }
    }
    return connectedPeers;
  }

  addEventListener(type: string, listener: EventListener): void {
    this.eventTarget.addEventListener(type, listener);
  }

  removeEventListener(type: string, listener: EventListener): void {
    this.eventTarget.removeEventListener(type, listener);
  }

  close(): void {
    // Close all data channels
    for (const dataChannel of this.dataChannels.values()) {
      dataChannel.close();
    }
    this.dataChannels.clear();

    // Close all peer connections
    for (const pc of this.connections.values()) {
      pc.close();
    }
    this.connections.clear();
  }

  private createPeerConnection(peerId: string): RTCPeerConnection {
    const pc = new RTCPeerConnection({
      iceServers: this.iceServers
    });

    // Handle ICE candidates
    pc.onicecandidate = (event) => {
      if (event.candidate) {
        this.eventTarget.dispatchEvent(new CustomEvent('ice-candidate', {
          detail: { peerId, candidate: event.candidate }
        }));
      }
    };

    // Handle connection state changes
    pc.onconnectionstatechange = () => {
      console.log(`Connection state with ${peerId}: ${pc.connectionState}`);
      this.eventTarget.dispatchEvent(new CustomEvent('connection-state-change', {
        detail: { peerId, state: pc.connectionState }
      }));

      if (pc.connectionState === 'failed' || pc.connectionState === 'disconnected') {
        this.removePeer(peerId);
      }
    };

    // Handle incoming data channels
    pc.ondatachannel = (event) => {
      const dataChannel = event.channel;
      this.setupDataChannel(dataChannel, peerId);
      this.dataChannels.set(peerId, dataChannel);
    };

    this.connections.set(peerId, pc);
    return pc;
  }

  private setupDataChannel(dataChannel: RTCDataChannel, peerId: string): void {
    dataChannel.onopen = () => {
      console.log(`Data channel opened with ${peerId}`);
      this.eventTarget.dispatchEvent(new CustomEvent('peer-connected', {
        detail: { peerId }
      }));
    };

    dataChannel.onclose = () => {
      console.log(`Data channel closed with ${peerId}`);
      this.eventTarget.dispatchEvent(new CustomEvent('peer-disconnected', {
        detail: { peerId }
      }));
    };

    dataChannel.onmessage = (event) => {
      try {
        if (typeof event.data === 'string') {
          const message = JSON.parse(event.data);
          this.eventTarget.dispatchEvent(new CustomEvent('message', {
            detail: { peerId, message }
          }));
        } else if (event.data instanceof ArrayBuffer) {
          this.eventTarget.dispatchEvent(new CustomEvent('binary-data', {
            detail: { peerId, data: event.data }
          }));
        }
      } catch (error) {
        console.error('Error parsing data channel message:', error);
      }
    };

    dataChannel.onerror = (error) => {
      console.error(`Data channel error with ${peerId}:`, error);
    };
  }

  private removePeer(peerId: string): void {
    const dataChannel = this.dataChannels.get(peerId);
    if (dataChannel) {
      dataChannel.close();
      this.dataChannels.delete(peerId);
    }

    const pc = this.connections.get(peerId);
    if (pc) {
      pc.close();
      this.connections.delete(peerId);
    }

    this.eventTarget.dispatchEvent(new CustomEvent('peer-removed', {
      detail: { peerId }
    }));
  }
}
