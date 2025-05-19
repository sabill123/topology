import Foundation
import Combine

class WebSocketService: NSObject {
    static let shared = WebSocketService()
    
    // Published events
    @Published var connectionState: ConnectionState = .disconnected
    @Published var receivedMessage = PassthroughSubject<WebSocketMessage, Never>()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    enum ConnectionState {
        case connected
        case connecting
        case disconnected
        case reconnecting
    }
    
    private override init() {
        let configuration = URLSessionConfiguration.default
        self.session = URLSession(configuration: configuration)
        super.init()
    }
    
    // MARK: - Connection
    
    func connect() {
        guard connectionState != .connected && connectionState != .connecting else { return }
        
        connectionState = .connecting
        reconnectAttempts = 0
        
        guard let accessToken = UserDefaults.standard.string(forKey: "accessToken"),
              let url = URL(string: "ws://172.30.1.87:8080/ws?token=\(accessToken)") else {
            print("WebSocket: Invalid URL or missing token")
            connectionState = .disconnected
            return
        }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Start listening for messages
        listenForMessages()
        
        // Start ping timer
        startPingTimer()
        
        // Send initial connection message
        send(message: WebSocketMessage(type: "connection", data: [:]))
    }
    
    func disconnect() {
        connectionState = .disconnected
        stopTimers()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }
    
    // MARK: - Message Handling
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleTextMessage(text)
                case .data(let data):
                    self?.handleDataMessage(data)
                @unknown default:
                    break
                }
                
                // Continue listening
                self?.listenForMessages()
                
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.handleConnectionError()
            }
        }
    }
    
    private func handleTextMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let message = try? JSONDecoder().decode(WebSocketMessage.self, from: data) else {
            print("WebSocket: Failed to decode message")
            return
        }
        
        // Handle specific message types
        switch message.type {
        case "connection_established":
            connectionState = .connected
            reconnectAttempts = 0
            print("WebSocket: Connected")
            
        case "pong":
            // Pong received, connection is alive
            break
            
        case "error":
            if let errorMessage = message.data["message"] as? String {
                print("WebSocket error: \(errorMessage)")
            }
            
        default:
            // Forward message to subscribers
            receivedMessage.send(message)
        }
    }
    
    private func handleDataMessage(_ data: Data) {
        // Handle binary data if needed
        print("WebSocket: Received binary data")
    }
    
    // MARK: - Send Messages
    
    func send(message: WebSocketMessage) {
        guard connectionState == .connected else {
            print("WebSocket: Not connected, cannot send message")
            return
        }
        
        do {
            let data = try JSONEncoder().encode(message)
            let string = String(data: data, encoding: .utf8)!
            
            webSocketTask?.send(.string(string)) { [weak self] error in
                if let error = error {
                    print("WebSocket send error: \(error)")
                    self?.handleConnectionError()
                }
            }
        } catch {
            print("WebSocket: Failed to encode message")
        }
    }
    
    // MARK: - Specific Message Types
    
    func sendTypingIndicator(to userId: String, isTyping: Bool = true) {
        send(message: WebSocketMessage(
            type: "typing",
            data: [
                "target_user_id": userId,
                "is_typing": isTyping
            ]
        ))
    }
    
    func sendMessage(to userId: String, content: String) {
        send(message: WebSocketMessage(
            type: "message",
            data: [
                "receiver_id": userId,
                "content": content
            ]
        ))
    }
    
    func sendCallSignal(callId: String, targetUserId: String, signalData: [String: Any]) {
        send(message: WebSocketMessage(
            type: "call_signal",
            data: [
                "call_id": callId,
                "target_user_id": targetUserId,
                "signal_data": signalData
            ]
        ))
    }
    
    func sendICECandidate(callId: String, targetUserId: String, candidate: [String: Any]) {
        send(message: WebSocketMessage(
            type: "ice_candidate",
            data: [
                "call_id": callId,
                "target_user_id": targetUserId,
                "candidate": candidate
            ]
        ))
    }
    
    // MARK: - Connection Management
    
    private func handleConnectionError() {
        connectionState = .disconnected
        stopTimers()
        attemptReconnect()
    }
    
    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("WebSocket: Max reconnection attempts reached")
            return
        }
        
        connectionState = .reconnecting
        reconnectAttempts += 1
        
        let delay = Double(reconnectAttempts) * 2.0 // Exponential backoff
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("WebSocket: Attempting reconnect \(self?.reconnectAttempts ?? 0)/\(self?.maxReconnectAttempts ?? 0)")
            self?.connect()
        }
    }
    
    // MARK: - Ping/Pong
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.sendPing()
        }
    }
    
    private func sendPing() {
        send(message: WebSocketMessage(
            type: "ping",
            data: ["timestamp": Date().timeIntervalSince1970]
        ))
    }
    
    private func stopTimers() {
        pingTimer?.invalidate()
        pingTimer = nil
        reconnectTimer?.invalidate()
        reconnectTimer = nil
    }
}

// MARK: - WebSocket Message Model

struct WebSocketMessage: Codable {
    let type: String
    let data: [String: Any]
    
    enum CodingKeys: String, CodingKey {
        case type
        case data
    }
    
    init(type: String, data: [String: Any]) {
        self.type = type
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        
        // Decode JSON as dictionary
        if let dataDict = try? container.decode([String: AnyCodable].self, forKey: .data) {
            self.data = dataDict.mapValues { $0.value }
        } else {
            self.data = [:]
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        // Encode dictionary as JSON
        let anyCodableData = data.mapValues { AnyCodable($0) }
        try container.encode(anyCodableData, forKey: .data)
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            value = NSNull()
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            try container.encodeNil()
        }
    }
}