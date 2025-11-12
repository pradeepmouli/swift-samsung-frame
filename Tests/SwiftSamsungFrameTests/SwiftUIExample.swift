// SwiftUIExample - SwiftUI integration examples for SwiftSamsungFrame
// Demonstrates how to build SwiftUI apps that control Samsung TVs

#if canImport(SwiftUI)
import SwiftUI
import SwiftSamsungFrame

// MARK: - Example 1: Basic Remote Control View

/// Simple remote control interface using SwiftUI
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct BasicRemoteView: View {
    @StateObject private var viewModel = TVRemoteViewModel()
    
    var body: some View {
        VStack(spacing: 20) {
            // Connection status
            Text(viewModel.connectionState.description)
                .font(.headline)
                .foregroundColor(viewModel.connectionState == .connected ? .green : .gray)
            
            // Error message
            if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            // Power button
            Button(action: {
                Task { await viewModel.sendPowerCommand() }
            }) {
                Label("Power", systemImage: "power")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.isConnected)
            
            // Volume controls
            HStack {
                Button(action: {
                    Task { await viewModel.sendVolumeDown() }
                }) {
                    Label("Volume -", systemImage: "speaker.wave.1")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    Task { await viewModel.sendMute() }
                }) {
                    Label("Mute", systemImage: "speaker.slash")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    Task { await viewModel.sendVolumeUp() }
                }) {
                    Label("Volume +", systemImage: "speaker.wave.3")
                }
                .buttonStyle(.bordered)
            }
            .disabled(!viewModel.isConnected)
            
            // Navigation pad
            VStack(spacing: 10) {
                Button(action: {
                    Task { await viewModel.navigate(.up) }
                }) {
                    Image(systemName: "chevron.up")
                        .frame(width: 60, height: 40)
                }
                .buttonStyle(.bordered)
                
                HStack(spacing: 10) {
                    Button(action: {
                        Task { await viewModel.navigate(.left) }
                    }) {
                        Image(systemName: "chevron.left")
                            .frame(width: 40, height: 60)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        Task { await viewModel.sendEnter() }
                    }) {
                        Text("OK")
                            .frame(width: 60, height: 60)
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button(action: {
                        Task { await viewModel.navigate(.right) }
                    }) {
                        Image(systemName: "chevron.right")
                            .frame(width: 40, height: 60)
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: {
                    Task { await viewModel.navigate(.down) }
                }) {
                    Image(systemName: "chevron.down")
                        .frame(width: 60, height: 40)
                }
                .buttonStyle(.bordered)
            }
            .disabled(!viewModel.isConnected)
            
            // Back and Home buttons
            HStack {
                Button(action: {
                    Task { await viewModel.sendBack() }
                }) {
                    Label("Back", systemImage: "arrowshape.turn.up.backward")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    Task { await viewModel.sendHome() }
                }) {
                    Label("Home", systemImage: "house")
                }
                .buttonStyle(.bordered)
            }
            .disabled(!viewModel.isConnected)
        }
        .padding()
        .task {
            // Auto-connect when view appears
            await viewModel.connect(to: "192.168.1.100")
        }
    }
}

// MARK: - View Model

/// ViewModel for managing TV remote control state
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
@MainActor
class TVRemoteViewModel: ObservableObject {
    @Published var connectionState: ConnectionState = .disconnected
    @Published var errorMessage: String?
    @Published var deviceName: String?
    
    private let client = TVClient()
    private let storage = KeychainTokenStorage()
    
    var isConnected: Bool {
        connectionState == .connected
    }
    
    func connect(to host: String) async {
        connectionState = .connecting
        errorMessage = nil
        
        do {
            _ = try await client.connect(to: host, tokenStorage: storage)
            connectionState = .connected
            
            // Fetch device info
            let device = try await client.deviceInfo()
            deviceName = device.name
        } catch {
            errorMessage = error.localizedDescription
            connectionState = .error
        }
    }
    
    func disconnect() async {
        await client.disconnect()
        connectionState = .disconnected
        deviceName = nil
    }
    
    // MARK: - Remote Commands
    
    func sendPowerCommand() async {
        await sendCommand { try await $0.remote.power() }
    }
    
    func sendVolumeUp() async {
        await sendCommand { try await $0.remote.volumeUp(steps: 1) }
    }
    
    func sendVolumeDown() async {
        await sendCommand { try await $0.remote.volumeDown(steps: 1) }
    }
    
    func sendMute() async {
        await sendCommand { try await $0.remote.mute() }
    }
    
    func navigate(_ direction: NavigationDirection) async {
        await sendCommand { try await $0.remote.navigate(direction) }
    }
    
    func sendEnter() async {
        await sendCommand { try await $0.remote.enter() }
    }
    
    func sendBack() async {
        await sendCommand { try await $0.remote.back() }
    }
    
    func sendHome() async {
        await sendCommand { try await $0.remote.home() }
    }
    
    private func sendCommand(_ action: @escaping (TVClient) async throws -> Void) async {
        do {
            try await action(client)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Example 2: App Launcher View

/// SwiftUI view for browsing and launching TV apps
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct AppLauncherView: View {
    @StateObject private var viewModel = AppLauncherViewModel()
    
    var body: some View {
        NavigationView {
            List(viewModel.apps) { app in
                HStack {
                    VStack(alignment: .leading) {
                        Text(app.name)
                            .font(.headline)
                        if let version = app.version {
                            Text("Version \(version)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Launch") {
                        Task {
                            await viewModel.launch(app)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .navigationTitle("TV Apps")
            .refreshable {
                await viewModel.loadApps()
            }
            .task {
                await viewModel.connect(to: "192.168.1.100")
                await viewModel.loadApps()
            }
        }
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
@MainActor
class AppLauncherViewModel: ObservableObject {
    @Published var apps: [TVApp] = []
    @Published var errorMessage: String?
    
    private let client = TVClient()
    
    func connect(to host: String) async {
        do {
            _ = try await client.connect(to: host)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadApps() async {
        do {
            apps = try await client.apps.list()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func launch(_ app: TVApp) async {
        do {
            try await client.apps.launch(app.id)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Example 3: Art Gallery View (Frame TVs)

/// SwiftUI gallery for browsing and selecting art on Frame TVs
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ArtGalleryView: View {
    @StateObject private var viewModel = ArtGalleryViewModel()
    
    let columns = [
        GridItem(.adaptive(minimum: 150))
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                if !viewModel.isSupported {
                    Text("Art Mode not supported on this TV")
                        .foregroundColor(.secondary)
                        .padding()
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(viewModel.artPieces) { art in
                            ArtPieceCard(art: art) {
                                await viewModel.select(art)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Art Gallery")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(viewModel.isArtModeActive ? "Exit Art Mode" : "Enter Art Mode") {
                        Task {
                            await viewModel.toggleArtMode()
                        }
                    }
                    .disabled(!viewModel.isSupported)
                }
            }
            .task {
                await viewModel.connect(to: "192.168.1.100")
                await viewModel.loadArt()
            }
        }
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ArtPieceCard: View {
    let art: ArtPiece
    let onSelect: () async -> Void
    
    var body: some View {
        VStack {
            // Placeholder for art thumbnail
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: "photo")
                        .foregroundColor(.gray)
                        .font(.largeTitle)
                )
            
            Text(art.title)
                .font(.caption)
                .lineLimit(1)
            
            Button("Select") {
                Task {
                    await onSelect()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
@MainActor
class ArtGalleryViewModel: ObservableObject {
    @Published var artPieces: [ArtPiece] = []
    @Published var isSupported = false
    @Published var isArtModeActive = false
    @Published var errorMessage: String?
    
    private let client = TVClient()
    
    func connect(to host: String) async {
        do {
            _ = try await client.connect(to: host)
            isSupported = try await client.art.isSupported()
            if isSupported {
                isArtModeActive = try await client.art.isArtModeActive()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func loadArt() async {
        guard isSupported else { return }
        
        do {
            artPieces = try await client.art.listAvailable()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func select(_ art: ArtPiece) async {
        do {
            try await client.art.select(art.id, show: true)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func toggleArtMode() async {
        do {
            try await client.art.setArtMode(enabled: !isArtModeActive)
            isArtModeActive.toggle()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Example 4: Device Discovery View

#if canImport(Network)
/// SwiftUI view for discovering TVs on the network
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct DeviceDiscoveryView: View {
    @StateObject private var viewModel = DiscoveryViewModel()
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.discoveredDevices) { device in
                    VStack(alignment: .leading) {
                        Text(device.name)
                            .font(.headline)
                        Text(device.host)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(device.modelName ?? "")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Discovered TVs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(viewModel.isScanning ? "Stop" : "Scan") {
                        Task {
                            if viewModel.isScanning {
                                await viewModel.stopScanning()
                            } else {
                                await viewModel.startScanning()
                            }
                        }
                    }
                }
            }
            .overlay {
                if viewModel.isScanning {
                    ProgressView("Scanning for TVs...")
                }
            }
        }
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
@MainActor
class DiscoveryViewModel: ObservableObject {
    @Published var discoveredDevices: [TVDevice] = []
    @Published var isScanning = false
    
    private let discovery = DiscoveryService()
    private var scanningTask: Task<Void, Never>?
    
    func startScanning() async {
        isScanning = true
        discoveredDevices.removeAll()
        
        scanningTask = Task {
            for await result in discovery.discover(timeout: .seconds(10)) {
                // Check if device already discovered
                if !discoveredDevices.contains(where: { $0.id == result.device.id }) {
                    discoveredDevices.append(result.device)
                }
            }
            isScanning = false
        }
    }
    
    func stopScanning() async {
        scanningTask?.cancel()
    discovery.cancel()
        isScanning = false
    }
}
#endif

// MARK: - Example 5: Connection State Indicator

/// Reusable connection status indicator
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ConnectionStatusView: View {
    let state: ConnectionState
    
    var body: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            
            Text(state.description)
                .font(.caption)
        }
    }
    
    private var statusColor: Color {
        switch state {
        case .connected:
            return .green
        case .connecting, .authenticating:
            return .yellow
        case .disconnecting:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
}

// MARK: - ConnectionState Extension

extension ConnectionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .disconnected:
            return "Disconnected"
        case .connecting:
            return "Connecting..."
        case .authenticating:
            return "Authenticating..."
        case .connected:
            return "Connected"
        case .disconnecting:
            return "Disconnecting..."
        case .error:
            return "Error"
        }
    }
}

// MARK: - Preview Providers

#if DEBUG
@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct BasicRemoteView_Previews: PreviewProvider {
    static var previews: some View {
        BasicRemoteView()
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct AppLauncherView_Previews: PreviewProvider {
    static var previews: some View {
        AppLauncherView()
    }
}

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ArtGalleryView_Previews: PreviewProvider {
    static var previews: some View {
        ArtGalleryView()
    }
}

#if canImport(Network)
@available(iOS 18.0, macOS 15.0, tvOS 18.0, *)
struct DeviceDiscoveryView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceDiscoveryView()
    }
}
#endif

@available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
struct ConnectionStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 10) {
            ConnectionStatusView(state: .disconnected)
            ConnectionStatusView(state: .connecting)
            ConnectionStatusView(state: .connected)
            ConnectionStatusView(state: .error)
        }
        .padding()
    }
}
#endif
#endif
