# Architecture

Status: proposed architecture, not implemented.

## Platform

- Native macOS application
- Swift and SwiftUI
- AppKit for window and menu bar integration
- Minimum deployment target: to be established
- Apple Silicon primary target

## Architectural principles

- Native-first
- Small dependency surface
- Explicit component boundaries
- No application backend unless justified
- No implicit telemetry
- Testable playback abstractions

## Proposed components

### Application

Lifecycle, menu bar integration, settings,
global shortcuts, window coordination.

### Interface

MiniPlayer, ZenPlayer, Search,
Library, Settings.

### Playback

A provider-neutral playback interface.

The concrete implementation must be selected
only after the M0 feasibility review.

### Provider integration

Authentication, catalog, library, metadata,
and playback capabilities supported by
a lawful integration method.

### Persistence

Local preferences, non-sensitive UI state,
and secure credential storage.

## Security

- Secrets in Keychain
- No hardcoded credentials
- No credentials in logs
- Minimum required permissions
- No untrusted code execution
- No unauthorized DRM bypass
- No redistribution of provider media

## Open decisions

- Playback implementation
- Authentication flow
- Compatibility with provider terms
- Supported macOS deployment target
- Media key and Now Playing integration
- Offline capability, if legally supported

These decisions require M0 validation.
