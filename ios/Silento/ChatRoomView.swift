import SwiftUI
import AVFoundation

struct ChatRoomView: View {
    @ObservedObject var chatService: ChatService
    let roomId: String
    let clientId: String
    let onLeave: () -> Void
    
    @State private var messageText = ""
    @State private var showRoomInfo = false
    @State private var showLeaveAlert = false
    @State private var showMediaPicker = false
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var isRecordingAudio = false
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
                    showMediaPicker = true
                },
                onCameraTap: {
                    showCamera = true
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
        .actionSheet(isPresented: $showMediaPicker) {
            ActionSheet(
                title: Text("Choose Media"),
                buttons: [
                    .default(Text("Photo Library")) {
                        // Will implement photo picker
                    },
                    .default(Text("Camera")) {
                        showCamera = true
                    },
                    .default(Text("Document")) {
                        showDocumentPicker = true
                    },
                    .cancel()
                ]
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
        // TODO: Implement audio recording
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
                    AsyncImage(url: URL(string: message.mediaURL ?? "")) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 200, height: 150)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    .frame(maxWidth: 250, maxHeight: 200)
                    
                    if !message.content.isEmpty {
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

#Preview {
    ChatRoomView(
        chatService: ChatService(),
        roomId: "test-room-123",
        clientId: "client-123",
        onLeave: {}
    )
} 