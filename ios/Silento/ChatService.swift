import Foundation
import SwiftUI
import Network
import CryptoKit

class ChatService: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var peers: [String] = []
    @Published var isConnected = false
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var isCreatingRoom = false
    @Published var isJoiningRoom = false
    
    enum ConnectionStatus: String, CaseIterable {
        case disconnected = "Disconnected"
        case connecting = "Connecting..."
        case connected = "Connected"
        case failed = "Connection Failed"
        case roomCreating = "Creating Room..."
        case roomJoining = "Joining Room..."
    }
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession
    var currentRoomId: String?
    private var currentServerURL: String?
    private var _clientId: String
    private var encryptionKey: SymmetricKey?
    
    // Public properties
    var clientId: String {
        return self._clientId
    }
    
    var serverURL: String? {
        return self.currentServerURL
    }
    
    // Server discovery - Railway production server (much better than Render!)
    private let serverURLs = [
        "https://silento-back-production.up.railway.app", // Railway production server (primary)
        "http://localhost:8000"                           // Local test server (fallback only)
    ]
    
    init() {
        self._clientId = UUID().uuidString
        self.urlSession = URLSession.shared
        self.connectionStatus = .disconnected
        self.encryptionKey = SymmetricKey(size: .bits256)
        
        print("🆔 Client ID: \(_clientId)")
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
        // Prevent multiple simultaneous room creation attempts
        guard !isCreatingRoom else {
            print("🚫 Room creation already in progress")
            return
        }
        
        isCreatingRoom = true
        connectionStatus = .roomCreating
        
        Task {
            await MainActor.run {
                isCreatingRoom = true
                connectionStatus = .roomCreating
            }
            
            do {
                let roomId = try await performCreateRoom()
                await MainActor.run {
                    self.isCreatingRoom = false
                    completion(.success(roomId))
                }
            } catch {
                await MainActor.run {
                    self.isCreatingRoom = false
                    self.connectionStatus = .failed
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performCreateRoom() async throws -> String {
        for serverURL in serverURLs {
            print("🔍 Testing server: \(serverURL)")
            
            do {
                // Test server connectivity first
                guard let healthURL = URL(string: "\(serverURL)/health") else {
                    throw NetworkError.invalidURL
                }
                
                let (_, response) = try await urlSession.data(from: healthURL)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                print("📡 Server \(serverURL) responded with status: \(httpResponse.statusCode)")
                print("✅ Server \(serverURL) is working!")
                
                await MainActor.run {
                    connectionStatus = .connecting
                }
                
                // Create room
                guard let createURL = URL(string: "\(serverURL)/api/create-room") else {
                    throw NetworkError.invalidURL
                }
                
                print("🚀 Creating room at: \(createURL)")
                
                var request = URLRequest(url: createURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = ["clientId": _clientId]
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = bodyData
                
                print("📤 Request body: \(body)")
                
                let (data, createResponse) = try await urlSession.data(for: request)
                
                guard let httpCreateResponse = createResponse as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 HTTP Status: \(httpCreateResponse.statusCode)")
                print("📥 Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
                
                guard httpCreateResponse.statusCode == 200 else {
                    throw NetworkError.serverError(httpCreateResponse.statusCode)
                }
                
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                print("📋 Parsed JSON: \(json ?? [:])")
                
                guard let roomId = json?["roomId"] as? String else {
                    throw NetworkError.noRoomId
                }
                
                print("✅ Room created successfully: \(roomId)")
                
                // Connect to WebSocket
                try await connectToWebSocket(serverURL: serverURL, roomId: roomId)
                
                return roomId
                
            } catch {
                print("❌ Server \(serverURL) failed: \(error)")
                continue
            }
        }
        
        throw NetworkError.allServersFailed
    }
    
    private func connectToWebSocket(serverURL: String, roomId: String) async throws {
        // Prevent multiple simultaneous connections
        if webSocketTask != nil {
            print("🔄 Closing existing WebSocket connection")
            webSocketTask?.cancel()
            webSocketTask = nil
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
        }
        
        currentRoomId = roomId
        
        guard let wsURL = URL(string: serverURL.replacingOccurrences(of: "https://", with: "wss://") + "/ws") else {
            throw NetworkError.invalidURL
        }
        
        print("🔌 Connecting to WebSocket: \(wsURL)")
        
        await MainActor.run {
            connectionStatus = .connecting
        }
        
        var request = URLRequest(url: wsURL)
        request.timeoutInterval = 30.0
        request.setValue("13", forHTTPHeaderField: "Sec-WebSocket-Version")
        request.setValue("websocket", forHTTPHeaderField: "Upgrade")
        request.setValue("Upgrade", forHTTPHeaderField: "Connection")
        
        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()
        
        print("⏳ Waiting for WebSocket connection...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Send initial room join message
        let initMessage = [
            "type": "init",
            "roomId": roomId,
            "clientId": _clientId
        ]
        
        print("📡 Sending WebSocket init message for room: \(roomId)")
        Task {
            do {
                try await sendWebSocketMessageAsync(WebSocketMessage(
                    type: "init",
                    content: nil,
                    clientId: _clientId,
                    roomId: roomId,
                    messageType: nil,
                    mediaURL: nil,
                    fileName: nil,
                    fileSize: nil
                ))
            } catch {
                print("❌ Failed to send init message: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = .failed
                }
            }
        }
        
        // Don't set connection status here - wait for init-success response
        print("✅ WebSocket init message sent, waiting for server response...")
        
        // Start listening for messages
        Task {
            listenForMessages()
        }
    }
    
    func joinRoom(_ roomId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // Prevent multiple simultaneous join attempts
        guard !isJoiningRoom else {
            print("🚫 Room joining already in progress")
            completion(.failure(NSError(domain: "JoinInProgress", code: 0, userInfo: [NSLocalizedDescriptionKey: "Already joining a room"])))
            return
        }
        
        isJoiningRoom = true
        connectionStatus = .roomJoining
        
        Task {
            await MainActor.run {
                isJoiningRoom = true
                connectionStatus = .roomJoining
            }
            
            do {
                let success = try await performJoinRoom(roomId: roomId)
                await MainActor.run {
                    self.isJoiningRoom = false
                    completion(.success(success))
                }
            } catch {
                await MainActor.run {
                    self.isJoiningRoom = false
                    self.connectionStatus = .failed
                    completion(.failure(error))
                }
            }
        }
    }
    
    private func performJoinRoom(roomId: String) async throws -> Bool {
        for serverURL in serverURLs {
            print("🔍 Testing server for room join: \(serverURL)")
            
            do {
                // Test server connectivity first
                guard let healthURL = URL(string: "\(serverURL)/health") else {
                    throw NetworkError.invalidURL
                }
                
                let (_, response) = try await urlSession.data(from: healthURL)
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else {
                    continue
                }
                
                print("📡 Server \(serverURL) is healthy for room join")
                
                await MainActor.run {
                    connectionStatus = .connecting
                }
                
                // Join room
                guard let joinURL = URL(string: "\(serverURL)/api/join-room") else {
                    throw NetworkError.invalidURL
                }
                
                print("🚪 Joining room \(roomId) at: \(joinURL)")
                
                var request = URLRequest(url: joinURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let body = ["roomId": roomId, "clientId": _clientId]
                let bodyData = try JSONSerialization.data(withJSONObject: body)
                request.httpBody = bodyData
                
                print("📤 Join request body: \(body)")
                
                let (data, joinResponse) = try await urlSession.data(for: request)
                
                guard let httpJoinResponse = joinResponse as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }
                
                print("📡 Join HTTP Status: \(httpJoinResponse.statusCode)")
                print("📥 Join Response data: \(String(data: data, encoding: .utf8) ?? "No data")")
                
                guard httpJoinResponse.statusCode == 200 else {
                    if httpJoinResponse.statusCode == 404 {
                        throw NSError(domain: "RoomNotFound", code: 404, userInfo: [NSLocalizedDescriptionKey: "Room \(roomId) not found"])
                    } else {
                        throw NetworkError.serverError(httpJoinResponse.statusCode)
                    }
                }
                
                print("✅ Successfully joined room: \(roomId)")
                
                // Connect to WebSocket
                try await connectToWebSocket(serverURL: serverURL, roomId: roomId)
                
                return true
                
            } catch {
                print("❌ Server \(serverURL) failed for room join: \(error)")
                continue
            }
        }
        
        throw NetworkError.allServersFailed
    }
    
    func connectToRoom(roomId: String) {
        // This method should just ensure we're properly connected to the existing room
        // Don't create a new room - we're already in one!
        print("🔗 Ensuring connection to existing room: \(roomId)")
        
        // If we already have a current room and it matches, do nothing
        if let currentRoom = currentRoomId, currentRoom == roomId, isConnected {
            print("✅ Already connected to room: \(roomId)")
            return
        }
        
        // Update current room ID if different
        currentRoomId = roomId
        
        // If not connected yet, the existing joinRoom or createRoom flow will handle the connection
        if !isConnected {
            print("⏳ Connection will be established by join/create room flow")
        } else {
            print("✅ Connected to room: \(roomId)")
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
            clientId: _clientId,
            roomId: roomId
        )
        
        print("📡 Sending WebSocket init message for room: \(roomId)")
        Task {
            do {
                try await sendWebSocketMessageAsync(initMessage)
            } catch {
                print("❌ Failed to send init message: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = .failed
                }
            }
        }
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
                        if senderId == self._clientId {
                            print("🔄 Skipping own message echo")
                            return
                        }
                        
                        let messageType = MessageType(rawValue: json["messageType"] as? String ?? "text") ?? .text
                        let timestamp = self.parseDate(json["timestamp"] as? String ?? "") ?? Date()
                        let mediaURL = json["mediaURL"] as? String
                        let fileName = json["fileName"] as? String
                        let fileSize = json["fileSize"] as? Int
                        
                        let chatMessage = ChatMessage(
                            id: UUID().uuidString,
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
                        self.peers = connectedUsers.filter { $0 != self._clientId }
                    }
                    
                case "media_start":
                    self.handleMediaStart(json)
                    
                case "media_chunk":
                    if let messageData = text.data(using: .utf8) {
                        self.handleMediaChunk(messageData)
                    }
                    
                case "media_end":
                    print("✅ Media transfer completed")
                    
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
    
    private func sendWebSocketMessageAsync(_ message: WebSocketMessage) async throws {
        let encoder = JSONEncoder()
        let messageData = try encoder.encode(message)
        let messageText = String(data: messageData, encoding: .utf8) ?? ""
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask?.send(.string(messageText)) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    func sendMessage(_ content: String) {
        let message = ChatMessage(
            id: UUID().uuidString,
            content: content,
            type: .text,
            isFromCurrentUser: true,
            timestamp: Date(),
            senderId: _clientId,
            status: .sending
        )
        
        // Add to local messages immediately
        DispatchQueue.main.async {
            self.messages.append(message)
            print("💾 Adding local message to UI: \(message.id)")
        }
        
        // Send via WebSocket
        Task {
            await sendMessageViaWebSocket(message)
        }
    }
    
    private func sendMessageViaWebSocket(_ message: ChatMessage) async {
        guard isConnected else {
            print("❌ Cannot send message: not connected")
            await MainActor.run {
                updateMessageStatus(messageId: message.id, status: .failed)
            }
            return
        }
        
        guard let roomId = currentRoomId else {
            print("❌ Cannot send message: no room ID")
            await MainActor.run {
                updateMessageStatus(messageId: message.id, status: .failed)
            }
            return
        }
        
        print("📤 Sending message: '\(message.content)'")
        print("🔗 WebSocket connected: \(isConnected)")
        print("👥 Current peers: \(peers)")
        print("🏠 Room ID: \(roomId)")
        
        do {            
            let webSocketMessage = WebSocketMessage(
                type: "message",
                content: message.content,
                clientId: _clientId,
                roomId: roomId,
                messageType: message.type.rawValue,
                mediaURL: message.mediaURL,
                fileName: message.fileName,
                fileSize: message.fileSize
            )
            
            try await sendWebSocketMessageAsync(webSocketMessage)
            
            await MainActor.run {
                updateMessageStatus(messageId: message.id, status: .sent)
            }
            
        } catch {
            print("❌ Failed to send message: \(error)")
            await MainActor.run {
                updateMessageStatus(messageId: message.id, status: .failed)
            }
        }
    }
    
    private func encryptMessage(_ content: String) throws -> String {
        guard let encryptionKey = encryptionKey else {
            return content // Return unencrypted if no key
        }
        
        let data = content.data(using: .utf8)!
        let sealedBox = try AES.GCM.seal(data, using: encryptionKey)
        return sealedBox.combined!.base64EncodedString()
    }
    
    private func decryptMessage(_ encryptedContent: String) throws -> String {
        guard let encryptionKey = encryptionKey,
              let encryptedData = Data(base64Encoded: encryptedContent) else {
            return encryptedContent // Return as-is if can't decrypt
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
        let decryptedData = try AES.GCM.open(sealedBox, using: encryptionKey)
        return String(data: decryptedData, encoding: .utf8) ?? encryptedContent
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
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    print("📥 Received WebSocket message: \(text)")
                    Task {
                        await self?.handleWebSocketMessage(text)
                    }
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        print("📥 Received WebSocket data as text: \(text)")
                        Task {
                            await self?.handleWebSocketMessage(text)
                        }
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self?.listenForMessages()
            case .failure(let error):
                print("❌ WebSocket receive error: \(error)")
                DispatchQueue.main.async {
                    self?.connectionStatus = .failed
                    self?.isConnected = false
                }
            }
        }
    }
    
    private func handleWebSocketMessage(_ text: String) async {
        do {
            guard let data = text.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = json["type"] as? String else {
                print("❌ Failed to parse WebSocket message")
                return
            }
            
            print("📋 Parsed message type: \(type)")
            
            switch type {
            case "init-success":
                if let peers = json["peers"] as? [String] {
                    await MainActor.run {
                        self.peers = peers
                        self.isConnected = true
                        self.connectionStatus = .connected
                        print("🔄 State updated: isConnected=\(self.isConnected), status=\(self.connectionStatus)")
                    }
                    print("✅ Room joined successfully with \(peers.count) peers")
                    print("✅ Connection fully established - ready for UI navigation")
                } else {
                    print("⚠️ Received init-success but no peers array")
                    await MainActor.run {
                        self.peers = []
                        self.isConnected = true
                        self.connectionStatus = .connected
                        print("🔄 State updated: isConnected=\(self.isConnected), status=\(self.connectionStatus)")
                    }
                    print("✅ Room joined successfully with 0 peers")
                    print("✅ Connection fully established - ready for UI navigation")
                }
                
            case "message":
                guard let content = json["content"] as? String,
                      let senderId = json["clientId"] as? String,
                      let messageTypeString = json["messageType"] as? String else {
                    print("❌ Invalid message format")
                    return
                }
                
                // Skip messages from ourselves
                guard senderId != _clientId else {
                    print("📤 Skipping own message")
                    return
                }
                
                // Don't decrypt messages for now since encryption is disabled
                // TODO: Implement proper shared encryption key
                let messageContent = content
                
                let messageType = MessageType(rawValue: messageTypeString) ?? .text
                let mediaURL = json["mediaURL"] as? String
                let fileName = json["fileName"] as? String
                
                let chatMessage = ChatMessage(
                    id: UUID().uuidString,
                    content: messageContent,
                    type: messageType,
                    isFromCurrentUser: false,
                    timestamp: Date(),
                    senderId: senderId,
                    status: .delivered,
                    mediaURL: mediaURL?.isEmpty == false ? mediaURL : nil,
                    fileName: fileName?.isEmpty == false ? fileName : nil
                )
                
                await MainActor.run {
                    // Check for duplicates
                    let isDuplicate = messages.contains { existingMessage in
                        existingMessage.content == chatMessage.content &&
                        existingMessage.isFromCurrentUser == chatMessage.isFromCurrentUser &&
                        abs(existingMessage.timestamp.timeIntervalSince(chatMessage.timestamp)) < 1.0
                    }
                    
                    if !isDuplicate {
                        messages.append(chatMessage)
                        print("📥 Added incoming message: \(chatMessage.content)")
                    } else {
                        print("🔄 Skipped duplicate message: \(chatMessage.content)")
                    }
                }
                
            case "peer-joined":
                if let peerId = json["clientId"] as? String, peerId != _clientId {
                    await MainActor.run {
                        if !peers.contains(peerId) {
                            peers.append(peerId)
                            
                            // Add system message for user joined
                            let joinMessage = ChatMessage(
                                id: UUID().uuidString,
                                content: "👋 A user joined the room",
                                type: .text,
                                isFromCurrentUser: false,
                                timestamp: Date(),
                                senderId: "system",
                                status: .delivered
                            )
                            messages.append(joinMessage)
                        }
                    }
                    print("👋 Peer joined: \(peerId)")
                }
                
            case "peer-left":
                if let peerId = json["clientId"] as? String {
                    await MainActor.run {
                        if peers.contains(peerId) {
                            peers.removeAll { $0 == peerId }
                            
                            // Add system message for user left
                            let leaveMessage = ChatMessage(
                                id: UUID().uuidString,
                                content: "👋 A user left the room",
                                type: .text,
                                isFromCurrentUser: false,
                                timestamp: Date(),
                                senderId: "system",
                                status: .delivered
                            )
                            messages.append(leaveMessage)
                        }
                    }
                    print("👋 Peer left: \(peerId)")
                }
                
            default:
                print("❓ Unknown message type: \(type)")
            }
            
        } catch {
            print("❌ Error handling WebSocket message: \(error)")
        }
    }
    
    private func updateMessageStatus(messageId: String, status: MessageStatus) {
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].status = status
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel()
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected
        peers.removeAll()
        messages.removeAll()
        currentRoomId = nil
        print("🔌 Disconnected from chat service")
    }
    
    deinit {
        disconnect()
    }
    
    private func performFileUpload(data: Data, fileName: String, mimeType: String) async throws -> String {
        guard let serverURL = currentServerURL ?? serverURLs.first,
              let uploadURL = URL(string: "\(serverURL)/api/upload") else {
            throw NetworkError.invalidURL
        }
        
        print("📤 Uploading file to: \(uploadURL)")
        print("📊 File size: \(data.count) bytes, Type: \(mimeType)")
        
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0 // 2 minutes for large files
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (responseData, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        print("📡 Upload response status: \(httpResponse.statusCode)")
        
        if httpResponse.statusCode != 200 {
            if let errorData = String(data: responseData, encoding: .utf8) {
                print("❌ Upload error response: \(errorData)")
            }
            throw NetworkError.serverError(httpResponse.statusCode)
        }
        
        let json = try JSONSerialization.jsonObject(with: responseData) as? [String: Any]
        print("📋 Upload response: \(json ?? [:])")
        
        guard let fileURL = json?["url"] as? String else {
            throw NetworkError.noFileURL
        }
        
        let fullURL = serverURL + fileURL
        print("✅ File uploaded successfully: \(fullURL)")
        return fullURL
    }
    
    func sendMediaMessage(fileURL: String, fileName: String, mimeType: String) {
        let messageType: MessageType
        if mimeType.starts(with: "image/") {
            messageType = .image
        } else if mimeType.starts(with: "video/") {
            messageType = .video
        } else if mimeType.starts(with: "audio/") {
            messageType = .audio
        } else {
            messageType = .file
        }
        
        let message = ChatMessage(
            id: UUID().uuidString,
            content: fileName,
            type: messageType,
            isFromCurrentUser: true,
            timestamp: Date(),
            senderId: _clientId,
            status: .sending,
            mediaURL: fileURL,
            fileName: fileName
        )
        
        DispatchQueue.main.async {
            self.messages.append(message)
        }
        
        Task {
            await sendMessageViaWebSocket(message)
        }
    }
    
    func uploadFile(_ data: Data, fileName: String, mimeType: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let fileURL = try await performFileUpload(data: data, fileName: fileName, mimeType: mimeType)
                completion(.success(fileURL))
            } catch NetworkError.serverError(404) {
                // Server doesn't support uploads yet - provide helpful error message
                completion(.failure(UploadError.serverNotReady))
            } catch NetworkError.serverError(_) {
                completion(.failure(UploadError.invalidResponse))
            } catch {
                completion(.failure(UploadError.networkError))
            }
        }
    }
    
    private func sendInitMessage(roomId: String) {
        print("📡 Sending WebSocket init message for room: \(roomId)")
        
        Task {
            do {
                try await sendWebSocketMessageAsync(WebSocketMessage(
                    type: "init",
                    content: nil,
                    clientId: _clientId,
                    roomId: roomId,
                    messageType: nil,
                    mediaURL: nil,
                    fileName: nil,
                    fileSize: nil
                ))
            } catch {
                print("❌ Failed to send init message: \(error)")
                DispatchQueue.main.async {
                    self.connectionStatus = .failed
                }
            }
        }
    }
    
    func leaveRoom() {
        webSocketTask?.cancel()
        webSocketTask = nil
        isConnected = false
        connectionStatus = .disconnected
        peers.removeAll()
        messages.removeAll()
        currentRoomId = nil
        currentServerURL = nil
        
        // Clean up temporary media files
        cleanupTempMediaFiles()
        
        print("🔌 Left room and disconnected")
    }
    
    // MARK: - P2P Media Transfer
    
    func sendMediaDataDirectly(_ data: Data, fileName: String, mimeType: String, completion: @escaping (Result<String, Error>) -> Void) {
        Task {
            do {
                let localURL = try await sendMediaViaPeerToPeer(data: data, fileName: fileName, mimeType: mimeType)
                completion(.success(localURL))
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    private func sendMediaViaPeerToPeer(data: Data, fileName: String, mimeType: String) async throws -> String {
        print("📡 Starting P2P media transfer for \(fileName) (\(data.count) bytes)")
        
        // Store file locally for sending
        let localURL = try saveMediaFileLocally(data: data, fileName: fileName)
        
        // Send media chunks via WebSocket
        try await sendMediaChunks(data: data, fileName: fileName, mimeType: mimeType)
        
        return localURL
    }
    
    private func saveMediaFileLocally(data: Data, fileName: String) throws -> String {
        let tempDir = createTempMediaDirectory()
        let fileURL = tempDir.appendingPathComponent(fileName)
        
        try data.write(to: fileURL)
        print("💾 Saved media file locally: \(fileURL.path)")
        
        return fileURL.absoluteString
    }
    
    private func createTempMediaDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SilentoMedia")
        
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            print("📁 Created temp media directory: \(tempDir.path)")
        }
        
        return tempDir
    }
    
    private func sendMediaChunks(data: Data, fileName: String, mimeType: String) async throws {
        let chunkSize = 64 * 1024 // 64KB chunks
        let totalChunks = (data.count + chunkSize - 1) / chunkSize
        let mediaId = UUID().uuidString
        
        print("📦 Sending \(totalChunks) chunks for \(fileName)")
        
        // Send media start message
        let startMessage = WebSocketMessage(
            type: "media_start",
            content: nil,
            clientId: _clientId,
            roomId: currentRoomId,
            messageType: mimeType,
            mediaURL: mediaId,
            fileName: fileName,
            fileSize: data.count
        )
        
        try await sendWebSocketMessageAsync(startMessage)
        
        // Send chunks
        for chunkIndex in 0..<totalChunks {
            let startIndex = chunkIndex * chunkSize
            let endIndex = min(startIndex + chunkSize, data.count)
            let chunkData = data.subdata(in: startIndex..<endIndex)
            
            let chunkMessage = MediaChunkMessage(
                type: "media_chunk",
                clientId: _clientId,
                roomId: currentRoomId ?? "",
                mediaId: mediaId,
                chunkIndex: chunkIndex,
                totalChunks: totalChunks,
                chunkData: chunkData.base64EncodedString()
            )
            
            let encoder = JSONEncoder()
            let messageData = try encoder.encode(chunkMessage)
            let messageText = String(data: messageData, encoding: .utf8) ?? ""
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                webSocketTask?.send(.string(messageText)) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            
            print("📤 Sent chunk \(chunkIndex + 1)/\(totalChunks)")
            
            // Small delay to prevent overwhelming the connection
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        // Send media end message
        let endMessage = WebSocketMessage(
            type: "media_end",
            content: nil,
            clientId: _clientId,
            roomId: currentRoomId,
            messageType: mimeType,
            mediaURL: mediaId,
            fileName: fileName,
            fileSize: data.count
        )
        
        try await sendWebSocketMessageAsync(endMessage)
        print("✅ Completed P2P media transfer for \(fileName)")
    }
    
    private func sendWebSocketMessage(_ message: WebSocketMessage) async throws {
        let encoder = JSONEncoder()
        let messageData = try encoder.encode(message)
        let messageText = String(data: messageData, encoding: .utf8) ?? ""
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            webSocketTask?.send(.string(messageText)) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Receiving Media Chunks
    
    private var receivingMedia: [String: MediaReceiveState] = [:]
    
    private struct MediaReceiveState {
        let fileName: String
        let mimeType: String
        let totalSize: Int
        let totalChunks: Int
        var receivedChunks: [Int: Data] = [:]
        var receivedChunkCount: Int = 0
        
        var isComplete: Bool {
            return receivedChunkCount == totalChunks
        }
    }
    
    private func handleMediaStart(_ message: [String: Any]) {
        guard let mediaId = message["mediaURL"] as? String,
              let fileName = message["fileName"] as? String,
              let mimeType = message["messageType"] as? String,
              let fileSize = message["fileSize"] as? Int else {
            print("❌ Invalid media start message")
            return
        }
        
        // Calculate total chunks
        let chunkSize = 64 * 1024
        let totalChunks = (fileSize + chunkSize - 1) / chunkSize
        
        receivingMedia[mediaId] = MediaReceiveState(
            fileName: fileName,
            mimeType: mimeType,
            totalSize: fileSize,
            totalChunks: totalChunks
        )
        
        print("🔄 Started receiving media: \(fileName) (\(fileSize) bytes, \(totalChunks) chunks)")
    }
    
    private func handleMediaChunk(_ data: Data) {
        do {
            let chunkMessage = try JSONDecoder().decode(MediaChunkMessage.self, from: data)
            
            guard var mediaState = receivingMedia[chunkMessage.mediaId] else {
                print("❌ Received chunk for unknown media: \(chunkMessage.mediaId)")
                return
            }
            
            // Decode chunk data
            guard let chunkData = Data(base64Encoded: chunkMessage.chunkData) else {
                print("❌ Failed to decode chunk data")
                return
            }
            
            // Store chunk
            mediaState.receivedChunks[chunkMessage.chunkIndex] = chunkData
            mediaState.receivedChunkCount += 1
            receivingMedia[chunkMessage.mediaId] = mediaState
            
            print("📥 Received chunk \(chunkMessage.chunkIndex + 1)/\(chunkMessage.totalChunks)")
            
            // Check if all chunks received
            if mediaState.isComplete {
                assembleAndSaveReceivedMedia(mediaId: chunkMessage.mediaId, mediaState: mediaState)
            }
            
        } catch {
            print("❌ Failed to process media chunk: \(error)")
        }
    }
    
    private func assembleAndSaveReceivedMedia(mediaId: String, mediaState: MediaReceiveState) {
        print("🔧 Assembling media file: \(mediaState.fileName)")
        
        // Assemble chunks in order
        var completeData = Data()
        for chunkIndex in 0..<mediaState.totalChunks {
            if let chunkData = mediaState.receivedChunks[chunkIndex] {
                completeData.append(chunkData)
            } else {
                print("❌ Missing chunk \(chunkIndex) for \(mediaState.fileName)")
                return
            }
        }
        
        // Save to temporary location
        do {
            let localURL = try saveMediaFileLocally(data: completeData, fileName: mediaState.fileName)
            
            // Create message for received media
            let mediaMessage = ChatMessage(
                id: UUID().uuidString,
                content: mediaState.fileName,
                type: getMessageType(for: mediaState.mimeType),
                isFromCurrentUser: false,
                timestamp: Date(),
                senderId: "peer", // We could track actual sender ID
                status: .delivered,
                mediaURL: localURL,
                fileName: mediaState.fileName,
                fileSize: mediaState.totalSize
            )
            
            DispatchQueue.main.async {
                self.messages.append(mediaMessage)
            }
            
            print("✅ Received media file assembled: \(mediaState.fileName)")
            
            // Clean up
            receivingMedia.removeValue(forKey: mediaId)
            
        } catch {
            print("❌ Failed to save received media: \(error)")
        }
    }
    
    private func getMessageType(for mimeType: String) -> MessageType {
        if mimeType.starts(with: "image/") {
            return .image
        } else if mimeType.starts(with: "video/") {
            return .video
        } else if mimeType.starts(with: "audio/") {
            return .audio
        } else {
            return .file
        }
    }
    
    // MARK: - Cleanup
    
    func cleanupTempMediaFiles() {
        let tempDir = createTempMediaDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
            for file in files {
                try FileManager.default.removeItem(at: file)
                print("🧹 Cleaned up temp file: \(file.lastPathComponent)")
            }
        } catch {
            print("❌ Failed to cleanup temp files: \(error)")
        }
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
    var status: MessageStatus
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

struct MediaChunkMessage: Codable {
    let type: String
    let clientId: String
    let roomId: String
    let mediaId: String
    let chunkIndex: Int
    let totalChunks: Int
    let chunkData: String // Base64 encoded
}

// MARK: - Supporting Types
extension ChatService {
    enum NetworkError: LocalizedError {
        case invalidURL
        case invalidResponse
        case noRoomId
        case noFileURL
        case serverError(Int)
        case allServersFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid server URL"
            case .invalidResponse:
                return "Invalid server response"
            case .noRoomId:
                return "No room ID received from server"
            case .noFileURL:
                return "No file URL received from server"
            case .serverError(let code):
                return "Server error: \(code)"
            case .allServersFailed:
                return "All servers failed to respond"
            }
        }
    }
    
    enum UploadError: LocalizedError {
        case serverNotReady
        case networkError
        case invalidResponse
        
        var errorDescription: String? {
            switch self {
            case .serverNotReady:
                return "Upload feature is deploying to server. Please try again in a few minutes."
            case .networkError:
                return "Network connection issue. Check your internet connection."
            case .invalidResponse:
                return "Server error. Please try again later."
            }
        }
    }
} 