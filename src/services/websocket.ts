export class WebSocketService {
  private ws: WebSocket | null = null;
  private roomId: string;
  private clientId: string;
  private eventTarget = new EventTarget();
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectTimeout: NodeJS.Timeout | null = null;

  constructor(roomId: string, clientId: string) {
    this.roomId = roomId;
    this.clientId = clientId;
  }

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        const protocol = window.location.protocol === "https:" ? "wss:" : "ws:";
        const wsUrl = `${protocol}//${window.location.host}/ws`;
        
        this.ws = new WebSocket(wsUrl);

        this.ws.onopen = () => {
          console.log('WebSocket connected');
          this.reconnectAttempts = 0;
          
          // Initialize connection with room and client info
          this.send({
            type: 'init',
            roomId: this.roomId,
            clientId: this.clientId
          });
          
          resolve();
        };

        this.ws.onmessage = (event) => {
          try {
            const message = JSON.parse(event.data);
            this.handleMessage(message);
          } catch (error) {
            console.error('Error parsing WebSocket message:', error);
          }
        };

        this.ws.onclose = (event) => {
          console.log('WebSocket disconnected:', event.code, event.reason);
          this.eventTarget.dispatchEvent(new CustomEvent('disconnected'));
          
          // Attempt to reconnect if not intentionally closed
          if (event.code !== 1000 && this.reconnectAttempts < this.maxReconnectAttempts) {
            this.attemptReconnect();
          }
        };

        this.ws.onerror = (error) => {
          console.error('WebSocket error:', error);
          reject(new Error('WebSocket connection failed'));
        };

      } catch (error) {
        reject(error);
      }
    });
  }

  send(message: any): void {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket not connected, message not sent:', message);
    }
  }

  sendSignalingMessage(type: string, targetPeerId: string, payload: any): void {
    this.send({
      type,
      from: this.clientId,
      to: targetPeerId,
      payload
    });
  }

  addEventListener(type: string, listener: EventListener): void {
    this.eventTarget.addEventListener(type, listener);
  }

  removeEventListener(type: string, listener: EventListener): void {
    this.eventTarget.removeEventListener(type, listener);
  }

  close(): void {
    if (this.reconnectTimeout) {
      clearTimeout(this.reconnectTimeout);
      this.reconnectTimeout = null;
    }
    
    if (this.ws) {
      this.ws.close(1000, 'Client disconnecting');
      this.ws = null;
    }
  }

  private handleMessage(message: any): void {
    switch (message.type) {
      case 'init-success':
        this.eventTarget.dispatchEvent(new CustomEvent('init-success', {
          detail: { peers: message.peers }
        }));
        break;

      case 'peer-joined':
        this.eventTarget.dispatchEvent(new CustomEvent('peer-joined', {
          detail: { peerId: message.clientId }
        }));
        break;

      case 'peer-left':
        this.eventTarget.dispatchEvent(new CustomEvent('peer-left', {
          detail: { peerId: message.clientId }
        }));
        break;

      case 'offer':
      case 'answer':
      case 'ice-candidate':
        this.eventTarget.dispatchEvent(new CustomEvent('signaling', {
          detail: {
            type: message.type,
            from: message.from,
            to: message.to,
            payload: message.payload
          }
        }));
        break;

      case 'error':
        console.error('WebSocket error message:', message.message);
        this.eventTarget.dispatchEvent(new CustomEvent('error', {
          detail: { message: message.message }
        }));
        break;

      default:
        console.warn('Unknown message type:', message.type);
    }
  }

  private attemptReconnect(): void {
    this.reconnectAttempts++;
    const delay = Math.min(1000 * Math.pow(2, this.reconnectAttempts - 1), 30000);
    
    console.log(`Attempting to reconnect in ${delay}ms (attempt ${this.reconnectAttempts}/${this.maxReconnectAttempts})`);
    
    this.reconnectTimeout = setTimeout(async () => {
      try {
        await this.connect();
        this.eventTarget.dispatchEvent(new CustomEvent('reconnected'));
      } catch (error) {
        console.error('Reconnection failed:', error);
        if (this.reconnectAttempts < this.maxReconnectAttempts) {
          this.attemptReconnect();
        } else {
          this.eventTarget.dispatchEvent(new CustomEvent('reconnect-failed'));
        }
      }
    }, delay);
  }

  isConnected(): boolean {
    return this.ws?.readyState === WebSocket.OPEN;
  }
}
