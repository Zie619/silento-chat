import SwiftUI
import AVFoundation
import UIKit
import AVKit

struct ChatRoomView: View {
    @ObservedObject var chatService: ChatService
    let roomId: String
    let clientId: String
    let onLeave: () -> Void
    
    @State private var messageText = ""
    @State private var showRoomInfo = false
    @State private var showLeaveAlert = false
    @State private var showImagePicker = false
    @State private var showDocumentPicker = false
    @State private var showMediaOptions = false
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .camera
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isRecordingAudio = false
    @State private var isRecordingVideo = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioSession = AVAudioSession.sharedInstance()
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var currentlyPlayingAudioURL: String?
    @State private var audioPlayerDelegate: AudioPlayerDelegate?
    @State private var showVideoPlayer = false
    @State private var videoPlayerURL: URL?
    @FocusState private var isMessageFieldFocused: Bool
    @State private var uploadingMessages: Set<String> = []
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { showLeaveAlert = true }) {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: { showRoomInfo = true }) {
                    VStack(spacing: 4) {
                        HStack(spacing: 6) {
                            Text("Room \(roomId)")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            Circle()
                                .fill(chatService.isConnected ? .green : .red)
                                .frame(width: 8, height: 8)
                        }
                        
                        if chatService.peers.isEmpty {
                            Text("You're alone")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            Text("\(chatService.peers.count) other\(chatService.peers.count == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { showRoomInfo = true }) {
                    Image(systemName: "info.circle")
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.8))
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(chatService.messages) { message in
                            MessageBubbleView(
                                message: message,
                                isCurrentUser: message.isFromCurrentUser,
                                currentlyPlayingURL: $currentlyPlayingAudioURL,
                                onPlayAudio: playAudioMessage,
                                onStopAudio: stopAudioPlayback,
                                isUploading: uploadingMessages.contains(message.id),
                                showVideoPlayer: $showVideoPlayer,
                                videoPlayerURL: $videoPlayerURL
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .onChange(of: chatService.messages.count) { _ in
                    if let lastMessage = chatService.messages.last {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Message input
            ModernMessageInputView(
                messageText: $messageText,
                isMessageFieldFocused: $isMessageFieldFocused,
                onSend: sendMessage,
                onAttachmentTap: showAttachmentOptions,
                onCameraTap: {
                    // Always open camera directly for photos - ensure source type is set correctly
                    imagePickerSourceType = .camera
                    showImagePicker = true
                },
                onCameraLongPress: {
                    // Long press for video recording
                    startVideoRecording()
                },
                onVoiceTap: toggleAudioRecording,
                isRecording: isRecordingAudio
            )
        }
        .background(Color.black)
        .sheet(isPresented: $showRoomInfo) {
            RoomInfoView(
                roomId: roomId,
                peers: chatService.peers,
                isConnected: chatService.isConnected,
                connectionStatus: chatService.connectionStatus
            )
        }
        .actionSheet(isPresented: $showMediaOptions) {
            ActionSheet(
                title: Text("Attach Media"),
                buttons: [
                    .default(Text("📷 Photo Library")) {
                        imagePickerSourceType = .photoLibrary
                        showImagePicker = true
                    },
                    .default(Text("📄 Document")) {
                        showDocumentPicker = true
                    },
                    .cancel()
                ]
            )
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(
                sourceType: imagePickerSourceType,
                selectedImage: $selectedImage,
                selectedVideoURL: $selectedVideoURL,
                isPresented: $showImagePicker,
                allowsVideo: imagePickerSourceType == .camera // Allow video when using camera
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                isPresented: $showDocumentPicker,
                onDocumentSelected: handleDocumentSelection
            )
        }
        .sheet(isPresented: $showVideoPlayer) {
            if let videoURL = videoPlayerURL {
                VideoPlayerView(url: videoURL)
            }
        }
        .alert("Leave Room", isPresented: $showLeaveAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Leave", role: .destructive) {
                onLeave()
            }
        } message: {
            Text("Are you sure you want to leave this room? Your messages will be lost.")
        }
        .onChange(of: selectedImage) { image in
            if let image = image {
                handleImageSelection(image)
                selectedImage = nil
            }
        }
        .onChange(of: selectedVideoURL) { videoURL in
            if let videoURL = videoURL {
                handleVideoSelection(videoURL)
                selectedVideoURL = nil
            }
        }
        .onTapGesture {
            isMessageFieldFocused = false
        }
    }
    
    private func addSystemMessage(_ content: String) {
        // Create a system message that looks different from user messages
        let systemMessage = ChatMessage(
            id: UUID().uuidString,
            content: content,
            type: .text,
            isFromCurrentUser: false,
            timestamp: Date(),
            senderId: "system",
            status: .delivered
        )
        
        DispatchQueue.main.async {
            chatService.messages.append(systemMessage)
        }
    }
    
    private func sendMessage() {
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else { return }
        
        chatService.sendMessage(trimmedMessage)
        messageText = ""
        isMessageFieldFocused = false
    }
    
    private func toggleAudioRecording() {
        isRecordingAudio.toggle()
        
        if isRecordingAudio {
            startAudioRecording()
        } else {
            stopAudioRecording()
        }
    }
    
    private func startAudioRecording() {
        do {
            // Configure audio session for recording
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            // Request microphone permission
            audioSession.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.beginRecording()
                    } else {
                        print("❌ Microphone permission denied")
                    }
                }
            }
        } catch {
            print("❌ Failed to configure audio session: \(error)")
        }
    }
    
    private func beginRecording() {
        let audioURL = getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioURL, settings: settings)
            audioRecorder?.record()
            
            recordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                self.recordingDuration += 1
            }
            
            print("🎤 Audio recording started")
        } catch {
            print("❌ Failed to start recording: \(error)")
            isRecordingAudio = false
        }
    }
    
    private func stopAudioRecording() {
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        guard let audioRecorder = audioRecorder else { return }
        
        let audioURL = audioRecorder.url
        
        do {
            let audioData = try Data(contentsOf: audioURL)
            let fileName = "voice_\(Date().timeIntervalSince1970).m4a"
            
            // Create uploading placeholder message
            let uploadingMessageId = UUID().uuidString
            let uploadingMessage = ChatMessage(
                id: uploadingMessageId,
                content: "🎤 Uploading voice message...",
                type: .audio,
                isFromCurrentUser: true,
                timestamp: Date(),
                senderId: clientId,
                status: .sending
            )
            
            DispatchQueue.main.async {
                self.chatService.messages.append(uploadingMessage)
                self.uploadingMessages.insert(uploadingMessageId)
            }
            
            // Upload to server with correct mime type
            chatService.uploadFile(audioData, fileName: fileName, mimeType: "audio/m4a") { result in
                DispatchQueue.main.async {
                    // Remove uploading placeholder
                    self.uploadingMessages.remove(uploadingMessageId)
                    if let index = self.chatService.messages.firstIndex(where: { $0.id == uploadingMessageId }) {
                        self.chatService.messages.remove(at: index)
                    }
                    
                    switch result {
                    case .success(let fileURL):
                        print("✅ Voice message uploaded: \(fileURL)")
                        self.chatService.sendMediaMessage(fileURL: fileURL, fileName: fileName, mimeType: "audio/m4a")
                        
                    case .failure(let error):
                        print("❌ Failed to upload voice message: \(error)")
                        self.chatService.sendMessage("❌ Failed to upload voice message")
                    }
                }
            }
            
            // Clean up the local file
            try? FileManager.default.removeItem(at: audioURL)
            
        } catch {
            print("❌ Failed to read audio file: \(error)")
            chatService.sendMessage("❌ Failed to process voice message")
        }
    }
    
    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    private func handleImageSelection(_ image: UIImage) {
        print("📸 Image selected: \(image.size)")
        
        // Convert UIImage to JPEG data
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("❌ Failed to convert image to data")
            return
        }
        
        let fileName = "image_\(Date().timeIntervalSince1970).jpg"
        
        // Create uploading placeholder message with loading indicator
        let uploadingMessageId = UUID().uuidString
        let uploadingMessage = ChatMessage(
            id: uploadingMessageId,
            content: "📸 Uploading image...",
            type: .text,
            isFromCurrentUser: true,
            timestamp: Date(),
            senderId: clientId,
            status: .sending
        )
        
        DispatchQueue.main.async {
            self.chatService.messages.append(uploadingMessage)
            self.uploadingMessages.insert(uploadingMessageId)
        }
        
        // Upload file to server
        chatService.uploadFile(imageData, fileName: fileName, mimeType: "image/jpeg") { result in
            DispatchQueue.main.async {
                // Remove uploading placeholder
                self.uploadingMessages.remove(uploadingMessageId)
                if let index = self.chatService.messages.firstIndex(where: { $0.id == uploadingMessageId }) {
                    self.chatService.messages.remove(at: index)
                }
                
                switch result {
                case .success(let fileURL):
                    print("✅ Image uploaded successfully: \(fileURL)")
                    // Send actual media message
                    self.chatService.sendMediaMessage(fileURL: fileURL, fileName: fileName, mimeType: "image/jpeg")
                    
                case .failure(let error):
                    print("❌ Failed to upload image: \(error)")
                    // Send error message
                    self.chatService.sendMessage("❌ Failed to upload image: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func handleDocumentSelection(_ url: URL) {
        print("📄 Document selected: \(url.lastPathComponent)")
        
        do {
            let documentData = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            let mimeType = "application/octet-stream" // Generic mime type for documents
            
            // Create uploading placeholder message with loading indicator
            let uploadingMessageId = UUID().uuidString
            let uploadingMessage = ChatMessage(
                id: uploadingMessageId,
                content: "📄 Uploading \(fileName)...",
                type: .text,
                isFromCurrentUser: true,
                timestamp: Date(),
                senderId: clientId,
                status: .sending
            )
            
            DispatchQueue.main.async {
                self.chatService.messages.append(uploadingMessage)
                self.uploadingMessages.insert(uploadingMessageId)
            }
            
            // Upload file to server
            chatService.uploadFile(documentData, fileName: fileName, mimeType: mimeType) { result in
                DispatchQueue.main.async {
                    // Remove uploading placeholder
                    self.uploadingMessages.remove(uploadingMessageId)
                    if let index = self.chatService.messages.firstIndex(where: { $0.id == uploadingMessageId }) {
                        self.chatService.messages.remove(at: index)
                    }
                    
                    switch result {
                    case .success(let fileURL):
                        print("✅ Document uploaded successfully: \(fileURL)")
                        // Send actual media message
                        self.chatService.sendMediaMessage(fileURL: fileURL, fileName: fileName, mimeType: mimeType)
                        
                    case .failure(let error):
                        print("❌ Failed to upload document: \(error)")
                        // Send error message
                        self.chatService.sendMessage("❌ Failed to upload document: \(error.localizedDescription)")
                    }
                }
            }
        } catch {
            print("❌ Failed to read document: \(error)")
            chatService.sendMessage("❌ Failed to read document: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Video Recording
    
    private func startVideoRecording() {
        print("🎥 Starting video recording...")
        // Open camera with video mode enabled
        imagePickerSourceType = .camera
        showImagePicker = true
        isRecordingVideo = false
    }
    
    // MARK: - Audio Playback
    
    private func playAudioMessage(_ url: String) {
        // Stop current audio if playing
        audioPlayer?.stop()
        
        guard let audioURL = URL(string: url) else {
            print("❌ Invalid audio URL: \(url)")
            return
        }
        
        print("🎵 Playing audio: \(url)")
        currentlyPlayingAudioURL = url
        
        // Download and play audio
        URLSession.shared.dataTask(with: audioURL) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Failed to download audio: \(error?.localizedDescription ?? "Unknown error")")
                DispatchQueue.main.async {
                    self.currentlyPlayingAudioURL = nil
                }
                return
            }
            
            DispatchQueue.main.async {
                do {
                    // Configure audio session for playback
                    try self.audioSession.setCategory(.playback, mode: .default)
                    try self.audioSession.setActive(true)
                    
                    self.audioPlayer = try AVAudioPlayer(data: data)
                    
                    // Create and store delegate with strong reference
                    self.audioPlayerDelegate = AudioPlayerDelegate {
                        DispatchQueue.main.async {
                            self.currentlyPlayingAudioURL = nil
                        }
                    }
                    self.audioPlayer?.delegate = self.audioPlayerDelegate
                    
                    self.audioPlayer?.play()
                    print("✅ Audio playback started")
                    
                } catch {
                    print("❌ Failed to play audio: \(error)")
                    self.currentlyPlayingAudioURL = nil
                }
            }
        }.resume()
    }
    
    private func stopAudioPlayback() {
        audioPlayer?.stop()
        currentlyPlayingAudioURL = nil
    }
    
    private func showAttachmentOptions() {
        showMediaOptions = true
    }
    
    private func handleVideoSelection(_ videoURL: URL) {
        print("🎥 Video selected: \(videoURL.lastPathComponent)")
        
        do {
            let videoData = try Data(contentsOf: videoURL)
            let fileName = "video_\(Date().timeIntervalSince1970).mp4"
            
            // Create uploading placeholder message with loading indicator
            let uploadingMessageId = UUID().uuidString
            let uploadingMessage = ChatMessage(
                id: uploadingMessageId,
                content: "🎥 Uploading video...",
                type: .video,
                isFromCurrentUser: true,
                timestamp: Date(),
                senderId: clientId,
                status: .sending
            )
            
            DispatchQueue.main.async {
                self.chatService.messages.append(uploadingMessage)
                self.uploadingMessages.insert(uploadingMessageId)
            }
            
            // Upload file to server
            chatService.uploadFile(videoData, fileName: fileName, mimeType: "video/mp4") { result in
                DispatchQueue.main.async {
                    // Remove uploading placeholder
                    self.uploadingMessages.remove(uploadingMessageId)
                    if let index = self.chatService.messages.firstIndex(where: { $0.id == uploadingMessageId }) {
                        self.chatService.messages.remove(at: index)
                    }
                    
                    switch result {
                    case .success(let fileURL):
                        print("✅ Video uploaded successfully: \(fileURL)")
                        // Send actual media message
                        self.chatService.sendMediaMessage(fileURL: fileURL, fileName: fileName, mimeType: "video/mp4")
                        
                    case .failure(let error):
                        print("❌ Failed to upload video: \(error)")
                        // Send error message
                        self.chatService.sendMessage("❌ Failed to upload video: \(error.localizedDescription)")
                    }
                }
            }
            
        } catch {
            print("❌ Failed to read video file: \(error)")
            chatService.sendMessage("❌ Failed to read video file: \(error.localizedDescription)")
        }
    }
}

struct ChatHeaderView: View {
    let roomId: String
    let peerCount: Int
    let isConnected: Bool
    let onInfoTap: () -> Void
    let onLeaveTap: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Back/Leave button
            Button(action: onLeaveTap) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            
            // Room avatar
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
                .overlay(
                    Text("R")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )
            
            // Room info
            VStack(alignment: .leading, spacing: 2) {
                Text("Room \(String(roomId.prefix(8)))")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.red)
                        .frame(width: 8, height: 8)
                    
                    Text(isConnected ? "\(peerCount + 1) online" : "Disconnected")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            Spacer()
            
            // Info button
            Button(action: onInfoTap) {
                Image(systemName: "info.circle")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Color.black.opacity(0.9)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .bottom
                )
        )
    }
}

struct MessageBubbleView: View {
    let message: ChatMessage
    let isCurrentUser: Bool
    @Binding var currentlyPlayingURL: String?
    let onPlayAudio: (String) -> Void
    let onStopAudio: () -> Void
    let isUploading: Bool
    @Binding var showVideoPlayer: Bool
    @Binding var videoPlayerURL: URL?
    
    var body: some View {
        HStack {
            if isCurrentUser {
                Spacer(minLength: 60)
                outgoingMessage
            } else {
                // Show system messages differently
                if message.senderId == "system" {
                    systemMessage
                } else {
                    incomingMessage
                    Spacer(minLength: 60)
                }
            }
        }
    }
    
    private var systemMessage: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
            Spacer()
        }
    }
    
    private var outgoingMessage: some View {
        VStack(alignment: .trailing, spacing: 4) {
            messageContent
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.2, green: 0.6, blue: 1.0),
                                    Color(red: 0.1, green: 0.5, blue: 0.9)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
            
            messageFooter
        }
    }
    
    private var incomingMessage: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Sender name for group chats
            if !isCurrentUser {
                Text("Anonymous")
                    .font(.caption)
                    .foregroundColor(.blue.opacity(0.8))
                    .padding(.leading, 16)
            }
            
            messageContent
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.12))
                )
            
            messageFooter
        }
    }
    
    private var messageContent: some View {
        Group {
            switch message.type {
            case .text:
                HStack(spacing: 8) {
                    if isUploading {
                        RotatingLoader()
                    }
                    
                    Text(message.content)
                        .font(.body)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                    
            case .image:
                VStack(alignment: .leading, spacing: 8) {
                    if let mediaURL = message.mediaURL, let url = URL(string: mediaURL) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 200, height: 150)
                                .overlay(
                                    VStack {
                                        RotatingLoader()
                                        Text("Loading...")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                )
                        }
                        .frame(maxWidth: 250, maxHeight: 200)
                    } else {
                        // Fallback for messages without media URL
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 150)
                            .overlay(
                                VStack {
                                    if isUploading {
                                        RotatingLoader()
                                    } else {
                                        Image(systemName: "photo")
                                            .font(.largeTitle)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Text(isUploading ? "Uploading..." : "Image")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            )
                    }
                    
                    if !message.content.isEmpty && !message.content.contains("Uploading") {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                
            case .video:
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 250, height: 140)
                        .overlay(
                            Group {
                                if isUploading {
                                    VStack {
                                        RotatingLoader()
                                        Text("Uploading...")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                } else {
                                    Button(action: {
                                        if let mediaURL = message.mediaURL, let url = URL(string: mediaURL) {
                                            // Set the video URL and show player
                                            videoPlayerURL = url
                                            showVideoPlayer = true
                                        }
                                    }) {
                                        VStack {
                                            Image(systemName: "play.circle.fill")
                                                .font(.largeTitle)
                                                .foregroundColor(.white)
                                            Text("Play Video")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                            }
                        )
                    
                    if !message.content.isEmpty && !message.content.contains("Uploading") {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                
            case .audio:
                HStack(spacing: 12) {
                    Button(action: {
                        if let mediaURL = message.mediaURL {
                            onPlayAudio(mediaURL)
                        }
                    }) {
                        if isUploading {
                            RotatingLoader()
                                .frame(width: 24, height: 24)
                        } else {
                            Image(systemName: currentlyPlayingURL == message.mediaURL ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                    }
                    .disabled(isUploading)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.fileName ?? "Voice Message")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        
                        // Show audio duration or upload status
                        if isUploading {
                            Text("Uploading...")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.6))
                        } else if message.content.contains("Failed") {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                                Text("Upload failed")
                                    .font(.caption2)
                                    .foregroundColor(.red)
                            }
                        } else {
                            // Audio waveform visualization
                            HStack(spacing: 2) {
                                ForEach(0..<12, id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 1)
                                        .fill(currentlyPlayingURL == message.mediaURL ? Color.blue : Color.white.opacity(0.6))
                                        .frame(width: 2, height: CGFloat.random(in: 6...16))
                                        .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.1), value: currentlyPlayingURL)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
            case .file:
                HStack(spacing: 12) {
                    if isUploading {
                        RotatingLoader()
                            .frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "doc.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.fileName ?? "Document")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        if isUploading {
                            Text("Uploading...")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        } else if let fileSize = message.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    if !isUploading {
                        Button(action: {
                            // TODO: Download/open file
                        }) {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                                .foregroundColor(.white)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
    }
    
    private var messageFooter: some View {
        HStack(spacing: 4) {
            Text(formatTime(message.timestamp))
                .font(.caption2)
                .foregroundColor(.white.opacity(0.6))
            
            if isCurrentUser {
                messageStatusIcon
            }
        }
        .padding(.horizontal, isCurrentUser ? 8 : 16)
    }
    
    private var messageStatusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                RotatingLoader()
                    .frame(width: 12, height: 12)
            case .sent:
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            case .delivered:
                Image(systemName: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            case .failed:
                Image(systemName: "exclamationmark.circle")
                    .font(.caption2)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

struct ModernMessageInputView: View {
    @Binding var messageText: String
    var isMessageFieldFocused: FocusState<Bool>.Binding
    let onSend: () -> Void
    let onAttachmentTap: () -> Void
    let onCameraTap: () -> Void
    let onCameraLongPress: () -> Void
    let onVoiceTap: () -> Void
    let isRecording: Bool
    
    private var hasText: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Attachment button
            if !hasText {
                Button(action: onAttachmentTap) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(Color.white.opacity(0.1)))
                }
                .transition(.scale.combined(with: .opacity))
            }
            
            // Text input container
            HStack(spacing: 8) {
                // Text field
                TextField("Message", text: $messageText)
                    .focused(isMessageFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.body)
                    .foregroundColor(.white)
                    .submitLabel(.send)
                    .onSubmit {
                        if hasText {
                            onSend()
                        }
                    }
                
                // Camera button with long press for video
                if !hasText {
                    Button(action: {
                        // Short tap - take photo with camera
                        onCameraTap()
                    }) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    .onLongPressGesture(minimumDuration: 0.5) {
                        // Long press - record video
                        onCameraLongPress()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.white.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            )
            
            // Send/Voice button
            Button(action: hasText ? onSend : onVoiceTap) {
                Image(systemName: hasText ? "paperplane.fill" : (isRecording ? "stop.circle.fill" : "mic.fill"))
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(
                                hasText || isRecording ? 
                                LinearGradient(
                                    colors: [.blue, .blue.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isRecording)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            Color.black.opacity(0.9)
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 0.5),
                    alignment: .top
                )
        )
    }
}

// Simple RoomInfoView for debugging
struct RoomInfoView: View {
    let roomId: String
    let peers: [String]
    let isConnected: Bool
    let connectionStatus: ChatService.ConnectionStatus
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Room Information")
                    .font(.title)
                    .fontWeight(.bold)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Room ID:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(roomId)
                            .foregroundColor(.blue)
                    }
                    
                    HStack {
                        Text("Status:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(isConnected ? .green : .red)
                    }
                    
                    HStack {
                        Text("Peers:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text("\(peers.count)")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                
                Spacer()
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Image Picker

struct ImagePickerView: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    @Binding var isPresented: Bool
    let allowsVideo: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
        
        // Configure media types based on source and allowsVideo
        if sourceType == .camera && allowsVideo {
            picker.mediaTypes = ["public.image", "public.movie"]
            picker.videoMaximumDuration = 60.0 // 60 seconds max
            picker.videoQuality = .typeMedium
        } else {
            picker.mediaTypes = ["public.image"]
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView
        
        init(_ parent: ImagePickerView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            
            // Handle video
            if let videoURL = info[.mediaURL] as? URL {
                parent.selectedVideoURL = videoURL
            }
            // Handle image
            else if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            
            parent.isPresented = false
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onDocumentSelected: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onDocumentSelected(url)
            }
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Audio Player Delegate

class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: () -> Void
    
    init(onFinish: @escaping () -> Void) {
        self.onFinish = onFinish
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        onFinish()
    }
}

// MARK: - Rotating Loader Component

struct RotatingLoader: View {
    @State private var isRotating = false
    
    var body: some View {
        Circle()
            .trim(from: 0, to: 0.7)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [.blue, .blue.opacity(0.3)]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
            .rotationEffect(.degrees(isRotating ? 360 : 0))
            .animation(
                Animation.linear(duration: 1)
                    .repeatForever(autoreverses: false),
                value: isRotating
            )
            .onAppear {
                isRotating = true
            }
    }
}

// MARK: - Video Player View

struct VideoPlayerView: View {
    let url: URL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VideoPlayer(player: AVPlayer(url: url))
                .navigationTitle("Video")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    ChatRoomView(
        chatService: ChatService(),
        roomId: "test-room-123",
        clientId: "client-123",
        onLeave: {}
    )
} 