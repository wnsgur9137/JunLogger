# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

This is a Swift Package Manager (SPM) library. All commands run from the repo root.

- Build: `swift build`
- Run all tests: `swift test`
- Run a single test: `swift test --filter JunLoggerTests.testLogCategoryRawValues` (replace with `<TestClass>.<testMethod>`)
- Clean build artifacts: `swift package clean`
- Resolve/update dependencies: `swift package resolve` / `swift package update`
- Generate Xcode project (if needed): `swift package generate-xcodeproj`

There is no separate linter configured.

## Architecture

JunLogger is a thin, opinionated wrapper around Apple's unified logging system (`OSLog` / `os.Logger`). The public surface is intentionally small — three files in `Sources/JunLogger/` collaborate to provide categorized logging:

- `LogCategory.swift` — `public enum LogCategory: String, CaseIterable` defines the fixed set of categories (`network`, `ui`, `data`, `domain`, `lifecycle`, `auth`, `performance`, `general`). Each `rawValue` is the exact string used as the OSLog category, which is what Console.app filters on (`category:Network`, etc.). Adding/renaming a category requires updating three things in lockstep: the enum case, the static `Logger` instance in `Logger+Extension.swift`, and the switch in `Logger.logger(for:)`.

- `Logger+Extension.swift` — extends `os.Logger` with two responsibilities:
  1. **Category routing**: one static `Logger` per `LogCategory` (e.g. `Logger.network`, `Logger.ui`), all sharing `Bundle.main.bundleIdentifier` as the subsystem. `Logger.logger(for:)` dispatches a `LogCategory` to the matching static instance.
  2. **Level helpers** (`debug`/`info`/`warning`/`error`/`fault`): each prepends a leveled emoji and a `[file:line] function - message` prefix before calling `self.log(level:...)`. Note that `warning` is mapped to `OSLogType.error` intentionally (OSLog has no native warning level).
  3. **Signposts** (`beginSignpost` / `endSignpost`): always emitted under the `"Performance"` category regardless of which Logger instance the call is made on. If you rename the performance category, also update both `OSLog(category:)` literals here.

- `AppLogger.swift` — defines `public enum Log`, the namespace most callers use (`Log.info(.ui, "…")`). Each static method takes an optional `LogCategory` (defaults to `.general`), captures `#file`/`#function`/`#line` via default args, and forwards to `Logger.logger(for: category)`. This is a pure facade; behavior lives in the Logger extension.

Call flow for a typical log: `Log.info(.network, "...")` → `Logger.logger(for: .network)` → static `Logger.network` → category-tagged level helper → `os.Logger.log(level:_:)`.

### Things to be careful about when editing

- Subsystem is `Bundle.main.bundleIdentifier ?? ""`. In test/SPM contexts this is often empty — that's expected, not a bug to "fix" with a hardcoded fallback.
- `#file`/`#function`/`#line` are captured at the **call site** of the helper, which is what users want. Don't refactor the helpers to take an explicit context object without preserving this — you'd silently break source attribution.
- The package supports iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / macCatalyst 14 / visionOS 1 (see `Package.swift`). `os.Logger` requires those minimums; do not use APIs gated to higher OS versions without availability checks.
- `swift test` builds for the host platform (macOS) only; CI/users targeting iOS-only APIs won't be exercised by the test suite as-is.
