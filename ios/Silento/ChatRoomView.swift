import SwiftUI
import AVFoundation
import UIKit

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
    @State private var imagePickerSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var isRecordingAudio = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioSession = AVAudioSession.sharedInstance()
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @FocusState private var isMessageFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            ChatHeaderView(
                roomId: roomId,
                peerCount: chatService.peers.count,
                isConnected: chatService.isConnected,
                onInfoTap: {
                    showRoomInfo = true
                },
                onLeaveTap: {
                    showLeaveAlert = true
                }
            )
            
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(chatService.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.1, green: 0.1, blue: 0.15),
                            Color(red: 0.05, green: 0.05, blue: 0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .onChange(of: chatService.messages.count) { _ in
                    // Auto-scroll to latest message
                    if let lastMessage = chatService.messages.last {
                        withAnimation(.easeOut(duration: 0.3)) {
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
                onAttachmentTap: {
                    showMediaOptions = true
                },
                onCameraTap: {
                    imagePickerSourceType = .camera
                    showImagePicker = true
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
        .confirmationDialog("Choose Media", isPresented: $showMediaOptions, titleVisibility: .visible) {
            Button("Photo Library") {
                imagePickerSourceType = .photoLibrary
                showImagePicker = true
            }
            
            Button("Camera") {
                imagePickerSourceType = .camera
                showImagePicker = true
            }
            
            Button("Document") {
                showDocumentPicker = true
            }
            
            Button("Cancel", role: .cancel) { }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePickerView(
                sourceType: imagePickerSourceType,
                selectedImage: $selectedImage,
                isPresented: $showImagePicker
            )
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView(
                isPresented: $showDocumentPicker,
                onDocumentSelected: handleDocumentSelection
            )
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
        .onTapGesture {
            isMessageFieldFocused = false
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
        print("🎤 Starting audio recording...")
        
        do {
            // Configure audio session
            try audioSession.setCategory(.record, mode: .default)
            try audioSession.setActive(true)
            
            // Check microphone permission
            audioSession.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        self.beginRecording()
                    } else {
                        print("❌ Microphone permission denied")
                        self.isRecordingAudio = false
                    }
                }
            }
        } catch {
            print("❌ Failed to setup audio session: \(error)")
            isRecordingAudio = false
        }
    }
    
    private func beginRecording() {
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            
            // Start timer for recording duration
            recordingDuration = 0
            recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                recordingDuration += 0.1
            }
            
            print("🎤 Recording started...")
        } catch {
            print("❌ Could not start recording: \(error)")
            isRecordingAudio = false
        }
    }
    
    private func stopAudioRecording() {
        print("🎤 Stopping audio recording...")
        
        audioRecorder?.stop()
        recordingTimer?.invalidate()
        recordingTimer = nil
        
        do {
            try audioSession.setActive(false)
        } catch {
            print("❌ Error deactivating audio session: \(error)")
        }
        
        // Handle the recorded audio file
        if let audioURL = audioRecorder?.url {
            handleAudioRecording(audioURL)
        } else {
            print("❌ No audio file recorded")
        }
    }
    
    private func handleAudioRecording(_ audioURL: URL) {
        do {
            let audioData = try Data(contentsOf: audioURL)
            let fileName = "audio_\(Date().timeIntervalSince1970).m4a"
            let durationText = String(format: "%.1f", recordingDuration)
            
            // Show uploading message
            let uploadingMessage = "🎤 Uploading voice message (\(durationText)s)..."
            chatService.sendMessage(uploadingMessage)
            
            // Upload audio file
            chatService.uploadFile(audioData, fileName: fileName, mimeType: "audio/m4a") { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fileURL):
                        print("✅ Audio uploaded successfully: \(fileURL)")
                        // Send audio message
                        self.chatService.sendMediaMessage(fileURL: fileURL, fileName: fileName, mimeType: "audio/m4a")
                        
                    case .failure(let error):
                        print("❌ Failed to upload audio: \(error)")
                        self.chatService.sendMessage("❌ Failed to upload voice message: \(error.localizedDescription)")
                    }
                }
            }
            
            // Clean up the temporary file
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
        
        // Show uploading message
        let uploadingMessage = "📸 Uploading image..."
        chatService.sendMessage(uploadingMessage)
        
        // Upload file to server
        chatService.uploadFile(imageData, fileName: fileName, mimeType: "image/jpeg") { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let fileURL):
                    print("✅ Image uploaded successfully: \(fileURL)")
                    // Send media message with actual file URL
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
            
            // Show uploading message
            let uploadingMessage = "📄 Uploading document..."
            chatService.sendMessage(uploadingMessage)
            
            // Upload file to server
            chatService.uploadFile(documentData, fileName: fileName, mimeType: mimeType) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let fileURL):
                        print("✅ Document uploaded successfully: \(fileURL)")
                        // Send media message with actual file URL
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
    
    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
                outgoingMessage
            } else {
                incomingMessage
                Spacer(minLength: 60)
            }
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
            if !message.isFromCurrentUser {
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
                Text(message.content)
                    .font(.body)
                    .foregroundColor(.white)
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
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
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
                                    Image(systemName: "photo")
                                        .font(.largeTitle)
                                        .foregroundColor(.white.opacity(0.7))
                                    Text("Image")
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
                            Button(action: {
                                // TODO: Play video
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                            }
                        )
                    
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.body)
                            .foregroundColor(.white)
                    }
                }
                .padding(12)
                
            case .audio:
                HStack(spacing: 12) {
                    Button(action: {
                        // TODO: Play audio
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        if !message.content.isEmpty {
                            Text(message.content)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        // Audio waveform placeholder
                        HStack(spacing: 2) {
                            ForEach(0..<20, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 3, height: CGFloat.random(in: 8...24))
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
            case .file:
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.fileName ?? "Document")
                            .font(.body)
                            .foregroundColor(.white)
                        
                        if let fileSize = message.fileSize {
                            Text(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        // TODO: Download/open file
                    }) {
                        Image(systemName: "arrow.down.circle")
                            .font(.title3)
                            .foregroundColor(.white)
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
            
            if message.isFromCurrentUser {
                messageStatusIcon
            }
        }
        .padding(.horizontal, message.isFromCurrentUser ? 8 : 16)
    }
    
    private var messageStatusIcon: some View {
        Group {
            switch message.status {
            case .sending:
                Image(systemName: "clock")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
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
                
                // Camera button (when no text)
                if !hasText {
                    Button(action: onCameraTap) {
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
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
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true
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
            if let editedImage = info[.editedImage] as? UIImage {
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

#Preview {
    ChatRoomView(
        chatService: ChatService(),
        roomId: "test-room-123",
        clientId: "client-123",
        onLeave: {}
    )
} 