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
        let token: String?
        let clientName: String?

        init(
            Cmd: String? = nil,
            DataOfCmd: String? = nil,
            Option: String? = nil,
            TypeOfRemote: String? = nil,
            token: String? = nil,
            clientName: String? = nil
        ) {
            self.Cmd = Cmd
            self.DataOfCmd = DataOfCmd
            self.Option = Option
            self.TypeOfRemote = TypeOfRemote
            self.token = token
            self.clientName = clientName
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
                token: nil,
                clientName: nil
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
                token: token ?? "None",
                clientName: clientName
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

    /// Create message to launch app
    static func launchApp(appID: String, appType: String = "DEEP_LINK", metaTag: String = "") throws -> AppListMessage {
        let dataDict: [String: Any] = [
            "appId": appID,
            "action_type": appType,
            "metaTag": metaTag
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: dataDict)
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            // This should never happen, but handle gracefully
            return AppListMessage(
                method: "ms.channel.emit",
                params: Params(
                    event: "ed.apps.launch",
                    to: "host",
                    data: ""
                )
            )
        }

        return AppListMessage(
            method: "ms.channel.emit",
            params: Params(
                event: "ed.apps.launch",
                to: "host",
                data: jsonString
            )
        )
    }
}

/// Art mode channel emit message
public struct ArtChannelMessage: Sendable, Codable {
    let method: String
    let params: Params

    struct Params: Sendable, Codable {
        let event: String
        let to: String
        let data: String

        init(event: String, to: String, data: String) {
            self.event = event
            self.to = to
            self.data = data
        }
    }

    /// Create art app request message
    /// - Parameter requestData: Dictionary containing request parameters
    /// - Returns: Encoded art channel message
    static func artAppRequest(_ requestData: [String: Any]) throws -> ArtChannelMessage {
        let jsonData = try JSONSerialization.data(withJSONObject: requestData)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        return ArtChannelMessage(
            method: "ms.channel.emit",
            params: Params(
                event: "art_app_request",
                to: "host",
                data: jsonString
            )
        )
    }
}
