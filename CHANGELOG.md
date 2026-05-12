# Changelog

All notable changes to this project are documented in this file.

The format follows [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/) and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html). 운영 정책은 [docs/release-management.md](docs/release-management.md)를 따른다.

## [Unreleased]

## [2.0.0] - 2026-05-12

### Breaking

- `Log` enum의 `debug` / `info` / `warning` / `error` / `fault` static 메서드를 제거하고, `Log[.category]`가 `os.Logger` 인스턴스를 반환하는 subscript 패턴으로 전환했다. 호출부는 `Log[.network].debug("...")` 형태로 변경해야 한다. 자세한 변환 표와 흔한 컴파일 에러 대처법은 [docs/migration-2.0.md](docs/migration-2.0.md) 참고.
- 메시지 헬퍼의 `file` / `function` / `line` 파라미터와 메시지 본문의 이모지·`[file:line] function -` 프리픽스를 제거했다. OSLog가 호출 위치를 자동 캡처하므로 중복이며, 프리픽스가 박혀 있는 동안에는 OSLog 인터폴레이션 최적화가 불가능했다.
- `error(_:error:)` / `fault(_:error:)`의 `Error?` 인자를 제거했다. 호출자가 `\(e.localizedDescription, privacy: .public)`로 직접 인터폴레이션한다.
- `LogCategory`를 `enum`에서 `struct`로 변경했다. 기본 8개 케이스는 정적 프로퍼티로 보존되어 호출 형태(`LogCategory.network`)는 동일하나, `switch`로 망라하는 외부 코드가 있었다면 영향을 받는다.

### Added

- `LogCategory`가 `ExpressibleByStringLiteral`을 채택해 사용자 정의 카테고리를 문자열 리터럴로 지정할 수 있다. (`Log["Payment"].info(...)`)
- `LogCategory.allBuiltInCategories` 노출.
- `LoggingProvider` 프로토콜과 기본 구현체 `OSLogProvider`, `DisabledLogProvider` 추가. `Log.provider`를 교체하여 테스트 환경에서 로그를 일괄 끄거나 임의 구현체로 대체할 수 있다.
- `Log[.x].notice(...)` 사용 가능 (OSLog native API가 그대로 노출되어 `OSLogType.default` 레벨 활용 가능).
- 인터폴레이션 레벨 privacy 마커(`\(value, privacy: .private)`)와 컴파일 타임 lazy evaluation이 호출 위치에서 그대로 동작한다. 회귀 방지용 `testLazyEvaluationWhenDisabled` 테스트 포함.
- 소급 정책 문서 `docs/release-management.md` 추가.
- 마이그레이션 가이드 `docs/migration-2.0.md` 추가.

### Changed

- README를 subscript 호출 패턴, privacy 마커 사용 예, 커스텀 카테고리 정의, OSLogType별 디스크 기록 정책, DI 가이드 중심으로 다시 작성.
- 기존 8개 카테고리의 `Logger` 정적 인스턴스(`Logger.network`, `Logger.ui`, …)는 1.x 호환을 위해 그대로 유지되며 `Bundle.main.bundleIdentifier`를 subsystem으로 사용한다. `Log.provider` 교체는 `Log[.x]` 경로에만 영향을 준다.

### Notes

- ⚠️ `.upToNextMajor(from: "1.0.0")`으로 의존하는 사용자는 v2.0.0을 자동으로 받지 않는다. `Package.swift`를 `.upToNextMajor(from: "2.0.0")`으로 변경하고 `swift package update`를 실행해야 한다.
- Signpost API(`Log.beginSignpost(name:)`, `Log.endSignpost(name:signpostID:)`)는 변경되지 않았다. `OSSignposter` 기반 새 API로의 전환은 향후 마이너 릴리스에서 다룬다.

## [1.0.1] - (이전 릴리스)

### Removed

- 테스트 코드 정리 (`c191817`).

## [1.0.0] - (초기 릴리스)

- iOS / macOS / watchOS / tvOS / visionOS 대상 Apple OSLog 기반 로깅 라이브러리 초기 릴리스.
- `Log.debug` / `info` / `warning` / `error` / `fault` static 메서드.
- 고정 8개 `LogCategory` enum.
- Signpost 기반 성능 측정.

[Unreleased]: https://github.com/wnsgur9137/JunLogger/compare/2.0.0...HEAD
[2.0.0]: https://github.com/wnsgur9137/JunLogger/compare/1.0.1...2.0.0
[1.0.1]: https://github.com/wnsgur9137/JunLogger/compare/1.0.0...1.0.1
[1.0.0]: https://github.com/wnsgur9137/JunLogger/releases/tag/1.0.0
