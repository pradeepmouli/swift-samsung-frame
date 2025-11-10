// WebSocketMessage - WebSocket message encoding/decoding
// Handles Samsung TV WebSocket protocol message formats

import Foundation

/// WebSocket message types for Samsung TV communication
public struct WebSocketMessage: Sendable, Codable {
    let method: String
    let params: Params
    
    struct Params: Sendable, Codable {
        let Cmd: String?
        let DataOfCmd: String?
        let Option: String?
        let TypeOfRemote: String?
        let Token: String?
        let name: String?
        
        init(
            Cmd: String? = nil,
            DataOfCmd: String? = nil,
            Option: String? = nil,
            TypeOfRemote: String? = nil,
            Token: String? = nil,
            name: String? = nil
        ) {
            self.Cmd = Cmd
            self.DataOfCmd = DataOfCmd
            self.Option = Option
            self.TypeOfRemote = TypeOfRemote
            self.Token = Token
            self.name = name
        }
    }
    
    /// Create a remote control command message
    static func remoteControl(key: String, type: String = "Click") -> WebSocketMessage {
        WebSocketMessage(
            method: "ms.remote.control",
            params: Params(
                Cmd: type,
                DataOfCmd: key,
                Option: "false",
                TypeOfRemote: "SendRemoteKey",
                Token: nil,
                name: nil
            )
        )
    }
    
    /// Create an authentication message
    static func authentication(token: String?, clientName: String = "SwiftSamsungFrame") -> WebSocketMessage {
        WebSocketMessage(
            method: "ms.channel.connect",
            params: Params(
                Cmd: nil,
                DataOfCmd: nil,
                Option: nil,
                TypeOfRemote: nil,
                Token: token,
                name: clientName
            )
        )
    }
}

/// WebSocket response message
public struct WebSocketResponse: Sendable, Codable {
    let event: String?
    let data: ResponseData?
    
    struct ResponseData: Sendable, Codable {
        let token: String?
        let name: String?
        let id: String?
        let clients: [Client]?
        
        struct Client: Sendable, Codable {
            let id: String
            let name: String
        }
    }
}

/// App list message
public struct AppListMessage: Sendable, Codable {
    let method: String
    let params: Params
    
    struct Params: Sendable, Codable {
        let event: String
        let to: String
        let data: String?
        
        init(event: String, to: String, data: String? = nil) {
            self.event = event
            self.to = to
            self.data = data
        }
    }
    
    /// Create message to get app list
    static func getAppList() -> AppListMessage {
        AppListMessage(
            method: "ms.channel.emit",
            params: Params(
                event: "ed.installedApp.get",
                to: "host",
                data: nil
            )
        )
    }
}

/// Art mode message
public struct ArtMessage: Sendable, Codable {
    let method: String
    let params: Params
    
    struct Params: Sendable, Codable {
        let event: String
        let to: String
        let data: DataParams?
        
        struct DataParams: Sendable, Codable {
            let content_id: String?
            let category: String?
            
            init(content_id: String? = nil, category: String? = nil) {
                self.content_id = content_id
                self.category = category
            }
        }
        
        init(event: String, to: String, data: DataParams? = nil) {
            self.event = event
            self.to = to
            self.data = data
        }
    }
    
    /// Create message to get art list
    static func getArtList() -> ArtMessage {
        ArtMessage(
            method: "ms.channel.emit",
            params: Params(
                event: "art_list",
                to: "host",
                data: nil
            )
        )
    }
    
    /// Create message to select art
    static func selectArt(contentID: String) -> ArtMessage {
        ArtMessage(
            method: "ms.channel.emit",
            params: Params(
                event: "art_select",
                to: "host",
                data: Params.DataParams(
                    content_id: contentID,
                    category: nil
                )
            )
        )
    }
}
