import SwiftUI

struct ContentView: View {
    @StateObject private var chatService = ChatService()
    @State private var currentView: AppView = .loading
    @State private var currentRoomId: String?
    @State private var clientId = UUID().uuidString
    
    enum AppView {
        case loading
        case home
        case createRoom
        case joinRoom
        case chatRoom
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.black,
                    Color.blue.opacity(0.3),
                    Color.black
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Current view
            switch currentView {
            case .loading:
                LoadingView()
                    .onAppear {
                        // Auto-transition to home after loading
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                currentView = .home
                            }
                        }
                    }
                
            case .home:
                HomeView(
                    onCreateRoom: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .createRoom
                        }
                    },
                    onJoinRoom: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .joinRoom
                        }
                    }
                )
                
            case .createRoom:
                CreateRoomView(
                    chatService: chatService,
                    onRoomCreated: { roomId in
                        currentRoomId = roomId
                        chatService.connectToRoom(roomId: roomId)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .chatRoom
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }
                )
                
            case .joinRoom:
                JoinRoomView(
                    chatService: chatService,
                    onRoomJoined: { roomId in
                        currentRoomId = roomId
                        chatService.connectToRoom(roomId: roomId)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .chatRoom
                        }
                    },
                    onBack: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            currentView = .home
                        }
                    }
                )
                
            case .chatRoom:
                if let roomId = currentRoomId {
                    ChatRoomView(
                        chatService: chatService,
                        roomId: roomId,
                        clientId: clientId,
                        onLeave: {
                            chatService.leaveRoom()
                            currentRoomId = nil
                            withAnimation(.easeInOut(duration: 0.3)) {
                                currentView = .home
                            }
                        }
                    )
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
} 