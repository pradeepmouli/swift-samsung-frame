import Foundation

/// WebSocket message sent to/from Samsung TV
struct WebSocketMessage: Codable {
    let method: String
    let params: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case method
        case params
    }
}

/// WebSocket command message
struct WebSocketCommand: Codable, Sendable {
    let method: String
    let params: CommandParams
    
    struct CommandParams: Codable, Sendable {
        let cmd: String
        let dataOfCmd: String
        let option: String
        let typeOfRemote: String
        
        init(cmd: String, dataOfCmd: String, option: String = "false", typeOfRemote: String = "SendRemoteKey") {
            self.cmd = cmd
            self.dataOfCmd = dataOfCmd
            self.option = option
            self.typeOfRemote = typeOfRemote
        }
    }
    
    init(params: CommandParams) {
        self.method = "ms.remote.control"
        self.params = params
    }
}

/// WebSocket authentication message
struct WebSocketAuthMessage: Codable, Sendable {
    let method: String
    let params: AuthParams
    
    struct AuthParams: Codable, Sendable {
        let name: String
        let token: String?
        
        init(name: String, token: String? = nil) {
            self.name = name
            self.token = token
        }
    }
    
    init(params: AuthParams) {
        self.method = "ms.channel.connect"
        self.params = params
    }
}

/// WebSocket authentication response
struct WebSocketAuthResponse: Codable, Sendable {
    let event: String
    let data: AuthResponseData?
    
    struct AuthResponseData: Codable, Sendable {
        let token: String?
        let clients: [[String: String]]?
    }
}
