    // Server discovery - try multiple URLs
    private let serverURLs = [
        "https://silento-backend.onrender.com",  // Production
        "http://192.168.68.52:5001",             // Local network (from your terminal output)
        "http://localhost:5001"                  // Localhost
    ]
    
    func createRoom(completion: @escaping (Result<String, Error>) -> Void) {
        guard let serverURL = currentServerURL else {
            completion(.failure(NSError(domain: "NoServer", code: 0, userInfo: [NSLocalizedDescriptionKey: "No server available"])))
            return
        }
        
        guard let url = URL(string: "\(serverURL)/api/create-room") else {
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