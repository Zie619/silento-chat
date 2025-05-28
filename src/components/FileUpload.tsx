import React, { useRef, useState } from 'react';

interface FileUploadProps {
  onFileSelected: (file: File) => void;
  onClose: () => void;
}

function FileUpload({ onFileSelected, onClose }: FileUploadProps) {
  const [dragOver, setDragOver] = useState(false);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  const acceptedTypes = {
    image: ['image/jpeg', 'image/png', 'image/gif', 'image/webp'],
    video: ['video/mp4', 'video/mov', 'video/avi', 'video/webm']
  };

  const maxFileSize = 100 * 1024 * 1024; // 100MB

  const isValidFileType = (file: File) => {
    return [...acceptedTypes.image, ...acceptedTypes.video].includes(file.type);
  };

  const formatFileSize = (bytes: number) => {
    if (bytes === 0) return '0 Bytes';
    const k = 1024;
    const sizes = ['Bytes', 'KB', 'MB', 'GB'];
    const i = Math.floor(Math.log(bytes) / Math.log(k));
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i];
  };

  const getFileIcon = (file: File) => {
    if (file.type.startsWith('image/')) {
      return (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
          <circle cx="8.5" cy="8.5" r="1.5"/>
          <polyline points="21,15 16,10 5,21"/>
        </svg>
      );
    } else if (file.type.startsWith('video/')) {
      return (
        <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <polygon points="23 7 16 12 23 17 23 7"/>
          <rect x="1" y="5" width="15" height="14" rx="2" ry="2"/>
        </svg>
      );
    }
    return null;
  };

  const handleFileSelect = (file: File) => {
    if (!isValidFileType(file)) {
      alert('Please select a valid image or video file.');
      return;
    }

    if (file.size > maxFileSize) {
      alert(`File size too large. Maximum size is ${formatFileSize(maxFileSize)}.`);
      return;
    }

    setSelectedFile(file);
  };

  const handleFileInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      handleFileSelect(file);
    }
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setDragOver(false);
    
    const file = e.dataTransfer.files[0];
    if (file) {
      handleFileSelect(file);
    }
  };

  const handleSend = () => {
    if (selectedFile) {
      onFileSelected(selectedFile);
    }
  };

  const handleCancel = () => {
    setSelectedFile(null);
    onClose();
  };

  return (
    <div className="modal-overlay" onClick={(e) => e.target === e.currentTarget && handleCancel()}>
      <div className="file-upload-modal">
        <div className="modal-header">
          <h3>Share File</h3>
          <button className="close-button" onClick={handleCancel}>
            <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="18" y1="6" x2="6" y2="18"/>
              <line x1="6" y1="6" x2="18" y2="18"/>
            </svg>
          </button>
        </div>

        <div className="modal-content">
          {!selectedFile ? (
            <div 
              className={`file-drop-zone ${dragOver ? 'drag-over' : ''}`}
              onDragOver={handleDragOver}
              onDragLeave={handleDragLeave}
              onDrop={handleDrop}
              onClick={() => fileInputRef.current?.click()}
            >
              <div className="drop-zone-content">
                <svg width="48" height="48" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48"/>
                </svg>
                <h4>Drop files here or click to browse</h4>
                <p>Support for images and videos up to {formatFileSize(maxFileSize)}</p>
                
                <div className="supported-formats">
                  <div className="format-group">
                    <strong>Images:</strong> JPEG, PNG, GIF, WebP
                  </div>
                  <div className="format-group">
                    <strong>Videos:</strong> MP4, MOV, AVI, WebM
                  </div>
                </div>
              </div>
              
              <input
                ref={fileInputRef}
                type="file"
                accept={[...acceptedTypes.image, ...acceptedTypes.video].join(',')}
                onChange={handleFileInputChange}
                style={{ display: 'none' }}
              />
            </div>
          ) : (
            <div className="file-preview">
              <div className="file-info">
                <div className="file-icon">
                  {getFileIcon(selectedFile)}
                </div>
                <div className="file-details">
                  <h4>{selectedFile.name}</h4>
                  <p>{formatFileSize(selectedFile.size)}</p>
                  <p className="file-type">{selectedFile.type}</p>
                </div>
              </div>

              {selectedFile.type.startsWith('image/') && (
                <div className="image-preview">
                  <img 
                    src={URL.createObjectURL(selectedFile)} 
                    alt={selectedFile.name}
                    onLoad={(e) => {
                      // Clean up object URL after image loads
                      setTimeout(() => {
                        URL.revokeObjectURL((e.target as HTMLImageElement).src);
                      }, 1000);
                    }}
                  />
                </div>
              )}

              {selectedFile.type.startsWith('video/') && (
                <div className="video-preview">
                  <video 
                    controls 
                    src={URL.createObjectURL(selectedFile)}
                    onLoadedData={(e) => {
                      // Clean up object URL after video loads
                      setTimeout(() => {
                        URL.revokeObjectURL((e.target as HTMLVideoElement).src);
                      }, 1000);
                    }}
                  />
                </div>
              )}

              <div className="file-actions">
                <button className="secondary-button" onClick={() => setSelectedFile(null)}>
                  Choose Different File
                </button>
                <button className="primary-button" onClick={handleSend}>
                  Send File
                </button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

export default FileUpload;
