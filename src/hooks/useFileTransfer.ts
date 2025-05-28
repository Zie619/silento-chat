import { useState, useCallback, useRef } from 'react';
import { FileTransfer, FileChunk } from '../types';

const CHUNK_SIZE = 16384; // 16KB chunks

export function useFileTransfer(sendMessage: (type: string, data: any, targetPeerId?: string) => void) {
  const [activeTransfers, setActiveTransfers] = useState<FileTransfer[]>([]);
  const [error, setError] = useState<string | null>(null);
  
  const incomingChunksRef = useRef<Map<string, Map<number, ArrayBuffer>>>(new Map());
  const transferStatsRef = useRef<Map<string, { startTime: number; transferredBytes: number }>>(new Map());

  const createTransfer = (
    file: File,
    messageId: string,
    peerId: string,
    direction: 'incoming' | 'outgoing'
  ): FileTransfer => {
    return {
      id: `transfer_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      fileName: file.name,
      fileSize: file.size,
      fileType: file.type,
      messageId,
      peerId,
      direction,
      status: 'preparing',
      progress: 0,
      startTime: Date.now()
    };
  };

  const updateTransfer = useCallback((transferId: string, updates: Partial<FileTransfer>) => {
    setActiveTransfers(prev => 
      prev.map(transfer => 
        transfer.id === transferId 
          ? { ...transfer, ...updates }
          : transfer
      )
    );
  }, []);

  const removeTransfer = useCallback((transferId: string) => {
    setActiveTransfers(prev => prev.filter(transfer => transfer.id !== transferId));
  }, []);

  const calculateSpeed = useCallback((transferId: string, transferredBytes: number): number => {
    const stats = transferStatsRef.current.get(transferId);
    if (!stats) return 0;

    const elapsed = (Date.now() - stats.startTime) / 1000; // seconds
    if (elapsed < 1) return 0;

    return transferredBytes / elapsed; // bytes per second
  }, []);

  const sendFile = useCallback(async (file: File, messageId: string) => {
    try {
      setError(null);
      
      // Get connected peers (this would come from WebRTC service)
      const connectedPeers = ['peer1', 'peer2']; // This should be dynamic
      
      if (connectedPeers.length === 0) {
        throw new Error('No connected peers to send file to');
      }

      // Create transfer objects for each peer
      const transfers = connectedPeers.map(peerId => {
        const transfer = createTransfer(file, messageId, peerId, 'outgoing');
        transferStatsRef.current.set(transfer.id, { 
          startTime: Date.now(), 
          transferredBytes: 0 
        });
        return transfer;
      });

      setActiveTransfers(prev => [...prev, ...transfers]);

      // Read file as ArrayBuffer
      const arrayBuffer = await file.arrayBuffer();
      const totalChunks = Math.ceil(arrayBuffer.byteLength / CHUNK_SIZE);

      // Send file metadata first
      sendMessage('file-metadata', {
        messageId,
        fileName: file.name,
        fileSize: file.size,
        fileType: file.type,
        totalChunks
      });

      // Update transfers to transferring status
      transfers.forEach(transfer => {
        updateTransfer(transfer.id, { status: 'transferring' });
      });

      // Send chunks
      for (let i = 0; i < totalChunks; i++) {
        const start = i * CHUNK_SIZE;
        const end = Math.min(start + CHUNK_SIZE, arrayBuffer.byteLength);
        const chunkData = arrayBuffer.slice(start, end);

        const chunk: FileChunk = {
          id: `chunk_${messageId}_${i}`,
          messageId,
          index: i,
          total: totalChunks,
          data: chunkData,
          fileName: file.name,
          fileType: file.type,
          fileSize: file.size
        };

        // Send to all peers
        sendMessage('file-chunk', chunk);

        // Update progress for all transfers
        const progress = ((i + 1) / totalChunks) * 100;
        const transferredBytes = end;

        transfers.forEach(transfer => {
          const speed = calculateSpeed(transfer.id, transferredBytes);
          const remainingBytes = file.size - transferredBytes;
          const estimatedTime = speed > 0 ? remainingBytes / speed : 0;

          updateTransfer(transfer.id, {
            progress,
            speed,
            estimatedTime: estimatedTime > 0 ? estimatedTime : undefined
          });

          // Update stats
          const stats = transferStatsRef.current.get(transfer.id);
          if (stats) {
            stats.transferredBytes = transferredBytes;
          }
        });

        // Small delay to prevent overwhelming the data channel
        await new Promise(resolve => setTimeout(resolve, 1));
      }

      // Mark transfers as completed
      transfers.forEach(transfer => {
        updateTransfer(transfer.id, { 
          status: 'completed', 
          progress: 100,
          speed: undefined,
          estimatedTime: undefined
        });

        // Remove completed transfer after delay
        setTimeout(() => removeTransfer(transfer.id), 3000);
      });

    } catch (error) {
      console.error('Error sending file:', error);
      setError(error instanceof Error ? error.message : 'File transfer failed');
    }
  }, [sendMessage, updateTransfer, removeTransfer, calculateSpeed]);

  const handleIncomingFileMetadata = useCallback((data: any, fromPeerId: string) => {
    const { messageId, fileName, fileSize, fileType, totalChunks } = data;
    
    // Create a placeholder file for the transfer
    const placeholderFile = new File([], fileName, { type: fileType });
    Object.defineProperty(placeholderFile, 'size', { value: fileSize });

    const transfer = createTransfer(placeholderFile, messageId, fromPeerId, 'incoming');
    
    setActiveTransfers(prev => [...prev, transfer]);
    
    // Initialize chunk storage
    incomingChunksRef.current.set(messageId, new Map());
    transferStatsRef.current.set(transfer.id, { 
      startTime: Date.now(), 
      transferredBytes: 0 
    });

    // Update to transferring status
    updateTransfer(transfer.id, { status: 'transferring' });
  }, [updateTransfer]);

  const handleIncomingFileChunk = useCallback(async (chunk: FileChunk, fromPeerId: string) => {
    const { messageId, index, total, data, fileName, fileType, fileSize } = chunk;
    
    // Store chunk
    const chunks = incomingChunksRef.current.get(messageId);
    if (!chunks) return;
    
    chunks.set(index, data);
    
    // Find corresponding transfer
    const transfer = activeTransfers.find(t => 
      t.messageId === messageId && t.peerId === fromPeerId && t.direction === 'incoming'
    );
    
    if (!transfer) return;

    // Update progress
    const progress = (chunks.size / total) * 100;
    const transferredBytes = Array.from(chunks.values())
      .reduce((total, chunk) => total + chunk.byteLength, 0);

    const speed = calculateSpeed(transfer.id, transferredBytes);
    const remainingBytes = fileSize - transferredBytes;
    const estimatedTime = speed > 0 ? remainingBytes / speed : 0;

    updateTransfer(transfer.id, {
      progress,
      speed,
      estimatedTime: estimatedTime > 0 ? estimatedTime : undefined
    });

    // Update stats
    const stats = transferStatsRef.current.get(transfer.id);
    if (stats) {
      stats.transferredBytes = transferredBytes;
    }

    // Check if transfer is complete
    if (chunks.size === total) {
      try {
        // Reconstruct file from chunks
        const sortedChunks = Array.from({ length: total }, (_, i) => chunks.get(i))
          .filter(chunk => chunk !== undefined) as ArrayBuffer[];
        
        const completeFile = new Blob(sortedChunks, { type: fileType });
        const file = new File([completeFile], fileName, { type: fileType });

        // Create message with complete file
        const message = {
          id: messageId,
          type: fileType.startsWith('image/') ? 'image' : 'video',
          content: fileName,
          senderId: fromPeerId,
          timestamp: Date.now(),
          file
        };

        // Dispatch message event
        window.dispatchEvent(new CustomEvent('webrtc-message', {
          detail: { type: 'message', data: message }
        }));

        // Mark transfer as completed
        updateTransfer(transfer.id, { 
          status: 'completed', 
          progress: 100,
          speed: undefined,
          estimatedTime: undefined
        });

        // Clean up
        incomingChunksRef.current.delete(messageId);
        transferStatsRef.current.delete(transfer.id);

        // Remove completed transfer after delay
        setTimeout(() => removeTransfer(transfer.id), 3000);

      } catch (error) {
        console.error('Error reconstructing file:', error);
        updateTransfer(transfer.id, { 
          status: 'error', 
          error: 'Failed to reconstruct file' 
        });
      }
    }
  }, [activeTransfers, updateTransfer, removeTransfer, calculateSpeed]);

  // Listen for incoming file messages
  useEffect(() => {
    const handleWebRTCMessage = (event: CustomEvent) => {
      const { type, data } = event.detail;
      
      if (type === 'file-metadata') {
        handleIncomingFileMetadata(data, 'unknown-peer'); // In real implementation, extract from message
      } else if (type === 'file-chunk') {
        handleIncomingFileChunk(data, 'unknown-peer'); // In real implementation, extract from message
      }
    };

    window.addEventListener('webrtc-message', handleWebRTCMessage as EventListener);
    return () => window.removeEventListener('webrtc-message', handleWebRTCMessage as EventListener);
  }, [handleIncomingFileMetadata, handleIncomingFileChunk]);

  return {
    activeTransfers,
    error,
    sendFile
  };
}
