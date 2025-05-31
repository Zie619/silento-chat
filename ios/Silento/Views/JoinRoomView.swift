import SwiftUI

struct JoinRoomView: View {
    @ObservedObject var chatService: ChatService
    let onRoomJoined: (String) -> Void
    let onBack: () -> Void
    
    @State private var roomId = ""
    @State private var isJoiningRoom = false
    @State private var errorMessage: String?
    @State private var showError = false
    @FocusState private var isTextFieldFocused: Bool
    
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
                
                Text("Join Room")
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
                                    colors: [.green.opacity(0.3), .blue.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    
                    VStack(spacing: 8) {
                        Text("Join Existing Room")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        Text("Enter the room ID shared with you")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                // Room ID input
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Room ID")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        TextField("Enter room ID", text: $roomId)
                            .focused($isTextFieldFocused)
                            .textFieldStyle(CustomTextFieldStyle())
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.join)
                            .onSubmit {
                                if !roomId.isEmpty {
                                    joinRoom()
                                }
                            }
                    }
                    
                    // Helper text
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundColor(.blue.opacity(0.7))
                        
                        Text("Ask the room creator to share their room ID with you")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Join button
            VStack(spacing: 16) {
                Button(action: joinRoom) {
                    HStack {
                        if isJoiningRoom {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title3)
                        }
                        
                        Text(isJoiningRoom ? "Joining Room..." : "Join Room")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(roomId.isEmpty ? Color.gray.opacity(0.3) : Color.white)
                            .shadow(
                                color: roomId.isEmpty ? .clear : .blue.opacity(0.3),
                                radius: roomId.isEmpty ? 0 : 10,
                                x: 0,
                                y: roomId.isEmpty ? 0 : 4
                            )
                    )
                }
                .disabled(isJoiningRoom || roomId.isEmpty)
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
        .onTapGesture {
            isTextFieldFocused = false
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func joinRoom() {
        guard !roomId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isJoiningRoom = true
        errorMessage = nil
        isTextFieldFocused = false
        
        let trimmedRoomId = roomId.trimmingCharacters(in: .whitespacesAndNewlines)
        
        chatService.joinRoom(trimmedRoomId) { result in
            DispatchQueue.main.async {
                isJoiningRoom = false
                
                switch result {
                case .success(let success):
                    if success {
                        onRoomJoined(trimmedRoomId)
                    } else {
                        errorMessage = "Failed to join room. Please check the Room ID."
                        showError = true
                    }
                case .failure(let error):
                    if error.localizedDescription.contains("Room not found") {
                        errorMessage = "Room not found. Please check the room ID and try again."
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    showError = true
                }
            }
        }
    }
}

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
            )
            .foregroundColor(.white)
            .font(.body)
    }
}

#Preview {
    JoinRoomView(
        chatService: ChatService(),
        onRoomJoined: { _ in },
        onBack: {}
    )
    .background(Color.black)
} 