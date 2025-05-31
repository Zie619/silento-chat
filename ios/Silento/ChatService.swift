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
    
    // Server discovery - production servers only
    private let serverURLs = [
        "https://silento-backend.onrender.com"   // Production API server
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
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60.0 // Much longer timeout for Render cold starts
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
        request.setValue("1.1", forHTTPHeaderField: "HTTP-Version") // Force HTTP/1.1
        
        // Configure session to avoid QUIC/HTTP3 issues
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil
        
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                print("❌ Server test failed for \(urlString): \(error.localizedDescription)")
                print("📊 Error details: Domain=\(nsError.domain), Code=\(nsError.code)")
                
                // Retry for specific timeout/network errors
                if nsError.code == -1001 || nsError.code == -1005 || nsError.code == -1009 {
                    print("🔄 Retrying server test for \(urlString) due to network/timeout error...")
                    DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
                        self.retryServerTest(urlString, attempt: 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Server \(urlString) responded with status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Server \(urlString) is working!")
                    completion(true)
                } else if httpResponse.statusCode == 502 || httpResponse.statusCode == 503 {
                    print("🚨 Server \(urlString) returned \(httpResponse.statusCode) (server starting up)")
                    // Retry for server startup issues
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        self.retryServerTest(urlString, attempt: 1, completion: completion)
                    }
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
    
    private func retryServerTest(_ urlString: String, attempt: Int, completion: @escaping (Bool) -> Void) {
        if attempt > 3 {
            print("❌ Max retry attempts reached for \(urlString)")
            completion(false)
            return
        }
        
        guard let url = URL(string: "\(urlString)/health") else {
            completion(false)
            return
        }
        
        print("🔄 Retry attempt \(attempt) for server: \(urlString)")
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60.0
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("iOS-App/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("1.1", forHTTPHeaderField: "HTTP-Version")
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        
        let session = URLSession(configuration: config)
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                let nsError = error as NSError
                print("❌ Retry \(attempt) failed for \(urlString): \(error.localizedDescription)")
                
                if nsError.code == -1001 || nsError.code == -1005 {
                    // Continue retrying for timeout/network errors
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        self.retryServerTest(urlString, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("📡 Retry \(attempt): Server \(urlString) responded with status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    print("✅ Server \(urlString) working after \(attempt) retries!")
                    completion(true)
                } else if (httpResponse.statusCode == 502 || httpResponse.statusCode == 503) && attempt < 3 {
                    // Keep retrying for server startup issues
                    DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                        self.retryServerTest(urlString, attempt: attempt + 1, completion: completion)
                    }
                } else {
                    completion(false)
                }
            } else {
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
        guard let serverURL = currentServerURL else { 
            print("❌ No server URL available for WebSocket connection")
            return 
        }
        
        // Convert HTTP URL to WebSocket URL
        let wsURL = serverURL.replacingOccurrences(of: "http://", with: "ws://")
                           .replacingOccurrences(of: "https://", with: "wss://")
        
        guard let url = URL(string: "\(wsURL)/ws") else { 
            print("❌ Invalid WebSocket URL: \(wsURL)/ws")
            return 
        }
        
        print("🔌 Connecting to WebSocket: \(url)")
        
        // Create URLRequest for WebSocket with headers
        var request = URLRequest(url: url)
        request.timeoutInterval = 60.0  // Extended timeout for production
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("iOS-App/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("1.1", forHTTPHeaderField: "HTTP-Version") // Force HTTP/1.1
        
        // Configure session for better production handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60.0
        config.timeoutIntervalForResource = 120.0
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        
        let session = URLSession(configuration: config)
        webSocketTask = session.webSocketTask(with: request)
        
        // Set up connection monitoring
        webSocketTask?.resume()
        
        print("⏳ Waiting for WebSocket connection (allowing time for production server)...")
        
        // Give WebSocket more time to connect for production servers
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds for production
        
        // Send init message
        let initMessage = WebSocketMessage(
            type: "init",
            clientId: clientId,
            roomId: roomId
        )
        
        print("📡 Sending WebSocket init message for room: \(roomId)")
        sendWebSocketMessage(initMessage)
        startListening()
        
        await MainActor.run {
            self.isConnected = true
            print("✅ WebSocket connected and listening")
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
            print("📥 Received WebSocket message: \(text)")
            
            guard let data = text.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else { 
                print("❌ Failed to parse WebSocket message")
                return 
            }
            
            print("📋 Parsed message type: \(type)")
            
            DispatchQueue.main.async {
                switch type {
                case "message":
                    if let content = json["content"] as? String,
                       let senderId = json["clientId"] as? String {
                        
                        // Don't add duplicate messages from ourselves
                        if senderId == self.clientId {
                            print("🔄 Skipping own message echo")
                            return
                        }
                        
                        let messageType = MessageType(rawValue: json["messageType"] as? String ?? "text") ?? .text
                        let timestamp = self.parseDate(json["timestamp"] as? String ?? "") ?? Date()
                        let mediaURL = json["mediaURL"] as? String
                        let fileName = json["fileName"] as? String
                        let fileSize = json["fileSize"] as? Int
                        
                        let chatMessage = ChatMessage(
                            content: content,
                            type: messageType,
                            isFromCurrentUser: false,
                            timestamp: timestamp,
                            senderId: senderId,
                            status: .delivered,
                            mediaURL: mediaURL,
                            fileName: fileName,
                            fileSize: fileSize
                        )
                        
                        print("✅ Adding message from \(senderId): \(content)")
                        self.messages.append(chatMessage)
                    } else {
                        print("❌ Invalid message format - missing content or clientId")
                    }
                    
                case "userJoined":
                    if let clientId = json["clientId"] as? String,
                       !self.peers.contains(clientId) {
                        print("👋 User joined: \(clientId)")
                        self.peers.append(clientId)
                    }
                    
                case "userLeft":
                    if let clientId = json["clientId"] as? String {
                        print("👋 User left: \(clientId)")
                        self.peers.removeAll { $0 == clientId }
                    }
                    
                case "roomState":
                    if let connectedUsers = json["connectedUsers"] as? [String] {
                        print("📊 Room state - connected users: \(connectedUsers)")
                        self.peers = connectedUsers.filter { $0 != self.clientId }
                    }
                    
                default:
                    print("❓ Unknown message type: \(type)")
                    break
                }
            }
        case .data(_):
            print("📦 Received binary WebSocket message (not supported)")
            break
        @unknown default:
            print("❓ Unknown WebSocket message format")
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
        print("📤 Sending message: '\(content)'")
        print("🔗 WebSocket connected: \(isConnected)")
        print("👥 Current peers: \(peers)")
        
        // Immediately add message to local state with "sending" status
        let localMessage = ChatMessage(
            content: content,
            type: .text,
            isFromCurrentUser: true,
            senderId: clientId,
            status: .sending
        )
        
        print("💾 Adding local message to UI: \(localMessage.id)")
        DispatchQueue.main.async {
            self.messages.append(localMessage)
            print("📊 Total messages now: \(self.messages.count)")
        }
        
        // Check WebSocket connection
        guard webSocketTask != nil else {
            print("❌ WebSocket task is nil")
            updateMessageStatus(localMessage.id, to: .failed)
            return
        }
        
        // Send via WebSocket
        let message = WebSocketMessage(
            type: "message",
            content: content,
            clientId: clientId,
            messageType: "text"
        )
        
        guard let data = try? JSONEncoder().encode(message),
              let text = String(data: data, encoding: .utf8) else {
            print("❌ Failed to encode message")
            updateMessageStatus(localMessage.id, to: .failed)
            return
        }
        
        print("📡 Sending WebSocket message: \(text)")
        
        webSocketTask?.send(.string(text)) { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("❌ Failed to send message: \(error.localizedDescription)")
                    self?.updateMessageStatus(localMessage.id, to: .failed)
                } else {
                    print("✅ Message sent successfully via WebSocket")
                    self?.updateMessageStatus(localMessage.id, to: .sent)
                }
            }
        }
    }
    
    private func updateMessageStatus(_ messageId: String, to status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            let updatedMessage = messages[index]
            // Create new message with updated status (since ChatMessage properties are let)
            let newMessage = ChatMessage(
                id: updatedMessage.id,
                content: updatedMessage.content,
                type: updatedMessage.type,
                isFromCurrentUser: updatedMessage.isFromCurrentUser,
                timestamp: updatedMessage.timestamp,
                senderId: updatedMessage.senderId,
                status: status,
                mediaURL: updatedMessage.mediaURL,
                fileName: updatedMessage.fileName,
                fileSize: updatedMessage.fileSize
            )
            messages[index] = newMessage
        }
    }
    
    func leaveRoom() {
        webSocketTask?.cancel()
        isConnected = false
        messages.removeAll()
        peers.removeAll()
    }
}

// MARK: - Models

enum MessageType: String, Codable {
    case text
    case image
    case video
    case audio
    case file
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case failed
}

struct ChatMessage: Identifiable, Codable {
    let id: String
    let content: String
    let type: MessageType
    let isFromCurrentUser: Bool
    let timestamp: Date
    let senderId: String
    let status: MessageStatus
    let mediaURL: String?
    let fileName: String?
    let fileSize: Int?
    
    init(id: String = UUID().uuidString, content: String, type: MessageType = .text, isFromCurrentUser: Bool, timestamp: Date = Date(), senderId: String, status: MessageStatus = .sent, mediaURL: String? = nil, fileName: String? = nil, fileSize: Int? = nil) {
        self.id = id
        self.content = content
        self.type = type
        self.isFromCurrentUser = isFromCurrentUser
        self.timestamp = timestamp
        self.senderId = senderId
        self.status = status
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSize = fileSize
    }
}

struct WebSocketMessage: Codable {
    let type: String
    let content: String?
    let clientId: String
    let roomId: String?
    let messageType: String?
    let mediaURL: String?
    let fileName: String?
    let fileSize: Int?
    
    init(type: String, content: String? = nil, clientId: String, roomId: String? = nil, messageType: String? = nil, mediaURL: String? = nil, fileName: String? = nil, fileSize: Int? = nil) {
        self.type = type
        self.content = content
        self.clientId = clientId
        self.roomId = roomId
        self.messageType = messageType
        self.mediaURL = mediaURL
        self.fileName = fileName
        self.fileSize = fileSize
    }
} 