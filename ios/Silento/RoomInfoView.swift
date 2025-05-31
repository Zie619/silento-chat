import SwiftUI

struct RoomInfoView: View {
    let roomId: String
    let peers: [String]
    let isConnected: Bool
    let connectionStatus: ChatService.ConnectionStatus
    
    @Environment(\.dismiss) private var dismiss
    @State private var showCopiedAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Connection status
                ConnectionStatusCard(
                    isConnected: isConnected,
                    connectionStatus: connectionStatus
                )
                
                // Room ID sharing
                RoomIDCard(
                    roomId: roomId,
                    onCopy: {
                        copyRoomId()
                    }
                )
                
                // Peers list
                PeersCard(peers: peers)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black,
                        Color.blue.opacity(0.1),
                        Color.black
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Room Info")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .alert("Copied!", isPresented: $showCopiedAlert) {
            Button("OK") { }
        } message: {
            Text("Room ID copied to clipboard")
        }
    }
    
    private func copyRoomId() {
        UIPasteboard.general.string = roomId
        showCopiedAlert = true
    }
}

struct ConnectionStatusCard: View {
    let isConnected: Bool
    let connectionStatus: ChatService.ConnectionStatus
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connection Status")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(isConnected ? Color.green : Color.red)
                    .frame(width: 12, height: 12)
                
                // Status text
                Text(statusText)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.8))
                
                Spacer()
                
                // Refresh button for errors
                if case .error(_) = connectionStatus {
                    Button("Retry") {
                        // TODO: Implement retry logic
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private var statusText: String {
        switch connectionStatus {
        case .connected:
            return "Connected to server"
        case .connecting:
            return "Connecting..."
        case .disconnected:
            return "Disconnected"
        case .error(let message):
            return "Error: \(message)"
        }
    }
}

struct RoomIDCard: View {
    let roomId: String
    let onCopy: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Room ID")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 12) {
                // Room ID display
                HStack {
                    Text(roomId)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black.opacity(0.3))
                        )
                    
                    Spacer()
                    
                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.title3)
                            .foregroundColor(.blue)
                    }
                }
                
                // Instructions
                Text("Share this Room ID with others to invite them to join")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct PeersCard: View {
    let peers: [String]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Connected Users")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Peer count badge
                Text("\(peers.count + 1)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue.opacity(0.2))
                    )
            }
            
            VStack(spacing: 8) {
                // Current user
                UserRow(
                    name: "You",
                    isCurrentUser: true
                )
                
                // Other peers
                if peers.isEmpty {
                    Text("No other users connected")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.vertical, 8)
                } else {
                    ForEach(peers.indices, id: \.self) { index in
                        UserRow(
                            name: "Anonymous User \(index + 1)",
                            isCurrentUser: false
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct UserRow: View {
    let name: String
    let isCurrentUser: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(isCurrentUser ? Color.blue : Color.gray.opacity(0.5))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            // Name
            Text(name)
                .font(.body)
                .foregroundColor(.white)
            
            Spacer()
            
            // Online indicator
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RoomInfoView(
        roomId: "test-room-123456789",
        peers: ["peer1", "peer2"],
        isConnected: true,
        connectionStatus: .connected
    )
} 