# Tasks: Samsung TV Client Library

**Input**: Design documents from `/specs/001-samsung-tv-client/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US4)
- Include exact file paths in descriptions

## User Story Priorities

From spec.md:
- **P1**: User Story 1 (Basic TV Control), User Story 4 (Connection Management) - MVP
- **P2**: User Story 2 (Application Management), User Story 5 (Device Discovery)
- **P3**: User Story 3 (Art Mode Control for Frame TVs)

**Implementation Strategy**: Build P1 stories first (MVP), then P2, then P3. Each story should be independently testable.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Verify Package.swift has correct Swift tools version (6.2+), platform targets, and upcoming features (ExistentialAny, StrictConcurrency)
- [ ] T002 Create base directory structure: Sources/SwiftSamsungFrame/{Client,Commands,Apps,Art,Discovery,Models,Protocols,Networking,Extensions}
- [ ] T003 Create test directory structure: Tests/SwiftSamsungFrameTests/{Unit/{ClientTests,CommandsTests,AppsTests,ArtTests,DiscoveryTests},Integration/EndToEndTests}
- [ ] T004 [P] Configure .gitignore for Swift Package Manager (.build/, .swiftpm/, *.xcodeproj, .DS_Store)
- [ ] T005 [P] Add .swiftlint.yml with Swift 6 concurrency rules and project conventions

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 [P] Define all enumerations in Sources/SwiftSamsungFrame/Models/Enumerations.swift (ConnectionState, TVFeature, APIVersion, AppStatus, ArtCategory, ImageType, MatteStyle, PhotoFilter, CommandType, DiscoveryMethod, TokenScope, KeyCode)
- [ ] T007 [P] Define TVError enum in Sources/SwiftSamsungFrame/Models/TVError.swift with all 12 error cases
- [ ] T008 [P] Create NavigationDirection enum in Sources/SwiftSamsungFrame/Models/NavigationDirection.swift (up, down, left, right)
- [ ] T009 [P] Create Duration extension in Sources/SwiftSamsungFrame/Extensions/Duration+Extensions.swift with milliseconds() and seconds() helpers
- [ ] T010 [P] Define TVDevice struct in Sources/SwiftSamsungFrame/Models/TVDevice.swift conforming to Sendable, Identifiable, Hashable, Codable
- [ ] T011 [P] Define ConnectionSession class in Sources/SwiftSamsungFrame/Models/ConnectionSession.swift with Actor isolation for thread safety
- [ ] T012 [P] Define AuthenticationToken struct in Sources/SwiftSamsungFrame/Models/AuthenticationToken.swift with Keychain-safe Codable implementation
- [ ] T013 [P] Define RemoteCommand struct in Sources/SwiftSamsungFrame/Models/RemoteCommand.swift
- [ ] T014 [P] Define TVApp struct in Sources/SwiftSamsungFrame/Models/TVApp.swift conforming to Sendable, Identifiable, Hashable, Codable
- [ ] T015 [P] Define ArtPiece struct in Sources/SwiftSamsungFrame/Models/ArtPiece.swift conforming to Sendable, Identifiable, Hashable, Codable
- [ ] T016 [P] Define DiscoveryResult struct in Sources/SwiftSamsungFrame/Models/DiscoveryResult.swift
- [ ] T017 Define all core protocols in Sources/SwiftSamsungFrame/Protocols/CoreProtocols.swift (TVClientProtocol, RemoteControlProtocol, AppManagementProtocol, ArtControllerProtocol, DiscoveryServiceProtocol, TokenStorageProtocol, TVClientDelegate)
- [ ] T018 [P] Create OSLog categories in Sources/SwiftSamsungFrame/Extensions/Logger+Extensions.swift (connection, commands, apps, art, discovery, networking)
- [ ] T019 Implement TokenStorageProtocol default implementation (KeychainTokenStorage) in Sources/SwiftSamsungFrame/Client/KeychainTokenStorage.swift using Security framework

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 4 - Connection Management (Priority: P1) 🎯 MVP

**Goal**: Establish secure connections to Samsung TVs, handle authentication tokens, manage persistent sessions, and gracefully handle network errors.

**Independent Test**: Connect to a TV (triggering pairing if needed), persist the auth token, reconnect with the saved token, and handle disconnection scenarios. Success is verified when connections are established, maintained, and gracefully terminated.

**Why First**: Connection management is fundamental infrastructure required for all other features. Without stable connection handling, no TV operations can be performed reliably.

### Implementation for User Story 4

- [ ] T020 [P] [US4] Create WebSocketClient actor in Sources/SwiftSamsungFrame/Networking/WebSocketClient.swift managing URLSessionWebSocketTask with async/await
- [ ] T021 [P] [US4] Implement WebSocket message encoding/decoding in Sources/SwiftSamsungFrame/Networking/WebSocketMessage.swift (JSON command format, auth response format)
- [ ] T022 [P] [US4] Create RESTClient class in Sources/SwiftSamsungFrame/Networking/RESTClient.swift using URLSession for HTTP requests
- [ ] T023 [US4] Implement TVClient class in Sources/SwiftSamsungFrame/Client/TVClient.swift conforming to TVClientProtocol
- [ ] T024 [US4] Implement connect() method with TLS certificate handling (self-signed cert acceptance) in TVClient
- [ ] T025 [US4] Implement authentication flow (token exchange, pairing prompt handling) in TVClient
- [ ] T026 [US4] Implement disconnect() method with graceful WebSocket closure in TVClient
- [ ] T027 [US4] Implement state property with async access to connection state in TVClient
- [ ] T028 [US4] Implement connection health check (ping/pong every 30s) in WebSocketClient
- [ ] T029 [US4] Add reconnection logic with exponential backoff (1s, 2s, 4s) in TVClient
- [ ] T030 [US4] Implement TVClientDelegate callback system for state changes in TVClient
- [ ] T031 [US4] Add error handling for all connection scenarios (timeout, auth failed, network unreachable) in TVClient
- [ ] T032 [US4] Add comprehensive doc comments (///) for all public TVClient APIs
- [ ] T033 [US4] Add logging with OSLog for connection lifecycle events

**Checkpoint**: At this point, User Story 4 should be fully functional - can connect, authenticate, persist tokens, and reconnect

---

## Phase 4: User Story 1 - Basic TV Control (Priority: P1) 🎯 MVP

**Goal**: Send basic remote control commands (power, volume, navigation, channel) to Samsung TVs to enable fundamental TV control functionality.

**Independent Test**: Connect to a Samsung TV and send power on/off, volume up/down, and navigation commands. Success is verified when the TV responds to each command correctly.

**Why Second**: Basic remote control is the foundation value proposition. With US4 (connection) and US1 (control), we have a minimal viable product.

**Dependencies**: Requires US4 (Connection Management) to be complete.

### Implementation for User Story 1

- [ ] T034 [P] [US1] Create RemoteControl class in Sources/SwiftSamsungFrame/Commands/RemoteControl.swift conforming to RemoteControlProtocol
- [ ] T035 [US1] Implement sendKey() method formatting and sending WebSocket command messages in RemoteControl
- [ ] T036 [US1] Implement sendKeys() method with configurable delay between commands in RemoteControl
- [ ] T037 [P] [US1] Implement power() convenience method in RemoteControl
- [ ] T038 [P] [US1] Implement volumeUp() and volumeDown() methods with steps parameter in RemoteControl
- [ ] T039 [P] [US1] Implement mute() method in RemoteControl
- [ ] T040 [P] [US1] Implement navigate() method accepting NavigationDirection in RemoteControl
- [ ] T041 [P] [US1] Implement enter(), back(), and home() convenience methods in RemoteControl
- [ ] T042 [US1] Integrate RemoteControl as property in TVClient (var remote: RemoteControlProtocol)
- [ ] T043 [US1] Add command timeout handling (5 second timeout) in RemoteControl
- [ ] T044 [US1] Add command retry logic (retry once after 500ms) in RemoteControl
- [ ] T045 [US1] Implement deviceInfo() method in TVClient using REST API endpoint
- [ ] T046 [US1] Add comprehensive doc comments (///) for all public RemoteControl APIs
- [ ] T047 [US1] Add logging with OSLog for command execution

**Checkpoint**: At this point, both US4 and US1 work together - full MVP with connection + basic control

---

## Phase 5: User Story 5 - Device Discovery (Priority: P2)

**Goal**: Discover Samsung TVs on the local network using mDNS/Bonjour to enable automatic TV detection without requiring users to manually enter IP addresses.

**Independent Test**: Scan the local network and verify that Samsung TVs are detected with their IP addresses, model names, and capabilities. Success is confirmed when known TVs on the network appear in the discovery results.

**Dependencies**: None - can be implemented independently of connection/control.

### Implementation for User Story 5

- [ ] T048 [P] [US5] Create DiscoveryService class in Sources/SwiftSamsungFrame/Discovery/DiscoveryService.swift conforming to DiscoveryServiceProtocol
- [ ] T049 [P] [US5] Implement mDNS browser using Network framework NWBrowser in Sources/SwiftSamsungFrame/Discovery/MDNSBrowser.swift
- [ ] T050 [P] [US5] Implement SSDP discovery using NWConnection for UDP multicast in Sources/SwiftSamsungFrame/Discovery/SSDPBrowser.swift
- [ ] T051 [US5] Implement discover() method returning AsyncStream<DiscoveryResult> in DiscoveryService
- [ ] T052 [US5] Implement mDNS service discovery for "_samsung-remote._tcp.local." service type in MDNSBrowser
- [ ] T053 [US5] Implement SSDP M-SEARCH multicast to 239.255.255.250:1900 in SSDPBrowser
- [ ] T054 [US5] Parse mDNS TXT records to filter for Frame TV models in MDNSBrowser
- [ ] T055 [US5] Parse SSDP responses for Samsung TV URN "urn:samsung.com:device:RemoteControlReceiver" in SSDPBrowser
- [ ] T056 [US5] Implement discovery strategy: try mDNS first (3s), fallback to SSDP (7s total) in DiscoveryService
- [ ] T057 [US5] Implement find(at:) method for quick validation of known IP address in DiscoveryService
- [ ] T058 [US5] Implement cancel() method to stop discovery in DiscoveryService
- [ ] T059 [US5] Add AsyncStream integration for concurrent discovery results in DiscoveryService
- [ ] T060 [US5] Add comprehensive doc comments (///) for all public DiscoveryService APIs
- [ ] T061 [US5] Add logging with OSLog for discovery events

**Checkpoint**: Discovery works independently - can find TVs without needing connection

---

## Phase 6: User Story 2 - Application Management (Priority: P2)

**Goal**: List installed apps, launch specific apps, check app status, and close apps on Samsung TVs to enable rich application integration experiences.

**Independent Test**: Retrieve the list of installed apps, launch an app (e.g., Netflix), verify its running status, and close it. Success is confirmed when all operations complete without errors and the TV responds correctly.

**Dependencies**: Requires US4 (Connection Management) to be complete.

### Implementation for User Story 2

- [ ] T062 [P] [US2] Create AppManagement class in Sources/SwiftSamsungFrame/Apps/AppManagement.swift conforming to AppManagementProtocol
- [ ] T063 [US2] Implement list() method fetching installed apps via WebSocket "ed.installedApp.get" message in AppManagement
- [ ] T064 [US2] Parse app list response JSON and map to TVApp models in AppManagement
- [ ] T065 [US2] Implement launch() method sending WebSocket "ed.apps.launch" message with appId in AppManagement
- [ ] T066 [US2] Implement close() method to terminate running app in AppManagement
- [ ] T067 [US2] Implement status() method to check app running state in AppManagement
- [ ] T068 [US2] Implement install() method (if TV supports app store installs) with unsupportedOperation error fallback in AppManagement
- [ ] T069 [US2] Integrate AppManagement as property in TVClient (var apps: AppManagementProtocol)
- [ ] T070 [US2] Add error handling for app not found, launch failed scenarios in AppManagement
- [ ] T071 [US2] Implement app icon retrieval using REST API endpoint in RESTClient
- [ ] T072 [US2] Add comprehensive doc comments (///) for all public AppManagement APIs
- [ ] T073 [US2] Add logging with OSLog for app management operations

**Checkpoint**: App management works with existing connection - can control apps alongside basic remote

---

## Phase 7: User Story 3 - Art Mode Control for Frame TVs (Priority: P3)

**Goal**: Control Art Mode features on Samsung Frame TVs, including selecting art, uploading custom images, managing slideshows, and configuring display settings to enable personalized art gallery experiences.

**Independent Test**: On a Frame TV, check art mode support, list available art, select a piece, upload a custom image, and toggle art mode on/off. Success is verified when all art operations complete and the TV displays the selected content.

**Dependencies**: Requires US4 (Connection Management) to be complete.

### Implementation for User Story 3

- [ ] T074 [P] [US3] Create ArtController class in Sources/SwiftSamsungFrame/Art/ArtController.swift conforming to ArtControllerProtocol
- [ ] T075 [US3] Implement isSupported() method checking TV features for artMode in ArtController
- [ ] T076 [US3] Implement listAvailable() method fetching art via WebSocket "art_list" message in ArtController
- [ ] T077 [US3] Parse art list response JSON and map to ArtPiece models in ArtController
- [ ] T078 [US3] Implement current() method to get currently displayed art in ArtController
- [ ] T079 [US3] Implement select() method sending WebSocket "art_select" message with content_id in ArtController
- [ ] T080 [US3] Implement upload() method using REST API multipart/form-data upload in ArtController
- [ ] T081 [US3] Implement multipart form encoding (file, matte, title fields) in RESTClient for art upload
- [ ] T082 [US3] Implement delete() method for single art piece removal in ArtController
- [ ] T083 [US3] Implement deleteMultiple() method for bulk art deletion in ArtController
- [ ] T084 [US3] Implement thumbnail() method fetching JPEG thumbnail via REST API in ArtController
- [ ] T085 [US3] Implement isArtModeActive() method checking current art mode state in ArtController
- [ ] T086 [US3] Implement setArtMode() method to toggle art mode on/off in ArtController
- [ ] T087 [US3] Implement availableFilters() method to list photo filters in ArtController
- [ ] T088 [US3] Implement applyFilter() method applying filter to art piece in ArtController
- [ ] T089 [US3] Integrate ArtController as property in TVClient (var art: ArtControllerProtocol)
- [ ] T090 [US3] Add image validation (format, size limits) before upload in ArtController
- [ ] T091 [US3] Add error handling for artModeNotSupported, uploadFailed, invalidImageFormat in ArtController
- [ ] T092 [US3] Add platform check for watchOS to disable upload (memory constraints) in ArtController
- [ ] T093 [US3] Add comprehensive doc comments (///) for all public ArtController APIs
- [ ] T094 [US3] Add logging with OSLog for art mode operations

**Checkpoint**: All user stories (US1-US5) are now independently functional and integrated

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Final improvements, testing infrastructure, and production readiness

- [ ] T095 [P] Create MockTVClient in Sources/SwiftSamsungFrame/Testing/MockTVClient.swift for unit testing (conform to TVClientProtocol)
- [ ] T096 [P] Create example usage in Tests/SwiftSamsungFrameTests/ExampleUsage.swift demonstrating connection + basic control
- [ ] T097 [P] Add SwiftUI integration example in Tests/SwiftSamsungFrameTests/SwiftUIExample.swift showing RemoteControlView
- [ ] T098 [P] Verify all public APIs have doc comments with parameter/return/throws documentation
- [ ] T099 [P] Add performance measurement using ContinuousClock for command execution timing
- [ ] T100 [P] Add OSLog signposts for tracing connection and command lifecycle
- [ ] T101 [P] Verify Sendable conformance for all models (no warnings with strict concurrency)
- [ ] T102 [P] Test cross-platform compilation (macOS, iOS, tvOS, watchOS) with Xcode
- [ ] T103 [P] Update README.md with installation instructions, quick start, and links to docs
- [ ] T104 [P] Add CHANGELOG.md documenting version 0.1.0 features
- [ ] T105 [P] Add CONTRIBUTING.md with development setup and PR guidelines
- [ ] T106 Validate Package.swift builds successfully with `swift build`
- [ ] T107 Validate all tests pass with `swift test`
- [ ] T108 Run SwiftLint and fix any warnings/errors
- [ ] T109 Generate documentation with DocC (if applicable)
- [ ] T110 Tag release v0.1.0 and push to GitHub

---

## Dependencies & Execution Strategy

### User Story Completion Order

1. **Phase 2 (Foundational)** - MUST complete first (blocking)
2. **Phase 3 (US4: Connection)** - Required for US1, US2, US3
3. **Phase 4 (US1: Basic Control)** - Can start immediately after Phase 3 ✅ **MVP Milestone**
4. **Phase 5 (US5: Discovery)** - Can run in parallel with Phase 4 (independent)
5. **Phase 6 (US2: App Management)** - Requires Phase 3 complete
6. **Phase 7 (US3: Art Mode)** - Requires Phase 3 complete
7. **Phase 8 (Polish)** - After all user stories complete

### Parallel Execution Opportunities

**After Phase 2 completes**, these can run in parallel:

- **Track A**: Phase 3 (US4) → Phase 4 (US1) [Sequential, forms MVP]
- **Track B**: Phase 5 (US5) [Fully independent]

**After Phase 3 completes**, these can run in parallel:

- **Track A**: Phase 4 (US1) [Already started]
- **Track B**: Phase 5 (US5) [Already started]
- **Track C**: Phase 6 (US2) [Now unblocked]
- **Track D**: Phase 7 (US3) [Now unblocked]

### MVP Definition

**Minimum Viable Product** = Phase 2 + Phase 3 + Phase 4

This provides:
- ✅ Connection management with authentication (US4)
- ✅ Basic remote control (power, volume, navigation) (US1)
- ✅ Device information retrieval
- ✅ Error handling and logging

**Suggested First Release**: MVP only (defer US2, US3, US5 to v0.2.0)

---

## Task Statistics

- **Total Tasks**: 110
- **Phase 1 (Setup)**: 5 tasks
- **Phase 2 (Foundational)**: 14 tasks (BLOCKING)
- **Phase 3 (US4 - Connection)**: 14 tasks (P1, MVP) 🎯
- **Phase 4 (US1 - Basic Control)**: 14 tasks (P1, MVP) 🎯
- **Phase 5 (US5 - Discovery)**: 14 tasks (P2)
- **Phase 6 (US2 - App Management)**: 12 tasks (P2)
- **Phase 7 (US3 - Art Mode)**: 21 tasks (P3)
- **Phase 8 (Polish)**: 16 tasks

**Parallelizable Tasks**: 47 tasks marked with [P]

**MVP Task Count**: 33 tasks (Phase 1 + Phase 2 + Phase 3 + Phase 4)

---

## Format Validation

✅ All tasks follow checklist format: `- [ ] [ID] [P?] [Story?] Description`
✅ All task IDs are sequential (T001-T110)
✅ All user story tasks have [US#] labels
✅ All tasks include file paths in descriptions
✅ Parallel tasks marked with [P]
✅ Dependencies clearly documented
✅ Independent test criteria defined for each user story
