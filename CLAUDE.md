# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

This is a Swift Package Manager (SPM) library. All commands run from the repo root.

- Build: `swift build`
- Run all tests: `swift test`
- Run a single test: `swift test --filter JunLoggerTests.testLogCategoryRawValues` (replace with `<TestClass>.<testMethod>`)
- Clean build artifacts: `swift package clean`
- Resolve/update dependencies: `swift package resolve` / `swift package update`
- Strict concurrency check (manual): `swift build -Xswiftc -strict-concurrency=complete`

There is no separate linter configured.

## Architecture (v2.x)

JunLogger is a thin facade over Apple's unified logging system (`OSLog` / `os.Logger`). The public API is a **subscript** that returns an `os.Logger` instance per category, so all subsequent calls happen at a native OSLog call site — the Swift compiler's OSLog SIL optimization (privacy markers, lazy evaluation) is preserved.

Four source files in `Sources/JunLogger/`:

- `LogCategory.swift` — `public struct LogCategory: RawRepresentable, ExpressibleByStringLiteral, Hashable, Sendable`. Eight built-in categories exposed as static properties (`network`, `ui`, `data`, `domain`, `lifecycle`, `auth`, `performance`, `general`). Custom categories are added via string literals (`Log["Payment"]`) or by extending `LogCategory` with new static properties. The `rawValue` is the OSLog `category` string used by Console.app filters.

- `LoggingProvider.swift` — `public protocol LoggingProvider: Sendable { func logger(for: LogCategory) -> Logger }` with two built-in implementations: `OSLogProvider` (default, uses `Bundle.main.bundleIdentifier`) and `DisabledLogProvider` (returns `Logger(.disabled)` for tests).

- `Logger+Extension.swift` — keeps the eight `static let` `Logger` instances (`Logger.network`, `Logger.ui`, …) for v1.x compatibility (direct `Logger.network.debug(...)` usage). Also hosts the **signpost** helpers (`beginSignpost(name:)` / `endSignpost(name:signpostID:)`), still using legacy `os_signpost` C-functions under a hardcoded `"Performance"` category. No level helpers — the wrapper-style `debug`/`info`/... methods on `Logger` were removed in v2.0.

- `AppLogger.swift` — `public enum Log` with three members: `static var provider: any LoggingProvider` (`nonisolated(unsafe)`), `static subscript(_ category: LogCategory) -> Logger`, and signpost facade methods. That's it. The subscript is the **entire** logging surface.

Typical call: `Log[.network].debug("...")` → `Log.provider.logger(for: .network)` → `Logger(subsystem: ..., category: "Network")` → `os.Logger.debug(_:)` (native, compiler-optimized).

### Things to be careful about when editing

- **Do not reintroduce wrapper methods that take `String` messages.** Doing so silently disables OSLog's interpolation-level privacy markers and lazy evaluation. The `testLazyEvaluationWhenDisabled` test pins this behavior — keep it green.
- **Do not introduce a method that accepts `OSLogMessage` as a parameter and forwards to `Logger.log(_:)`.** This was attempted in early v2.0 design and is **impossible**: `OSLogMessage`'s only initializer is `init(stringInterpolation:)`, and `OSLogInterpolation`'s `appendInterpolation` overloads do not accept `OSLogMessage`. SIL optimization runs at the call site of the interpolation, not across function boundaries.
- **Adding a category**: extend `LogCategory` with a new `public static let` (or pass a string literal at the call site). No switch/dispatch changes needed; the subscript + provider handles it.
- **Subsystem** is `Bundle.main.bundleIdentifier ?? ""` (in `OSLogProvider` and the v1.x-compatible static instances). In test/SPM contexts this is often empty — that's expected.
- **OS minimums**: iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / macCatalyst 14 / visionOS 1. `os.Logger` requires these. Raising the floor is a MAJOR change per [docs/release-management.md](docs/release-management.md).
- **`OSLogType.warning` does not exist.** Apple's own `Logger.warning(_:)` maps to `OSLogType.error`. This is correct, not a bug.
- **Signposts** still use legacy `os_signpost`. `OSSignposter` (iOS 15+) migration is queued in [docs/improvement-plan.md](docs/improvement-plan.md) §6.
- **`swift test` runs on the host platform (macOS) only**. iOS-only behavior isn't exercised by `swift test`.

## Release / Versioning

This repository follows **[docs/release-management.md](docs/release-management.md)** for all version-, tag-, CHANGELOG-, and Release-related work. The full decision rules live there. When doing release work in this repo, treat that document as authoritative and update both it and this section together if the policy changes.

**Quick reference Claude must follow**:

- **SemVer**: API removal/rename/signature change → MAJOR. New API addition (compatible) or new `@available(deprecated:)` → MINOR. Bug fix without API surface change → PATCH. Deployment target raise or `swift-tools-version` raise → MAJOR.
- **Tag**: `X.Y.Z` (no `v` prefix), annotated, message `Release X.Y.Z`. Push branch + tag separately.
- **CHANGELOG.md**: Keep a Changelog format. Always keep a `## [Unreleased]` section at the top. Every PR updates `[Unreleased]` before merge. On release, swap the `[Unreleased]` header for `## [X.Y.Z] - YYYY-MM-DD` and add a fresh empty `[Unreleased]` above it. Add a compare link at the bottom.
- **GitHub Release**: must be created right after pushing the tag (the tag alone is not enough). Body sections: Highlights / Breaking / Added / Changed / Removed / Fixed / Migration / Compatibility / Notes. MAJOR releases must include the `.upToNextMajor` warning.
- **Migration guide**: required for MAJOR releases at `docs/migration-X.0.md`. Link from README top, CHANGELOG entry, and Release body.
- **MAJOR consumer impact**: explicitly note in the Release body that `.upToNextMajor(from: "<prev major>.0.0")` consumers will NOT auto-upgrade and must bump the constraint.

**Release checklist** (run in order; do not skip):

1. Classify the change (MAJOR/MINOR/PATCH) using the table in `docs/release-management.md` §1.
2. Convert `[Unreleased]` to `## [X.Y.Z] - YYYY-MM-DD` in CHANGELOG.md, add a fresh `[Unreleased]` above.
3. Add the new compare link at the bottom of CHANGELOG.md.
4. For MAJOR: write/update `docs/migration-X.0.md` and link it from README + CHANGELOG.
5. Run `swift build` and `swift test` — both must be green.
6. Commit (single or split as appropriate — match the project's commit style: emoji prefix, Korean body when project history is Korean).
7. Create the annotated tag: `git tag -a X.Y.Z -m "Release X.Y.Z"`.
8. Push: `git push origin main` then `git push origin X.Y.Z`.
9. Tell the user to create the GitHub Release page with the body template in `docs/release-management.md` §4. (Claude cannot create GitHub Releases without explicit user delegation.)
10. For MAJOR: remind the user to notify dependents about the `Package.swift` constraint update.

**What Claude must NOT do unprompted**:

- Push tags or branches to `origin` without explicit user approval. Pushing is visible to everyone and effectively permanent.
- Create a GitHub Release page (gh API call) without explicit user approval.
- Force-push or rewrite history of pushed tags/branches.
- Choose a version number when the change classification is ambiguous — ask the user.

## Commit Style

Existing commits use an emoji prefix in the subject (`🎉`, `♻️`, `📝`, `⚙️`, `✅`, `🚀`). Match this style. Bodies are Korean for substantive changes that explain "why". Include the standard Co-Authored-By trailer that the harness inserts.

## Documentation Map

- [README.md](README.md) — user-facing usage guide
- [CHANGELOG.md](CHANGELOG.md) — Keep a Changelog history
- [docs/release-management.md](docs/release-management.md) — versioning/tagging/release policy (authoritative)
- [docs/migration-2.0.md](docs/migration-2.0.md) — v1.x → v2.0 migration
- [docs/improvement-plan.md](docs/improvement-plan.md) — research-backed backlog (§6 OSSignposter, §8 Swift 6 strict still open)
