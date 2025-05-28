import React from 'react';
import { FileTransfer } from '../types';

interface FileTransferProgressProps {
  transfer: FileTransfer;
}

function FileTransferProgress({ transfer }: FileTransferProgressProps) {
  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const formatSpeed = (bytesPerSecond: number) => {
    return `${formatFileSize(bytesPerSecond)}/s`;
  };

  const formatETA = (seconds: number) => {
    if (seconds < 60) return `${Math.round(seconds)}s`;
    const minutes = Math.floor(seconds / 60);
    const remainingSeconds = Math.round(seconds % 60);
    return `${minutes}m ${remainingSeconds}s`;
  };

  const getTransferIcon = () => {
    if (transfer.status === 'completed') {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polyline points="20,6 9,17 4,12"/>
        </svg>
      );
    } else if (transfer.status === 'error') {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <circle cx="12" cy="12" r="10"/>
          <line x1="15" y1="9" x2="9" y2="15"/>
          <line x1="9" y1="9" x2="15" y2="15"/>
        </svg>
      );
    } else {
      return (
        <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/>
          <polyline points="17,8 12,3 7,8"/>
          <line x1="12" y1="3" x2="12" y2="15"/>
        </svg>
      );
    }
  };

  const getStatusText = () => {
    switch (transfer.status) {
      case 'preparing':
        return 'Preparing...';
      case 'transferring':
        return `${Math.round(transfer.progress)}% • ${formatSpeed(transfer.speed || 0)}`;
      case 'completed':
        return 'Completed';
      case 'error':
        return transfer.error || 'Transfer failed';
      default:
        return 'Unknown status';
    }
  };

  const getStatusClass = () => {
    switch (transfer.status) {
      case 'completed':
        return 'success';
      case 'error':
        return 'error';
      default:
        return 'progress';
    }
  };

  return (
    <div className={`file-transfer ${getStatusClass()}`}>
      <div className="transfer-header">
        <div className="transfer-icon">
          {getTransferIcon()}
        </div>
        
        <div className="transfer-info">
          <div className="transfer-filename">{transfer.fileName}</div>
          <div className="transfer-details">
            <span className="file-size">{formatFileSize(transfer.fileSize)}</span>
            {transfer.direction === 'outgoing' ? ' • Sending' : ' • Receiving'}
            {transfer.peerId && ` • ${transfer.peerId.substring(0, 8)}...`}
          </div>
        </div>

        <div className="transfer-status">
          {getStatusText()}
          {transfer.status === 'transferring' && transfer.estimatedTime && (
            <div className="eta">ETA: {formatETA(transfer.estimatedTime)}</div>
          )}
        </div>
      </div>

      {(transfer.status === 'transferring' || transfer.status === 'preparing') && (
        <div className="progress-bar">
          <div 
            className="progress-fill" 
            style={{ width: `${transfer.progress}%` }}
          ></div>
        </div>
      )}

      {transfer.status === 'transferring' && (
        <div className="transfer-details-expanded">
          <div className="detail-item">
            <span>Transferred:</span>
            <span>
              {formatFileSize((transfer.fileSize * transfer.progress) / 100)} / {formatFileSize(transfer.fileSize)}
            </span>
          </div>
          {transfer.speed && (
            <div className="detail-item">
              <span>Speed:</span>
              <span>{formatSpeed(transfer.speed)}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export default FileTransferProgress;
