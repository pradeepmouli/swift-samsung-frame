// MockTVClient - Mock implementation of TVClientProtocol for unit testing
// Provides configurable responses and captures method calls for verification

import Foundation

/// Mock implementation of TVClientProtocol for testing
///
/// This mock allows tests to verify interactions with the TV client without
/// requiring an actual Samsung TV connection. It captures method calls and
/// provides configurable responses.
///
/// Example usage:
/// ```swift
/// let mock = MockTVClient()
/// mock.connectionStateToReturn = .connected
/// mock.deviceInfoToReturn = TVDevice(id: "test", name: "Test TV", ...)
///
/// let state = await mock.state
/// XCTAssertEqual(state, .connected)
/// XCTAssertTrue(mock.stateAccessCount > 0)
/// ```
public actor MockTVClient: TVClientProtocol {
    
    // MARK: - Configurable Responses
    
    /// Connection state to return from state property
    public var connectionStateToReturn: ConnectionState = .disconnected
    
    /// Device info to return from deviceInfo()
    public var deviceInfoToReturn: TVDevice?
    
    /// Error to throw from connect()
    public var connectError: (any Error)?
    
    /// Error to throw from deviceInfo()
    public var deviceInfoError: (any Error)?
    
    /// Session to return from connect()
    public var sessionToReturn: ConnectionSession?
    
    // MARK: - Call Tracking
    
    /// Number of times connect() was called
    public private(set) var connectCallCount = 0
    
    /// Number of times disconnect() was called
    public private(set) var disconnectCallCount = 0
    
    /// Number of times state was accessed
    public private(set) var stateAccessCount = 0
    
    /// Number of times deviceInfo() was called
    public private(set) var deviceInfoCallCount = 0
    
    /// Last host passed to connect()
    public private(set) var lastConnectHost: String?
    
    /// Last port passed to connect()
    public private(set) var lastConnectPort: Int?
    
    /// Last token storage passed to connect()
    public private(set) var lastTokenStorage: (any TokenStorageProtocol)?
    
    // MARK: - Sub-interfaces
    
    public let remote: any RemoteControlProtocol
    public let apps: any AppManagementProtocol
    public let art: any ArtControllerProtocol
    
    // MARK: - Initialization
    
    public init(
        remote: (any RemoteControlProtocol)? = nil,
        apps: (any AppManagementProtocol)? = nil,
        art: (any ArtControllerProtocol)? = nil
    ) {
        self.remote = remote ?? MockRemoteControl()
        self.apps = apps ?? MockAppManagement()
        self.art = art ?? MockArtController()
    }
    
    // MARK: - TVClientProtocol Implementation
    
    public func connect(
        to host: String,
        port: Int = 8001,
        tokenStorage: (any TokenStorageProtocol)? = nil
    ) async throws -> ConnectionSession {
        connectCallCount += 1
        lastConnectHost = host
        lastConnectPort = port
        lastTokenStorage = tokenStorage
        
        if let error = connectError {
            throw error
        }
        
        if let session = sessionToReturn {
            return session
        }
        
        // Return a default session
        let mockDevice = TVDevice(
            id: "mock-device",
            host: lastConnectHost ?? "192.168.1.100",
            port: lastConnectPort ?? 8001,
            name: "Mock TV"
        )
        return ConnectionSession(device: mockDevice)
    }
    
    public func disconnect() async {
        disconnectCallCount += 1
    }
    
    public var state: ConnectionState {
        get async {
            stateAccessCount += 1
            return connectionStateToReturn
        }
    }
    
    public func deviceInfo() async throws -> TVDevice {
        deviceInfoCallCount += 1
        
        if let error = deviceInfoError {
            throw error
        }
        
        if let device = deviceInfoToReturn {
            return device
        }
        
        // Return a default device
        return TVDevice(
            id: "mock-device",
            host: "192.168.1.100",
            port: 8001,
            name: "Mock TV",
            modelName: "Mock Model",
            macAddress: "00:00:00:00:00:00"
        )
    }
    
    // MARK: - Test Helpers
    
    /// Configure connection state for testing
    public func configure(state: ConnectionState) {
        connectionStateToReturn = state
    }
    
    /// Configure device info for testing
    public func configure(device: TVDevice) {
        deviceInfoToReturn = device
    }
    
    /// Configure connect error for testing
    public func configure(connectError error: (any Error)?) {
        connectError = error
    }
    
    /// Configure session for testing
    public func configure(session: ConnectionSession) {
        sessionToReturn = session
    }
    
    /// Reset all call counters and captured values
    public func reset() {
        connectCallCount = 0
        disconnectCallCount = 0
        stateAccessCount = 0
        deviceInfoCallCount = 0
        lastConnectHost = nil
        lastConnectPort = nil
        lastTokenStorage = nil
    }
}

/// Mock implementation of RemoteControlProtocol
public actor MockRemoteControl: RemoteControlProtocol {
    
    // MARK: - Configurable Responses
    
    /// Error to throw from any command
    public var commandError: (any Error)?
    
    // MARK: - Call Tracking
    
    public private(set) var sendKeyCallCount = 0
    public private(set) var sendKeysCallCount = 0
    public private(set) var powerCallCount = 0
    public private(set) var volumeUpCallCount = 0
    public private(set) var volumeDownCallCount = 0
    public private(set) var muteCallCount = 0
    public private(set) var navigateCallCount = 0
    public private(set) var enterCallCount = 0
    public private(set) var backCallCount = 0
    public private(set) var homeCallCount = 0
    
    public private(set) var lastKeySent: KeyCode?
    public private(set) var lastKeysSent: [KeyCode]?
    public private(set) var lastKeysDelay: Duration?
    public private(set) var lastVolumeUpSteps: Int?
    public private(set) var lastVolumeDownSteps: Int?
    public private(set) var lastNavigateDirection: NavigationDirection?
    
    public init() {}
    
    public func sendKey(_ key: KeyCode) async throws {
        sendKeyCallCount += 1
        lastKeySent = key
        if let error = commandError { throw error }
    }
    
    public func sendKeys(_ keys: [KeyCode], delay: Duration = .milliseconds(100)) async throws {
        sendKeysCallCount += 1
        lastKeysSent = keys
        lastKeysDelay = delay
        if let error = commandError { throw error }
    }
    
    public func power() async throws {
        powerCallCount += 1
        if let error = commandError { throw error }
    }
    
    public func volumeUp(steps: Int = 1) async throws {
        volumeUpCallCount += 1
        lastVolumeUpSteps = steps
        if let error = commandError { throw error }
    }
    
    public func volumeDown(steps: Int = 1) async throws {
        volumeDownCallCount += 1
        lastVolumeDownSteps = steps
        if let error = commandError { throw error }
    }
    
    public func mute() async throws {
        muteCallCount += 1
        if let error = commandError { throw error }
    }
    
    public func navigate(_ direction: NavigationDirection) async throws {
        navigateCallCount += 1
        lastNavigateDirection = direction
        if let error = commandError { throw error }
    }
    
    public func enter() async throws {
        enterCallCount += 1
        if let error = commandError { throw error }
    }
    
    public func back() async throws {
        backCallCount += 1
        if let error = commandError { throw error }
    }
    
    public func home() async throws {
        homeCallCount += 1
        if let error = commandError { throw error }
    }
    
    public func reset() {
        sendKeyCallCount = 0
        sendKeysCallCount = 0
        powerCallCount = 0
        volumeUpCallCount = 0
        volumeDownCallCount = 0
        muteCallCount = 0
        navigateCallCount = 0
        enterCallCount = 0
        backCallCount = 0
        homeCallCount = 0
        lastKeySent = nil
        lastKeysSent = nil
        lastKeysDelay = nil
        lastVolumeUpSteps = nil
        lastVolumeDownSteps = nil
        lastNavigateDirection = nil
    }
}

/// Mock implementation of AppManagementProtocol
public actor MockAppManagement: AppManagementProtocol {
    
    // MARK: - Configurable Responses
    
    public var appsToReturn: [TVApp] = []
    public var statusToReturn: AppStatus = .stopped
    public var listError: (any Error)?
    public var launchError: (any Error)?
    public var closeError: (any Error)?
    public var statusError: (any Error)?
    public var installError: (any Error)?
    
    // MARK: - Call Tracking
    
    public private(set) var listCallCount = 0
    public private(set) var launchCallCount = 0
    public private(set) var closeCallCount = 0
    public private(set) var statusCallCount = 0
    public private(set) var installCallCount = 0
    
    public private(set) var lastLaunchedAppID: String?
    public private(set) var lastClosedAppID: String?
    public private(set) var lastStatusAppID: String?
    public private(set) var lastInstalledAppID: String?
    
    public init() {}
    
    public func list() async throws -> [TVApp] {
        listCallCount += 1
        if let error = listError { throw error }
        return appsToReturn
    }
    
    public func launch(_ appID: String) async throws {
        launchCallCount += 1
        lastLaunchedAppID = appID
        if let error = launchError { throw error }
    }
    
    public func close(_ appID: String) async throws {
        closeCallCount += 1
        lastClosedAppID = appID
        if let error = closeError { throw error }
    }
    
    public func status(of appID: String) async throws -> AppStatus {
        statusCallCount += 1
        lastStatusAppID = appID
        if let error = statusError { throw error }
        return statusToReturn
    }
    
    public func install(_ appID: String) async throws {
        installCallCount += 1
        lastInstalledAppID = appID
        if let error = installError { throw error }
    }
    
    public func reset() {
        listCallCount = 0
        launchCallCount = 0
        closeCallCount = 0
        statusCallCount = 0
        installCallCount = 0
        lastLaunchedAppID = nil
        lastClosedAppID = nil
        lastStatusAppID = nil
        lastInstalledAppID = nil
    }
}

/// Mock implementation of ArtControllerProtocol
public actor MockArtController: ArtControllerProtocol {
    
    // MARK: - Configurable Responses
    
    public var isSupportedToReturn = true
    public var artPiecesToReturn: [ArtPiece] = []
    public var currentArtToReturn: ArtPiece?
    public var uploadedArtIDToReturn: String?
    public var thumbnailToReturn: Data?
    public var isArtModeActiveToReturn = false
    public var filtersToReturn: [PhotoFilter] = []
    
    public var isSupportedError: (any Error)?
    public var listError: (any Error)?
    public var currentError: (any Error)?
    public var selectError: (any Error)?
    public var uploadError: (any Error)?
    public var deleteError: (any Error)?
    public var deleteMultipleError: (any Error)?
    public var thumbnailError: (any Error)?
    public var isArtModeActiveError: (any Error)?
    public var setArtModeError: (any Error)?
    public var filtersError: (any Error)?
    public var applyFilterError: (any Error)?
    
    // MARK: - Call Tracking
    
    public private(set) var isSupportedCallCount = 0
    public private(set) var listCallCount = 0
    public private(set) var currentCallCount = 0
    public private(set) var selectCallCount = 0
    public private(set) var uploadCallCount = 0
    public private(set) var deleteCallCount = 0
    public private(set) var deleteMultipleCallCount = 0
    public private(set) var thumbnailCallCount = 0
    public private(set) var isArtModeActiveCallCount = 0
    public private(set) var setArtModeCallCount = 0
    public private(set) var filtersCallCount = 0
    public private(set) var applyFilterCallCount = 0
    
    public private(set) var lastSelectedArtID: String?
    public private(set) var lastSelectedShow: Bool?
    public private(set) var lastUploadedImageData: Data?
    public private(set) var lastUploadedImageType: ImageType?
    public private(set) var lastUploadedMatte: MatteStyle?
    public private(set) var lastDeletedArtID: String?
    public private(set) var lastDeletedMultipleIDs: [String]?
    public private(set) var lastThumbnailArtID: String?
    public private(set) var lastSetArtModeEnabled: Bool?
    public private(set) var lastAppliedFilter: PhotoFilter?
    public private(set) var lastAppliedFilterArtID: String?
    
    public init() {}
    
    public func isSupported() async throws -> Bool {
        isSupportedCallCount += 1
        if let error = isSupportedError { throw error }
        return isSupportedToReturn
    }
    
    public func listAvailable() async throws -> [ArtPiece] {
        listCallCount += 1
        if let error = listError { throw error }
        return artPiecesToReturn
    }
    
    public func current() async throws -> ArtPiece {
        currentCallCount += 1
        if let error = currentError { throw error }
        if let art = currentArtToReturn {
            return art
        }
        throw TVError.deviceNotFound(id: "mock-art")
    }
    
    public func select(_ artID: String, show: Bool = false) async throws {
        selectCallCount += 1
        lastSelectedArtID = artID
        lastSelectedShow = show
        if let error = selectError { throw error }
    }
    
    public func upload(
        _ imageData: Data,
        type imageType: ImageType,
        matte: MatteStyle?
    ) async throws -> String {
        uploadCallCount += 1
        lastUploadedImageData = imageData
        lastUploadedImageType = imageType
        lastUploadedMatte = matte
        if let error = uploadError { throw error }
        return uploadedArtIDToReturn ?? "mock-art-id"
    }
    
    public func delete(_ artID: String) async throws {
        deleteCallCount += 1
        lastDeletedArtID = artID
        if let error = deleteError { throw error }
    }
    
    public func deleteMultiple(_ artIDs: [String]) async throws {
        deleteMultipleCallCount += 1
        lastDeletedMultipleIDs = artIDs
        if let error = deleteMultipleError { throw error }
    }
    
    public func thumbnail(for artID: String) async throws -> Data {
        thumbnailCallCount += 1
        lastThumbnailArtID = artID
        if let error = thumbnailError { throw error }
        return thumbnailToReturn ?? Data()
    }
    
    public func isArtModeActive() async throws -> Bool {
        isArtModeActiveCallCount += 1
        if let error = isArtModeActiveError { throw error }
        return isArtModeActiveToReturn
    }
    
    public func setArtMode(enabled: Bool) async throws {
        setArtModeCallCount += 1
        lastSetArtModeEnabled = enabled
        if let error = setArtModeError { throw error }
    }
    
    public func availableFilters() async throws -> [PhotoFilter] {
        filtersCallCount += 1
        if let error = filtersError { throw error }
        return filtersToReturn
    }
    
    public func applyFilter(_ filter: PhotoFilter, to artID: String) async throws {
        applyFilterCallCount += 1
        lastAppliedFilter = filter
        lastAppliedFilterArtID = artID
        if let error = applyFilterError { throw error }
    }
    
    public func reset() {
        isSupportedCallCount = 0
        listCallCount = 0
        currentCallCount = 0
        selectCallCount = 0
        uploadCallCount = 0
        deleteCallCount = 0
        deleteMultipleCallCount = 0
        thumbnailCallCount = 0
        isArtModeActiveCallCount = 0
        setArtModeCallCount = 0
        filtersCallCount = 0
        applyFilterCallCount = 0
        lastSelectedArtID = nil
        lastSelectedShow = nil
        lastUploadedImageData = nil
        lastUploadedImageType = nil
        lastUploadedMatte = nil
        lastDeletedArtID = nil
        lastDeletedMultipleIDs = nil
        lastThumbnailArtID = nil
        lastSetArtModeEnabled = nil
        lastAppliedFilter = nil
        lastAppliedFilterArtID = nil
    }
}
