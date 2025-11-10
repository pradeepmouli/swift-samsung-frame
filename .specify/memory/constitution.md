<!--
Sync Impact Report:
- Version change: INITIAL → 1.0.0
- Initial constitution ratification for SwiftSamsungFrame
- Added principles: Swift 6 Compliance, Cross-Platform Support, Protocol-Oriented Design, Test Coverage, Strict Concurrency, Semantic Versioning, API Documentation
- Added sections: Swift Language Requirements, Development Workflow
- Templates requiring updates:
  ✅ plan-template.md - Constitution Check section aligns
  ✅ spec-template.md - User stories and requirements align
  ✅ tasks-template.md - Test-first workflow aligns
- Follow-up TODOs: None
-->

# SwiftSamsungFrame Constitution

## Core Principles

### I. Swift 6 Compliance (NON-NEGOTIABLE)

All code MUST target Swift 6.2+ with strict language mode enabled. This includes:
- Swift tools version 6.2 or later declared in Package.swift
- `ExistentialAny` and `StrictConcurrency` upcoming features enabled for all targets
- No compiler warnings tolerated in release builds
- Full compliance with Swift 6 concurrency model (`async`/`await`, `Actor`, `Sendable`)

**Rationale**: Swift 6 provides critical safety guarantees, especially around concurrency. Strict mode prevents subtle bugs and ensures long-term maintainability.

### II. Cross-Platform Support

The library MUST support all Apple platforms with specified minimum versions:
- macOS 15+
- iOS 18+
- tvOS 18+
- watchOS 11+

Platform-specific code MUST be isolated using `#if` compiler directives and clearly documented. Core functionality MUST work consistently across all platforms unless explicitly documented as platform-specific.

**Rationale**: Broad platform support maximizes library utility and ensures the codebase remains platform-agnostic by design.

### III. Protocol-Oriented Design

Favor protocol-oriented programming over class hierarchies:
- Define behavior via protocols with default implementations in extensions
- Use `struct` as the default type; only use `class` when reference semantics or inheritance are required
- Explicitly declare conformance to standard protocols (`Equatable`, `Hashable`, `Codable`) when appropriate
- Keep access control explicit (`public`, `internal`, `private`, `fileprivate`)

**Rationale**: Protocol-oriented design promotes composition, testability, and flexibility while avoiding common pitfalls of inheritance-based architectures.

### IV. Test Coverage (NON-NEGOTIABLE)

All public APIs MUST have corresponding XCTest coverage:
- Unit tests for all public functions, methods, and computed properties
- Tests written BEFORE implementation (TDD: Red → Green → Refactor)
- Tests MUST be deterministic with meaningful assertions
- Integration tests for cross-module interactions when applicable
- Tests MUST pass on all supported platforms

**Rationale**: Comprehensive testing ensures reliability, prevents regressions, and serves as executable documentation of expected behavior.

### V. Strict Concurrency

All concurrent code MUST use Swift's structured concurrency model:
- Prefer `async`/`await` over completion handlers
- Use `Actor` for shared mutable state
- Leverage `TaskGroup` for parallel workloads and `AsyncSequence` for streams
- All public APIs that cross actor boundaries MUST be marked `Sendable` where applicable
- Enable data race detection in debug builds

**Rationale**: Swift 6's concurrency model eliminates data races at compile time. Strict adherence prevents subtle threading bugs and future-proofs the codebase.

### VI. Semantic Versioning

Version numbering MUST follow semantic versioning (MAJOR.MINOR.PATCH):
- **MAJOR**: Breaking API changes, platform requirement increases, Swift version bumps
- **MINOR**: New features, new public APIs, non-breaking enhancements
- **PATCH**: Bug fixes, documentation updates, internal refactoring

Breaking changes MUST be documented in a CHANGELOG with migration guides.

**Rationale**: Predictable versioning allows library consumers to manage dependencies confidently and understand impact of updates.

### VII. API Documentation

All public APIs MUST have documentation comments:
- Use `///` doc comments for all `public` and `open` declarations
- Document parameters with `- Parameter name: description`
- Document return values with `- Returns: description`
- Document thrown errors with `- Throws: description`
- Include usage examples for complex APIs
- Keep documentation concise and focused on behavior, not implementation

**Rationale**: Well-documented APIs reduce cognitive load, improve developer experience, and serve as a contract between library and consumer.

## Swift Language Requirements

### Naming Conventions
- Types (structs, classes, enums, protocols): PascalCase
- Variables, properties, functions, enum cases: camelCase
- Filenames: PascalCase matching primary type

### Code Quality
- Favor immutable `let` bindings; use `var` only when mutation is required
- Use trailing closure syntax where appropriate
- Spell out parameter labels for clarity
- Keep functions focused (<30 lines) and extract helpers when logic grows complex
- Use `Result` for error propagation in synchronous APIs; throw errors in async contexts

### Tooling
- Use SwiftLint or SwiftFormat with project-specific configuration
- Do not disable linting rules globally without documented justification
- Enable Thread Sanitizer and Address Sanitizer in debug schemes
- Run `swift build` and `swift test` before all commits

## Development Workflow

### Pre-Implementation
1. Write specification defining user scenarios and requirements
2. Write tests that capture requirements (tests MUST fail initially)
3. Obtain approval for test coverage before implementation begins

### Implementation
1. Implement feature to pass tests (Red → Green)
2. Refactor for clarity and performance while maintaining test coverage
3. Update documentation to reflect changes
4. Run full test suite on all platforms

### Quality Gates
- All tests MUST pass on macOS, iOS, tvOS, watchOS
- No compiler warnings in release builds
- All public APIs MUST have doc comments
- SwiftLint/SwiftFormat checks MUST pass
- Code review MUST verify constitutional compliance

### Review Process
- PRs MUST include tests demonstrating new functionality
- Breaking changes MUST be justified and documented
- Complexity increases MUST be justified with rationale
- Reviewers MUST verify platform compatibility

## Governance

This constitution supersedes all other development practices. Amendments require:
1. Documented justification for the change
2. Impact assessment on existing code and templates
3. Update to constitution version following semantic versioning
4. Synchronization of `.specify/templates/` files to reflect new principles

All PRs and code reviews MUST verify compliance with these principles. Violations MUST be justified in the `Complexity Tracking` section of implementation plans.

For runtime development guidance beyond this constitution, refer to Swift coding standards in `vscode-userdata:/Users/pmouli/Library/Application%20Support/Code/User/prompts/swift.instructions.md`.

**Version**: 1.0.0 | **Ratified**: 2025-11-09 | **Last Amended**: 2025-11-09
