import Foundation
import SwiftUI

class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var peers: [String] = []
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let clientId = UUID().uuidString
    private var currentServerURL: String?
    
    enum ConnectionStatus {
        case disconnected
        case connecting
        case connected
        case failed
    }
    
    // Server discovery - try multiple URLs
    private let serverURLs = [
        "http://silento-server.onrender.com",  // Production
        "http://192.168.68.52:5001",          // Local network (from your terminal output)
        "http://localhost:5001"               // Localhost
    ]
    
    init() {
        discoverServer()
    }
    
    // MARK: - Server Discovery
    
    private func discoverServer() {
        connectionStatus = .connecting
        
        Task {
            for serverURL in serverURLs {
                if await testServerConnection(serverURL) {
                    await MainActor.run {
                        self.currentServerURL = serverURL
                        self.connectionStatus = .connected
                        print("✅ Connected to server: \(serverURL)")
                    }
                    return
                }
            }
            
            // If no server found
            await MainActor.run {
                self.connectionStatus = .failed
                print("❌ No server available")
            }
        }
    }
    
    private func testServerConnection(_ serverURL: String) async -> Bool {
        guard let url = URL(string: "\(serverURL)/health") else { return false }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                return httpResponse.statusCode == 200
            }
        } catch {
            print("Server test failed for \(serverURL): \(error)")
        }
        return false
    }
    
    // MARK: - Room Management
    
    func createRoom(completion: @escaping (Result<String, Error>) -> Void) {
        guard let serverURL = currentServerURL else {
            completion(.failure(NSError(domain: "NoServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No server available"])))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/api/rooms") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["clientId": clientId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let roomId = json["roomId"] as? String else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: nil)))
                    return
                }
                
                completion(.success(roomId))
            }
        }.resume()
    }
    
    func joinRoom(_ roomId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let serverURL = currentServerURL else {
            completion(.failure(NSError(domain: "NoServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No server available"])))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/api/rooms/\(roomId)/join") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["clientId": clientId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    completion(.success(httpResponse.statusCode == 200))
                } else {
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: nil)))
                }
            }
        }.resume()
    }
    
    func connectToRoom(roomId: String) {
        // Clear previous messages
        messages.removeAll()
        peers.removeAll()
        
        // Connect to WebSocket
        Task {
            await connectWebSocket(roomId: roomId)
        }
    }
    
    // MARK: - WebSocket Connection
    
    private func connectWebSocket(roomId: String) async {
        guard let serverURL = currentServerURL else { return }
        
        // Convert HTTP URL to WebSocket URL
        let wsURL = serverURL.replacingOccurrences(of: "http://", with: "ws://")
                           .replacingOccurrences(of: "https://", with: "wss://")
        
        guard let url = URL(string: "\(wsURL)/ws") else { return }
        
        webSocketTask = URLSession.shared.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Send init message
        let initMessage = WebSocketMessage(
            type: "init",
            roomId: roomId,
            clientId: clientId
        )
        
        sendWebSocketMessage(initMessage)
        startListening()
        
        await MainActor.run {
            self.isConnected = true
        }
    }
    
    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                self?.handleWebSocketMessage(message)
                self?.startListening() // Continue listening
            case .failure(let error):
                print("WebSocket error: \(error)")
                DispatchQueue.main.async {
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { return }
            
            DispatchQueue.main.async {
                switch type {
                case "message":
                    if let content = json["content"] as? String,
                       let senderId = json["clientId"] as? String,
                       let timestamp = json["timestamp"] as? String {
                        let message = ChatMessage(
                            id: UUID().uuidString,
                            content: content,
                            isFromCurrentUser: senderId == self.clientId,
                            timestamp: self.parseDate(timestamp) ?? Date()
                        )
                        self.messages.append(message)
                    }
                case "userJoined":
                    if let clientId = json["clientId"] as? String,
                       !self.peers.contains(clientId) {
                        self.peers.append(clientId)
                    }
                case "userLeft":
                    if let clientId = json["clientId"] as? String {
                        self.peers.removeAll { $0 == clientId }
                    }
                case "roomState":
                    if let connectedUsers = json["connectedUsers"] as? [String] {
                        self.peers = connectedUsers.filter { $0 != self.clientId }
                    }
                default:
                    break
                }
            }
        case .data(_):
            break
        @unknown default:
            break
        }
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return formatter.date(from: dateString)
    }
    
    private func sendWebSocketMessage(_ message: WebSocketMessage) {
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ content: String) {
        let message = WebSocketMessage(
            type: "message",
            content: content,
            clientId: clientId
        )
        sendWebSocketMessage(message)
    }
    
    func leaveRoom() {
        webSocketTask?.cancel()
        isConnected = false
        messages.removeAll()
        peers.removeAll()
    }
}

// MARK: - Models

struct ChatMessage: Identifiable {
    let id: String
    let content: String
    let isFromCurrentUser: Bool
    let timestamp: Date
}

struct WebSocketMessage: Codable {
    let type: String
    let content: String?
    let clientId: String
    let roomId: String?
    
    init(type: String, content: String? = nil, clientId: String, roomId: String? = nil) {
        self.type = type
        self.content = content
        self.clientId = clientId
        self.roomId = roomId
    }
} 