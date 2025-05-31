import SwiftUI

struct CreateRoomView: View {
    @ObservedObject var chatService: ChatService
    let onRoomCreated: (String) -> Void
    let onBack: () -> Void
    
    @State private var errorMessage: String?
    @State private var showError = false
    
    private var isCreatingRoom: Bool {
        chatService.isCreatingRoom || chatService.connectionStatus == .roomCreating || chatService.connectionStatus == .connecting
    }
    
    private var statusText: String {
        switch chatService.connectionStatus {
        case .roomCreating:
            return "Creating Room..."
        case .connecting:
            return "Connecting..."
        case .connected:
            return "Connected!"
        case .failed:
            return "Connection Failed"
        default:
            return isCreatingRoom ? "Creating Room..." : "Create Room"
        }
    }
    
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 16) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    .disabled(isCreatingRoom)
                    Spacer()
                }
                .padding(.horizontal, 20)
                
                Text("Create Room")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            // Main content
            VStack(spacing: 32) {
                // Icon with status indicator
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue.opacity(0.3), .cyan.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        if isCreatingRoom {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                        }
                    }
                    
                    VStack(spacing: 8) {
                        Text(isCreatingRoom ? "Setting Up Your Room" : "Start New Conversation")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        if isCreatingRoom {
                            Text("Establishing secure connection...")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        } else {
                            Text("Create a secure room for anonymous messaging")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        
                        // Connection status
                        if isCreatingRoom {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .opacity(0.7)
                                    .scaleEffect(chatService.connectionStatus == .connecting ? 1.2 : 1.0)
                                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: chatService.connectionStatus)
                                
                                Text(chatService.connectionStatus.rawValue)
                                    .font(.caption)
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                
                // Features
                if !isCreatingRoom {
                    VStack(spacing: 16) {
                        FeatureRow(icon: "🔒", title: "End-to-End Encryption", description: "Your messages are completely secure")
                        FeatureRow(icon: "👥", title: "Multi-User Support", description: "Share the room ID with others")
                        FeatureRow(icon: "🗑️", title: "Auto-Delete", description: "Messages disappear automatically")
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale))
                } else {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: "shield.checkered")
                                .foregroundColor(.green)
                            Text("Encryption: AES-256 Enabled")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "server.rack")
                                .foregroundColor(.blue)
                            Text("Server: Railway Production")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Image(systemName: "network")
                                .foregroundColor(.orange)
                            Text("Protocol: WebSocket Secure (WSS)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        
                        if chatService.connectionStatus == .connecting {
                            HStack(spacing: 12) {
                                Image(systemName: "wifi")
                                    .foregroundColor(.cyan)
                                Text("Establishing connection...")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.opacity.combined(with: .scale))
                }
            }
            
            Spacer()
            
            // Create button
            VStack(spacing: 16) {
                Button(action: createRoom) {
                    HStack {
                        if isCreatingRoom {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                        }
                        
                        Text(statusText)
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(isCreatingRoom ? .gray : .blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: isCreatingRoom ? .gray.opacity(0.3) : .blue.opacity(0.3), radius: 10, x: 0, y: 4)
                    )
                }
                .disabled(isCreatingRoom)
                .padding(.horizontal, 20)
                
                // Error message
                if showError, let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.bottom, 40)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: chatService.connectionStatus) { status in
            if status == .connected {
                // Small delay to show connected state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let roomId = chatService.currentRoomId {
                        onRoomCreated(roomId)
                    }
                }
            }
        }
    }
    
    private func createRoom() {
        errorMessage = nil
        
        chatService.createRoom { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let roomId):
                    onRoomCreated(roomId)
                case .failure(let error):
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Text(icon)
                .font(.title2)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

#Preview {
    CreateRoomView(
        chatService: ChatService(),
        onRoomCreated: { _ in },
        onBack: {}
    )
    .background(Color.black)
} 