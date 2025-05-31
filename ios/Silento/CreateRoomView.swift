import SwiftUI

struct CreateRoomView: View {
    @ObservedObject var chatService: ChatService
    let onRoomCreated: (String) -> Void
    let onBack: () -> Void
    
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isLoading = false
    @State private var createdRoomId: String?
    @State private var showChatRoom = false
    
    private var isCreatingRoom: Bool {
        chatService.isCreatingRoom || chatService.connectionStatus == .roomCreating || chatService.connectionStatus == .connecting
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            ScrollView {
                VStack(spacing: 40) {
                    // Main header
                    VStack(spacing: 20) {
                        // App icon
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)
                            .overlay(
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            )
                            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
                        
                        VStack(spacing: 8) {
                            Text("Create New Room")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("Start a private, encrypted conversation")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                    }
                    
                    // Features
                    VStack(spacing: 20) {
                        FeatureRow(
                            icon: "🔒",
                            title: "End-to-End Encrypted",
                            description: "Your messages are secured with AES-256 encryption"
                        )
                        
                        FeatureRow(
                            icon: "👤",
                            title: "Anonymous Chat",
                            description: "No registration required, completely anonymous"
                        )
                        
                        FeatureRow(
                            icon: "🚀",
                            title: "Instant Connection",
                            description: "Share your room ID and start chatting immediately"
                        )
                        
                        FeatureRow(
                            icon: "📱",
                            title: "Media Support",
                            description: "Send photos, voice messages, and documents"
                        )
                    }
                    .padding(.horizontal, 20)
                    
                    // Connection status or create button
                    VStack(spacing: 20) {
                        if isLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                    .scaleEffect(1.5)
                                
                                VStack(spacing: 8) {
                                    Text(chatService.connectionStatus.rawValue.capitalized)
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    Text(statusDescription)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .padding(24)
                            .background(
                                RoundedRectangle(cornerRadius: 20)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        } else {
                            Button(action: createRoom) {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title2)
                                    Text("Create Room")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .blue.opacity(0.8)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)
                            }
                            .disabled(isCreatingRoom)
                            
                            // Server info
                            if let serverURL = chatService.serverURL {
                                VStack(spacing: 8) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                        
                                        Text("Connected to: \(URL(string: serverURL)?.host ?? "Server")")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Text("Your room will be hosted securely")
                                        .font(.caption2)
                                        .foregroundColor(.white.opacity(0.5))
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.15),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
        .fullScreenCover(isPresented: $showChatRoom) {
            if let roomId = createdRoomId {
                ChatRoomView(
                    chatService: chatService,
                    roomId: roomId,
                    clientId: chatService.clientId,
                    onLeave: {
                        showChatRoom = false
                        createdRoomId = nil
                        chatService.leaveRoom()
                    }
                )
            }
        }
    }
    
    private var statusDescription: String {
        switch chatService.connectionStatus {
        case .roomCreating:
            return "Setting up your private room..."
        case .connecting:
            return "Establishing secure connection..."
        case .connected:
            return "Connected! Preparing to enter room..."
        case .failed:
            return "Connection failed"
        default:
            return "Please wait..."
        }
    }
    
    private func createRoom() {
        isLoading = true
        errorMessage = nil
        
        chatService.createRoom { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let roomId):
                    print("✅ Room created: \(roomId)")
                    self.createdRoomId = roomId
                    
                    // Wait for connection to be fully established before navigating
                    self.waitForConnection()
                    
                case .failure(let error):
                    print("❌ Failed to create room: \(error)")
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func waitForConnection() {
        print("🔄 Starting connection wait loop...")
        
        // Create a more reliable connection monitoring system
        var attempts = 0
        let maxAttempts = 20 // 10 seconds total
        
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            attempts += 1
            
            DispatchQueue.main.async {
                print("🔍 Connection check \(attempts): isConnected=\(self.chatService.isConnected), status=\(self.chatService.connectionStatus)")
                
                // Check if we're fully connected
                if self.chatService.isConnected && self.chatService.connectionStatus == .connected {
                    // Connection fully established
                    print("✅ Connection confirmed - navigating to chat room")
                    timer.invalidate()
                    self.isLoading = false
                    self.showChatRoom = true
                    return
                }
                
                // Check for failure states
                if self.chatService.connectionStatus == .failed {
                    print("❌ Connection failed - stopping wait")
                    timer.invalidate()
                    self.isLoading = false
                    self.errorMessage = "Failed to connect to the room"
                    return
                }
                
                // Check for timeout
                if attempts >= maxAttempts {
                    print("⏰ Connection timeout - forcing navigation")
                    timer.invalidate()
                    
                    // If we have a room ID and the basic connection seems established, try to navigate anyway
                    if self.createdRoomId != nil && self.chatService.currentRoomId != nil {
                        print("🚀 Forcing navigation with available room ID")
                        self.isLoading = false
                        self.showChatRoom = true
                    } else {
                        self.isLoading = false
                        self.errorMessage = "Connection timed out. Please try again."
                    }
                    return
                }
                
                // Continue waiting...
                print("⏳ Still waiting for connection... (attempt \(attempts)/\(maxAttempts))")
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
                .frame(width: 40, height: 40)
                .background(
                    Circle()
                        .fill(Color.white.opacity(0.1))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
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