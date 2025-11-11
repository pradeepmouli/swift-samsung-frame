# Documentation Generation Guide

This guide explains how to generate and publish documentation for SwiftSamsungFrame.

## DocC Documentation

SwiftSamsungFrame uses Swift's DocC for documentation generation. DocC creates rich, interactive documentation from documentation comments in the code.

### Prerequisites

- **Xcode 16+** (macOS only)
- **macOS 15+**
- Swift Package with DocC support enabled

### Generating Documentation with Xcode

1. **Open the package in Xcode:**
   ```bash
   open Package.swift
   ```

2. **Build Documentation:**
   - Select **Product > Build Documentation** from the menu
   - Or press `Cmd + Shift + D`

3. **View Documentation:**
   - Documentation appears in Xcode's Documentation Browser
   - Press `Cmd + Shift + 0` to open the browser

### Generating Documentation from Command Line

Using `swift-docc-plugin` (requires Xcode):

```bash
# Generate documentation
swift package --allow-writing-to-directory ./docs \
  generate-documentation --target SwiftSamsungFrame \
  --output-path ./docs

# Preview documentation locally
swift package --disable-sandbox preview-documentation \
  --target SwiftSamsungFrame
```

The preview server will start at `http://localhost:8000/documentation/swiftsamsungframe/`

### Publishing Documentation to GitHub Pages

1. **Generate static documentation:**
   ```bash
   swift package --allow-writing-to-directory ./docs \
     generate-documentation --target SwiftSamsungFrame \
     --disable-indexing \
     --transform-for-static-hosting \
     --hosting-base-path swift-samsung-frame \
     --output-path ./docs
   ```

2. **Commit and push to gh-pages branch:**
   ```bash
   git checkout -b gh-pages
   git add docs/
   git commit -m "Update documentation"
   git push origin gh-pages
   ```

3. **Enable GitHub Pages:**
   - Go to repository Settings > Pages
   - Select `gh-pages` branch and `/docs` folder
   - Save

Documentation will be available at:
`https://yourusername.github.io/swift-samsung-frame/documentation/swiftsamsungframe/`

## SwiftLint Configuration

SwiftLint ensures code quality and consistency. The project includes a `.swiftlint.yml` configuration file.

### Running SwiftLint

**Check for issues:**
```bash
swiftlint lint
```

**Auto-fix issues:**
```bash
swiftlint lint --fix
```

**Run only on modified files:**
```bash
git diff --name-only | grep .swift | xargs swiftlint lint --path
```

### SwiftLint in CI/CD

Add to your GitHub Actions workflow:

```yaml
- name: SwiftLint
  run: |
    brew install swiftlint
    swiftlint lint --strict
```

### Key SwiftLint Rules

The project enforces:
- Swift 6 concurrency compliance
- Maximum line length (120 characters)
- Explicit access control
- No force unwrapping, force try, or force cast
- Consistent code formatting

See `.swiftlint.yml` for full configuration.

## API Documentation Standards

All public APIs must have comprehensive documentation:

### Required Documentation Elements

1. **Summary**: Brief one-line description
2. **Discussion**: Detailed explanation (optional but recommended)
3. **Parameters**: Description of each parameter
4. **Returns**: Description of return value
5. **Throws**: Description of errors that can be thrown
6. **Examples**: Usage examples (highly recommended)

### Example Documentation

```swift
/// Connects to a Samsung TV over WebSocket.
///
/// This method establishes a secure WebSocket connection to the TV,
/// handles authentication if needed, and maintains the connection
/// session. The connection can be reused for multiple commands.
///
/// - Parameters:
///   - host: IP address or hostname of the TV (e.g., "192.168.1.100")
///   - port: WebSocket port (default: 8001)
///   - tokenStorage: Optional token storage for persisting auth tokens
/// - Returns: Active connection session
/// - Throws: 
///   - `TVError.connectionFailed` if unable to connect
///   - `TVError.authenticationFailed` if pairing is rejected
///   - `TVError.timeout` if connection times out
///
/// ## Example
///
/// ```swift
/// let client = TVClient()
/// let session = try await client.connect(to: "192.168.1.100")
/// print("Connected to TV")
/// ```
///
/// - Important: Accept the pairing prompt on your TV when connecting
///   for the first time.
public func connect(
    to host: String,
    port: Int = 8001,
    tokenStorage: (any TokenStorageProtocol)? = nil
) async throws -> ConnectionSession
```

### Documentation Checklist

Before marking documentation as complete:

- [ ] All public types have documentation
- [ ] All public methods have documentation
- [ ] All public properties have documentation
- [ ] Complex internal types are documented
- [ ] Examples are provided for main features
- [ ] Parameters and return values are explained
- [ ] Error conditions are documented
- [ ] Related types are cross-referenced using backticks

### Cross-References

Use backticks to link to other types:

```swift
/// Connects using a `ConnectionSession` and sends commands via `RemoteControlProtocol`.
/// See also: ``TVDevice``, ``AuthenticationToken``
```

## Verifying Documentation

### Check for Missing Documentation

```bash
# Using Swift compiler warnings
swift build -Xswiftc -warn-missing-docs

# Manual review
grep -r "public " Sources/SwiftSamsungFrame --include="*.swift" | \
  grep -v "///" | head -20
```

### Documentation Coverage

Aim for:
- **100%** of public APIs documented
- **80%+** of internal types documented
- **Examples** for all major features
- **Cross-references** between related types

## Best Practices

1. **Write documentation before implementation** (TDD for docs)
2. **Keep it current**: Update docs with code changes
3. **Use examples**: Show don't just tell
4. **Be concise**: Clear and brief is better than verbose
5. **Think user-first**: Write for people using the API, not implementing it
6. **Test examples**: Make sure example code actually works
7. **Use diagrams**: Consider adding ASCII diagrams for complex flows

## Publishing Releases

When preparing a release:

1. **Update CHANGELOG.md** with all changes
2. **Generate fresh documentation**
3. **Review documentation coverage**
4. **Run SwiftLint** and fix all issues
5. **Build and test** on all platforms
6. **Tag the release** with semantic version
7. **Publish documentation** to GitHub Pages
8. **Create GitHub Release** with notes from CHANGELOG

### Release Checklist

- [ ] CHANGELOG.md updated
- [ ] Version bumped in Package.swift (if applicable)
- [ ] Documentation generated and published
- [ ] All tests passing
- [ ] SwiftLint clean
- [ ] Cross-platform builds verified
- [ ] GitHub release created
- [ ] Documentation site updated

## Resources

- [Swift-DocC Documentation](https://www.swift.org/documentation/docc/)
- [DocC Tutorial](https://developer.apple.com/documentation/docc)
- [SwiftLint Documentation](https://github.com/realm/SwiftLint)
- [Semantic Versioning](https://semver.org/)

---

For questions or issues with documentation, please open an issue on GitHub.
