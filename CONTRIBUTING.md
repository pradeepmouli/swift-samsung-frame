# Contributing to SwiftSamsungFrame

Thank you for your interest in contributing to SwiftSamsungFrame! This document provides guidelines and instructions for contributing to the project.

## Code of Conduct

Please be respectful and considerate in your interactions with other contributors. We aim to maintain a welcoming and inclusive community.

## Development Setup

### Prerequisites

- **Swift 6.2 or later** (required for strict concurrency features)
- **Xcode 16+** (for iOS/macOS development) or Swift toolchain for Linux
- **macOS 15+**, **iOS 18+**, **tvOS 18+**, or **watchOS 11+** for platform-specific testing
- A Samsung TV (2016+ with Tizen OS) for integration testing (optional)

### Getting Started

1. **Clone the repository:**

   ```bash
   git clone https://github.com/yourusername/swift-samsung-frame.git
   cd swift-samsung-frame
   ```

2. **Build the project:**

   ```bash
   swift build
   ```

3. **Run tests:**

   ```bash
   swift test
   ```

4. **Open in Xcode (optional):**

   ```bash
   open Package.swift
   ```

### Project Structure

```
swift-samsung-frame/
├── Sources/
│   └── SwiftSamsungFrame/
│       ├── Client/           # TVClient and connection management
│       ├── Commands/          # (Reserved for future organization)
│       ├── Apps/              # (Reserved for future organization)
│       ├── Art/               # (Reserved for future organization)
│       ├── Discovery/         # (Reserved for future organization)
│       ├── Models/            # Data models (TVDevice, TVApp, etc.)
│       ├── Protocols/         # Protocol definitions
│       ├── Networking/        # WebSocket, REST, D2D, Discovery
│       └── Extensions/        # Utility extensions
├── Tests/
│   └── SwiftSamsungFrameTests/
│       ├── Unit/              # Unit tests
│       └── Integration/       # Integration tests (future)
├── specs/                     # Design specifications
│   └── 001-samsung-tv-client/
│       ├── plan.md
│       ├── spec.md
│       ├── research.md
│       ├── data-model.md
│       ├── tasks.md
│       └── contracts/         # API contracts
├── Package.swift
├── README.md
├── CHANGELOG.md
├── CONTRIBUTING.md
└── .swiftlint.yml
```

## Development Guidelines

### Swift 6 Concurrency

This project uses Swift 6 with **strict concurrency** enabled. All contributions must comply with:

- **Actor isolation** for shared mutable state
- **Sendable conformance** for types passed across concurrency boundaries
- **@MainActor** for UI-related code
- No data races or concurrency warnings

### Code Style

We use SwiftLint to enforce code style. Key conventions:

1. **Line Length**: Maximum 120 characters (warning at 120, error at 150)
2. **Function Length**: Maximum 60 lines (warning at 60, error at 100)
3. **Type Length**: Maximum 300 lines (warning at 300, error at 400)
4. **File Length**: Maximum 500 lines (warning at 500, error at 800)
5. **Naming**: Use descriptive names; minimum 2 characters for identifiers
6. **Access Control**: Use explicit access control (public, internal, private)
7. **Force Unwrapping**: Avoid force unwrapping (generates warning)
8. **Force Try/Cast**: Never use force try or force cast (generates error)

### Running SwiftLint

If SwiftLint is installed:

```bash
swiftlint lint
```

To auto-fix issues:

```bash
swiftlint lint --fix
```

To install SwiftLint:

```bash
# macOS
brew install swiftlint

# Or via Mint
mint install realm/SwiftLint
```

### Documentation

All public APIs must have documentation comments:

```swift
/// Brief description of the method.
///
/// Detailed description providing context and usage examples.
///
/// - Parameters:
///   - param1: Description of first parameter
///   - param2: Description of second parameter
/// - Returns: Description of return value
/// - Throws: Description of errors that can be thrown
public func exampleMethod(param1: String, param2: Int) async throws -> Result {
    // Implementation
}
```

### Testing

#### Unit Tests

- Write unit tests for all new functionality
- Tests should be fast, isolated, and deterministic
- Use mocking for external dependencies (network, storage)
- Aim for high code coverage of core logic

#### Integration Tests

- Integration tests require a real Samsung TV
- Mark integration tests appropriately
- Document TV setup requirements in test comments

Example test structure:

```swift
import XCTest
@testable import SwiftSamsungFrame

final class ExampleTests: XCTestCase {
    func testExample() async throws {
        // Arrange
        let subject = TVClient()
        
        // Act
        let result = try await subject.someMethod()
        
        // Assert
        XCTAssertEqual(result, expectedValue)
    }
}
```

### Logging

Use OSLog for all logging:

```swift
import OSLog

private let logger = Logger.connection  // Use appropriate category

logger.info("Connection established to \(host)")
logger.error("Failed to connect: \(error.localizedDescription)")
```

Available log categories:
- `Logger.connection` - Connection lifecycle
- `Logger.commands` - Remote control commands
- `Logger.apps` - Application management
- `Logger.art` - Art Mode operations
- `Logger.discovery` - Device discovery
- `Logger.networking` - Network operations

### Error Handling

Use the `TVError` enum for all library-specific errors:

```swift
public enum TVError: Error, LocalizedError {
    case connectionFailed(reason: String)
    case authenticationFailed
    case timeout
    // ... other cases
    
    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let reason):
            return "Connection failed: \(reason)"
        // ... other descriptions
        }
    }
}
```

Always provide descriptive error messages with context.

## Pull Request Process

### Before Submitting

1. **Run tests**: Ensure all tests pass
   ```bash
   swift test
   ```

2. **Run SwiftLint** (if available): Fix any warnings/errors
   ```bash
   swiftlint lint
   ```

3. **Build for all platforms**: Verify cross-platform compatibility
   ```bash
   swift build
   ```

4. **Update documentation**: Update README.md if adding new features

5. **Update CHANGELOG.md**: Add entry for your changes under [Unreleased]

### PR Guidelines

1. **Create a focused PR**: One feature or bug fix per PR
2. **Write descriptive title**: Clearly state what the PR does
3. **Provide context**: Explain why the change is needed
4. **Reference issues**: Link to related issues (e.g., "Fixes #123")
5. **Include tests**: Add tests for new functionality
6. **Update docs**: Update documentation for API changes

### PR Template

```markdown
## Description
Brief description of the changes

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
Describe the testing you've done:
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated (if applicable)
- [ ] Manual testing performed

## Checklist
- [ ] My code follows the project's code style
- [ ] I have performed a self-review of my own code
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have made corresponding changes to the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective or that my feature works
- [ ] New and existing unit tests pass locally with my changes
- [ ] I have updated CHANGELOG.md

## Related Issues
Closes #(issue number)
```

## Branching Strategy

- **main**: Stable release branch
- **develop**: Development branch (if used)
- **feature/**: Feature branches (e.g., `feature/add-volume-control`)
- **bugfix/**: Bug fix branches (e.g., `bugfix/connection-timeout`)
- **docs/**: Documentation branches (e.g., `docs/update-readme`)

Create branches from `main` for your changes.

## Commit Messages

Write clear, descriptive commit messages:

**Format:**
```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**
```
feat: Add volume control with configurable steps

Implements volumeUp() and volumeDown() methods with a steps parameter
to control how many volume increments to send to the TV.

Closes #45
```

```
fix: Handle timeout errors in WebSocket connection

Connection attempts now properly timeout after 30 seconds and throw
a descriptive TVError.timeout error.
```

## Issue Reporting

### Bug Reports

When reporting bugs, please include:

1. **Swift/Xcode version**
2. **Platform** (macOS/iOS/tvOS/watchOS/Linux)
3. **Samsung TV model** (if applicable)
4. **Steps to reproduce**
5. **Expected behavior**
6. **Actual behavior**
7. **Code sample** (minimal reproducible example)
8. **Error messages/logs**

### Feature Requests

When requesting features, please include:

1. **Use case**: Describe what you're trying to accomplish
2. **Proposed solution**: How you think it should work
3. **Alternatives**: Other approaches you've considered
4. **Additional context**: Any relevant information

## Release Process

Releases are managed by project maintainers:

1. Update version in Package.swift
2. Update CHANGELOG.md with release notes
3. Tag release: `git tag -a v0.2.0 -m "Release 0.2.0"`
4. Push tags: `git push --tags`
5. Create GitHub release with notes from CHANGELOG.md

## Platform-Specific Contributions

### Apple Platforms (iOS, macOS, tvOS, watchOS)

- Test on multiple platforms when adding features
- Use `#if canImport(Network)` for Network framework features
- Document platform-specific limitations

### Linux

- Ensure basic functionality works on Linux
- Use `#if canImport(FoundationNetworking)` when needed
- Note Linux limitations in documentation

### Cross-Platform Guidelines

```swift
// Network framework features (Apple platforms only)
#if canImport(Network)
import Network

func discoverDevices() async throws -> [TVDevice] {
    // mDNS/SSDP implementation
}
#else
func discoverDevices() async throws -> [TVDevice] {
    throw TVError.unsupportedOperation("Discovery not available on this platform")
}
#endif
```

## Development Workflow

### Typical Workflow

1. **Pick or create an issue** to work on
2. **Create a branch** from main
3. **Write code** following style guidelines
4. **Add tests** for new functionality
5. **Update documentation** if needed
6. **Run tests** to ensure everything passes
7. **Commit changes** with clear messages
8. **Push branch** and create PR
9. **Address review feedback**
10. **Merge** after approval

### Working on Tasks

Refer to `specs/001-samsung-tv-client/tasks.md` for planned work:

- Tasks are organized by phase and user story
- Pick tasks marked with `[P]` for parallel work
- Check dependencies before starting a task
- Mark tasks complete in tasks.md when done

## Getting Help

- **Questions**: Open a discussion on GitHub
- **Bugs**: File an issue with details
- **Features**: Propose via feature request issue
- **Urgent**: Contact maintainers directly (if provided)

## Resources

### Documentation

- [Swift Language Guide](https://docs.swift.org/swift-book/)
- [Swift Concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Package Manager](https://swift.org/package-manager/)

### Samsung TV APIs

- [Samsung TV WebSocket API](https://github.com/xchwarze/samsung-tv-ws-api)
- [Samsung TV Art Mode](https://github.com/xchwarze/samsung-tv-ws-api/tree/art-updates)
- [Samsung Remote Control Protocol](https://github.com/Ape/samsungctl)

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

## Recognition

Contributors will be acknowledged in release notes and the project README.

---

Thank you for contributing to SwiftSamsungFrame! 🎉
