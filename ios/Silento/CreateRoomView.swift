import SwiftUI

struct CreateRoomView: View {
    @ObservedObject var chatService: ChatService
    let onRoomCreated: (String) -> Void
    let onBack: () -> Void
    
    @State private var isCreatingRoom = false
    @State private var errorMessage: String?
    @State private var showError = false
    
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
                // Icon
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
                        
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Start New Conversation")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Create a secure room for anonymous messaging")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Features
                VStack(spacing: 16) {
                    FeatureRow(icon: "🔒", title: "End-to-End Encryption", description: "Your messages are completely secure")
                    FeatureRow(icon: "👥", title: "Multi-User Support", description: "Share the room ID with others")
                    FeatureRow(icon: "🗑️", title: "Auto-Delete", description: "Messages disappear automatically")
                }
                .padding(.horizontal, 20)
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
                        
                        Text(isCreatingRoom ? "Creating Room..." : "Create Room")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white)
                            .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 4)
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
    }
    
    private func createRoom() {
        isCreatingRoom = true
        errorMessage = nil
        
        chatService.createRoom { result in
            DispatchQueue.main.async {
                isCreatingRoom = false
                
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