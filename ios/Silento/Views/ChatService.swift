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
        case error(String)
    }
    
    // Server discovery - use ONLY production server
    private let serverURLs = [
        "https://silento-backend.onrender.com"   // Production API server ONLY
    ]
    
    init() {
        connectionStatus = .connecting
        discoverServer { }
    }
    
    // MARK: - Server Discovery
    
    private func discoverServer(completion: @escaping () -> Void) {
        var attemptedServers = 0
        let totalServers = serverURLs.count
        
        for serverURL in serverURLs {
            testServer(serverURL) { [weak self] success in
                DispatchQueue.main.async {
                    attemptedServers += 1
                    
                    if success && self?.currentServerURL == nil {
                        self?.currentServerURL = serverURL
                        self?.connectionStatus = .connected
                        print("🎉 Connected to server: \(serverURL)")
                        completion()
                        return
                    }
                    
                    if attemptedServers == totalServers && self?.currentServerURL == nil {
                        self?.connectionStatus = .failed
                        print("❌ All servers failed to connect")
                        completion()
                    }
                }
            }
        }
    }
    
    private func testServer(_ urlString: String, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(urlString)/health") else {
            print("❌ Invalid URL: \(urlString)")
            completion(false)
            return
        }
        
        print("🔍 Testing server: \(urlString)")
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                print("❌ Server test failed for \(urlString): \(error.localizedDescription)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Server \(urlString) responded with status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Server \(urlString) is working!")
                    completion(true)
                } else if httpResponse.statusCode == 502 {
                    print("🚨 Server \(urlString) returned 502 Bad Gateway (server down)")
                    completion(false)
                } else {
                    print("⚠️ Server \(urlString) returned status: \(httpResponse.statusCode)")
                    completion(false)
                }
            } else {
                print("❌ No HTTP response from \(urlString)")
                completion(false)
            }
        }
        
        task.resume()
    }
    
    // MARK: - Room Management
    
    func createRoom(completion: @escaping (Result<String, Error>) -> Void) {
        guard let serverURL = currentServerURL else {
            completion(.failure(NSError(domain: "NoServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No server available"])))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/api/create-room") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
            return
        }
        
        print("🚀 Creating room at: \(url)")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["clientId": clientId]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("📤 Request body: \(body)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Network error: \(error.localizedDescription)")
                    completion(.failure(error))
                    return
                }
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("📡 HTTP Status: \(httpResponse.statusCode)")
                }
                
                guard let data = data else {
                    print("❌ No response data")
                    completion(.failure(NSError(domain: "NoData", code: 0, userInfo: [NSLocalizedDescriptionKey: "No response data"])))
                    return
                }
                
                print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "nil")")
                
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("❌ Failed to parse JSON")
                    completion(.failure(NSError(domain: "InvalidJSON", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON response"])))
                    return
                }
                
                print("📋 Parsed JSON: \(json)")
                
                guard let roomId = json["roomId"] as? String else {
                    print("❌ No roomId in response")
                    completion(.failure(NSError(domain: "InvalidResponse", code: 0, userInfo: [NSLocalizedDescriptionKey: "No roomId in response"])))
                    return
                }
                
                print("✅ Room created successfully: \(roomId)")
                completion(.success(roomId))
            }
        }.resume()
    }
    
    func joinRoom(_ roomId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let serverURL = currentServerURL else {
            completion(.failure(NSError(domain: "NoServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No server available"])))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/api/join-room") else {
            completion(.failure(NSError(domain: "InvalidURL", code: 0, userInfo: nil)))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["roomId": roomId, "clientId": clientId]
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
            clientId: clientId,
            roomId: roomId
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