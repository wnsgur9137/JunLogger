# JunLogger 개선 계획 (Improvement Plan)

> 작성일: 2026-05-12
> 대상 코드: `c191817 ♻️ Delete test code` ~ `178e552 ⚙️ Ignore Claude Code tooling files`
> 작성 목적: 외부 리서치 결과(Apple 공식 문서·WWDC·주요 OSS·Swift Evolution)를 바탕으로 도출된 JunLogger 개선 항목을, "왜 해야 하는지"의 근거와 "어떻게 작업할 수 있는지"의 단계까지 포함해 추후 작업자가 단독으로 진행 가능한 수준으로 정리한다.

---

## 0. 현재 baseline 요약 (모든 개선 항목의 기준점)

| 항목 | 현재 구현 | 위치 |
| --- | --- | --- |
| Public 진입점 | `public enum Log` + static 메서드 (`Log.debug`, `Log.info`, …) | `Sources/JunLogger/AppLogger.swift` |
| 메시지 타입 | `String` | 모든 레벨 헬퍼 |
| 메시지 가공 | `"<이모지> [\(fileName):\(line)] \(function) - \(message)"` 호출 시점 즉시 완성 | `Logger+Extension.swift:104~181` |
| 카테고리 | `public enum LogCategory: String, CaseIterable` 고정 8종 | `LogCategory.swift` |
| Subsystem | `Bundle.main.bundleIdentifier ?? ""` (static private) | `Logger+Extension.swift:15~17` |
| 레벨 매핑 | debug→`.debug`, info→`.info`, warning→`.error`, error→`.error`, fault→`.fault` | `Logger+Extension.swift` |
| Signpost | "Performance" 카테고리 하드코딩된 별도 `OSLog` 인스턴스, `os_signpost()` C-함수 사용 | `Logger+Extension.swift:185~227` |
| OS 하한 | iOS 14 / macOS 11 / watchOS 7 / tvOS 14 / macCatalyst 14 / visionOS 1, Swift 5.9+ | `Package.swift` |
| 테스트 | smoke 수준 3개 (rawValue, 호출 비크래시, signpost ID 유효성) | `Tests/JunLoggerTests/JunLoggerTests.swift` |

이 baseline에서 **OSLog가 제공하는 두 가지 핵심 기능을 활용하지 못하고 있다**: (1) 인터폴레이션 레벨 privacy redaction, (2) 컴파일 타임 lazy evaluation. 이는 OSLog 위에 wrapper를 만드는 본질적 동기를 잃게 한다. 아래 작업들은 이 baseline 위에서 단계적으로 진행한다.

---

## 1. [HIGH] `String` 메시지 API → `OSLogMessage` 인터폴레이션 기반으로 전환

### 1.1 왜 해야 하는가 — 문제의 본질

OSLog의 `Logger`는 단순한 출력 함수가 아니라 **Swift 컴파일러와 협력하는 특수 인터폴레이션 시스템**이다. 다음 두 가지는 `Logger`가 `OSLogMessage`(또는 `String` 리터럴이 `OSLogMessage`로 추론되는 케이스)를 받을 때에만 동작한다.

**(a) 프라이버시 마커 (`OSLogPrivacy`)**

Apple [OSLogPrivacy 공식 문서](https://developer.apple.com/documentation/os/oslogprivacy) (iOS 14.0+):

```swift
Logger().info("계좌번호: \(accountNumber, privacy: .private)")
Logger().log("주문: \(smoothieName, privacy: .public)")
```

`.private` / `.public` / `.sensitive` / `.auto` 와 `auto(mask: .hash)` 등의 마스킹 변형을 **인자별로** 지정한다. 호출자가 `String`을 미리 만들어 전달하면 컴파일러가 format string과 argument를 분리할 수 없어 어노테이션 자체가 불가능하다. Peter Steinberger의 분석([Logging in Swift](https://steipete.me/posts/2020/logging-in-swift))은 이 함정을 "대부분의 OSLog 래퍼가 저지르는 실수"로 지적한다.

JunLogger의 현재 시그니처:

```swift
public static func debug(
    _ category: LogCategory = .general,
    _ message: String,                    // ← 이미 String이므로 어노테이션 부착 시점이 없음
    file: String = #file,
    function: String = #function,
    line: Int = #line
)
```

호출자가 `Log.debug(.network, "응답: \(body, privacy: .private)")`을 시도해도, `\(body, privacy: .private)`는 **Swift의 기본 String 인터폴레이션**으로 해석되어 컴파일 에러 또는 무시된다. 즉, JunLogger를 통과하는 모든 동적 값이 사실상 `.public`으로 노출된다.

**(b) 컴파일 타임 Lazy Evaluation**

[apple/swift PR #24336](https://github.com/apple/swift/pull/24336/files)과 [WWDC 2020 세션 10168 — Explore logging in Swift](https://developer.apple.com/videos/play/wwdc2020/10168)에 따르면, Swift 컴파일러는 필수 최적화 패스(SIL transformation)로 `OSLogMessage` 인터폴레이션을:

1. format string을 컴파일 타임 리터럴로 추출
2. 각 동적 인자를 `@autoclosure`로 감싸 런타임 지연 평가

처리한다. 핵심 약속은 *"The message is not formatted unless you observe it."* — 해당 로그 레벨이 disabled면 인자 표현식 자체가 평가되지 않는다.

JunLogger는 호출 시점에 `"\(이모지) [\(fileName):\(line)] \(function) - \(message)"`를 **즉시 평가**하므로, 프로덕션에서 debug 레벨이 꺼져 있어도 (1) 파일명 추출, (2) NSString 캐스트, (3) 문자열 인터폴레이션이 매번 실행된다. 즉, OSLog를 쓰는 주요 동기인 "zero-cost when disabled"를 잃었다.

### 1.2 제안 변경

API 시그니처를 `OSLogMessage` 기반으로 변경한다.

```swift
// 변경 후 (예시 — 실제 구현 시 정확한 시그니처는 OSLogMessage의 ExpressibleByStringInterpolation 조건 확인)
public static func debug(
    _ category: LogCategory = .general,
    _ message: OSLogMessage,
    file: String = #fileID,
    function: String = #function,
    line: Int = #line
)
```

호출부:

```swift
Log.debug(.network, "응답: \(body, privacy: .private), 상태 \(statusCode, privacy: .public)")
```

`OSLogMessage`는 `String` 리터럴(인터폴레이션 포함)을 직접 받을 수 있으므로 호출 측 변경은 최소화된다. 단, 사전 빌드된 `String` 변수를 직접 넘기는 호출은 컴파일 에러가 되고, 이는 의도된 마이그레이션 강제(호출자가 인터폴레이션을 의식하도록 유도)다.

### 1.3 호환성 고려

- 이는 **major breaking change**다. SemVer상 다음 릴리스는 `2.0.0`이 적절.
- 호출자가 `String` 변수를 그대로 넘기던 코드가 있다면 `Log.info(.ui, "\(savedMessage)")`로 인터폴레이션 래핑 필요. 컴파일 에러로 명확히 드러나므로 위험은 낮음.
- 한 PR로 묶지 않고 1번과 2번(prefix 제거)을 함께 묶어야 한다(상호 의존, §2 참조).

### 1.4 작업 단계

1. `Logger+Extension.swift`의 각 레벨 헬퍼(`debug`/`info`/`warning`/`error`/`fault`)의 `message: String` 파라미터를 `message: OSLogMessage`로 변경.
2. 내부 호출을 `self.log(level: ..., "\(message, privacy: .auto)")` 형태로 수정. (privacy default를 어떻게 줄지 결정 필요 — 권장: `.auto`로 두고 호출자가 명시적으로 override)
3. `AppLogger.swift`의 `Log.*` facade도 동일하게 시그니처 갱신.
4. 기존 테스트의 호출 코드를 새 시그니처에 맞춰 갱신. `"Test debug log"` 리터럴은 호환되므로 대부분 그대로 작동.
5. README의 사용 예시에 `privacy:` 사용 예제 추가.
6. CHANGELOG/마이그레이션 가이드에 `2.0.0` 변경 사항 명시.

### 1.5 검증 방법

- 컴파일: `swift build`
- 단위 테스트: `swift test`
- 수동 검증: 샘플 앱에서 `Log.info(.auth, "사용자: \(userId, privacy: .private)")` 출력 후 Console.app에서 `<private>` 마스킹 확인.
- 성능 검증(선택): `Logger.isEnabled(type:)`이 false인 상황에서 인자 표현식의 부작용(예: counter 증가)이 발생하지 않음을 단위 테스트로 검증.

### 1.6 우선순위 근거

이 항목은 라이브러리 존재 의의 자체와 직결된다. 미해결 시 JunLogger는 **사실상 `print()` 위에 카테고리만 입힌 래퍼**가 된다. App Store 리뷰·개인정보 보호 규정 측면 리스크도 있다.

---

## 2. [HIGH] 메시지 본문의 이모지·`[file:line] function -` prefix 제거

### 2.1 왜 해야 하는가

§1의 `OSLogMessage` 전환은 **이 prefix가 메시지 본문에 박혀 있는 동안 불가능**하다. 컴파일 타임 리터럴로 추출되어야 할 format string에 동적 파일명/라인을 끼워 넣으면, 인터폴레이션 위치가 호출자가 의도한 자리가 아니라 prefix 안쪽이 되어버린다.

추가로 다음 trade-off들이 있다:

- **검색·필터링 방해**: `OSLogStore` (iOS 15+) 기반 in-app 로그 뷰어, `log stream` CLI, Console.app의 텍스트 검색이 모두 prefix 문자열에 의해 오염된다. `category:Network` 같은 메타데이터 검색은 Console.app이 이미 제공한다([Filtering logs in Xcode 15](https://nilcoalescing.com/blog/FilteringLogsInXcode15/)).
- **중복 정보**: OSLog는 call site 정보를 자동 캡처해 Console.app·Instruments에서 표시한다. 메시지 본문에 다시 박는 것은 같은 정보를 두 곳에 보관하는 것.
- **시각적 구분의 대체재**: Xcode 15 Debug Console은 log type별 색상·메타데이터 컬럼을 기본 제공한다([WWDC 2023 세션 10226 — Debug with structured logging](https://developer.apple.com/videos/play/wwdc2023/10226/)). 이모지 prefix의 효용이 크게 줄었다.
- **검색·grep 친화성**: 메시지 본문이 짧고 정형화될수록 grep·log stream 필터가 깔끔해진다. 이모지는 폰트·터미널 환경에 따라 깨질 수도 있다.

### 2.2 제안 변경

- `Logger+Extension.swift`의 레벨 헬퍼에서 prefix 조립 코드를 제거하고 메시지를 그대로 `self.log(level: ..., "\(message)")` 형태로 전달.
- 소스 위치(`file`, `function`, `line`) 인자는 시그니처에 유지하되, 본문에 끼워 넣는 대신 다음 중 하나의 처리:
  - **옵션 A (권장)**: 제거. OSLog가 호출 위치를 자동 캡처하므로 잉여. README에서 Console.app·Instruments에서 호출 위치 확인 방법 안내.
  - **옵션 B**: 메시지에 OSLogMessage 인터폴레이션으로 명시 삽입 — `"\(file, privacy: .public):\(line) \(message)"`. privacy를 명시해야 컴파일러가 추출 가능.

옵션 A를 1차 권장. 호출 위치는 OSLog 메타데이터에 이미 있으므로 본문에서 빼는 것이 정합성에 맞다.

### 2.3 호환성 고려

- 출력 포맷이 바뀐다. 로그를 정규식으로 후처리하는 외부 도구가 있다면 영향. (현재로서는 그럴 가능성 낮음)
- §1과 함께 `2.0.0`으로 묶어 진행.

### 2.4 작업 단계

1. `Logger+Extension.swift:104~181`의 5개 레벨 헬퍼에서 `fileName`/prefix 조립 라인 제거.
2. `error`/`fault`의 `Error?` 인자 처리는 유지하되, `localizedDescription`도 `OSLogMessage` 인터폴레이션 안에서 `\(error.localizedDescription, privacy: .public)`로 작성.
3. (옵션 A 선택 시) `file`/`function`/`line` 파라미터를 시그니처에서 제거. 또는 deprecated로 1버전 유지 후 다음 메이저에서 제거.
4. README 사용 예시·"로그 확인" 섹션에서 이모지 prefix 언급 제거. Xcode 15 Debug Console 메타데이터 컬럼 활용 안내 추가.
5. 기존 테스트의 `"Test debug log"` 등은 그대로 통과 가능.

### 2.5 검증 방법

- `swift build` / `swift test`
- 샘플 앱에서 출력을 확인하여 Console.app 메타데이터 컬럼에 카테고리/타입이 올바르게 표시되는지, 호출 위치 정보가 자동으로 캡처되는지 확인.

### 2.6 우선순위 근거

`§1`의 선행 조건이며, 그 자체로도 검색·grep·OSLogStore 친화성을 크게 개선한다.

---

## 3. [MEDIUM] `#file` → `#fileID`로 기본값 명시 변경

### 3.1 왜 해야 하는가

Swift Evolution [SE-0274 (Magic File)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md), [SE-0285 (Ease #file Transition)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0285-ease-pound-file-transition.md)에 따르면:

| 리터럴 | 값 형태 | 가용 |
| --- | --- | --- |
| `#file` | Swift 5.8 이전: 풀 절대 경로 / Swift 5.8+ 점진적으로 `#fileID`와 동일화 진행 / Swift 6: `#fileID` 의미 | Swift 5.0+ |
| `#filePath` | 항상 풀 절대 경로 | Swift 5.3+ |
| `#fileID` | `모듈명/파일명.swift` 상대형 | Swift 5.3+ |

Swift API Design Guidelines와 [Swift Forums의 #file vs #fileID 논의](https://forums.swift.org/t/file-vs-fileid-in-swift-6/74614)에서 프로덕션 코드는 **명시적으로 `#fileID`를 사용**할 것을 권장한다. 이유:

1. **프라이버시**: `#file` 풀 경로는 빌더의 홈 디렉토리(`/Users/leejunhyeok/...`)를 노출. 라이브러리 배포 시 사용자의 디렉토리 구조까지 따라 들어가 로그에 박힌다.
2. **바이너리 크기**: 짧은 문자열로 절약.
3. **Swift 6 미래 호환**: `#file`의 기본 의미가 이미 `#fileID`로 수렴 중. 명시하면 컴파일러 옵션 변경에 영향받지 않는다.

JunLogger의 OS/Swift 하한(iOS 14+, Swift 5.9+)에서 `#fileID`는 무조건 사용 가능하다.

### 3.2 제안 변경

`AppLogger.swift`와 `Logger+Extension.swift`의 모든 `file: String = #file`을 `file: String = #fileID`로 변경.

### 3.3 호환성 고려

- 동작 변화: 로그에 박히는 파일 경로가 풀 경로→`Module/File.swift`로 짧아진다. 정규식 후처리 도구가 있다면 영향.
- ABI 변화 없음.
- `2.0.0`(§1·§2와 함께) 또는 `1.x` 마이너에 포함 가능. §2에서 file 파라미터를 제거할 가능성이 있다면 §3 작업은 의미가 없어지므로 §2의 결정에 따라 좌우.

### 3.4 작업 단계

1. `Sources/JunLogger/*.swift`에서 `= #file`을 모두 `= #fileID`로 일괄 변경.
2. `(file as NSString).lastPathComponent` 처리도 함께 변경 검토. `#fileID`는 이미 짧으므로 lastPathComponent가 불필요할 수 있음(`Module/File.swift`는 그대로 표시하는 편이 정보량이 큼).

### 3.5 검증 방법

- 빌드/테스트.
- 샘플 출력 확인.

### 3.6 우선순위 근거

한 줄 변경으로 프라이버시·바이너리 크기·Swift 6 호환성을 동시에 개선. 위험도 낮음.

---

## 4. [MEDIUM] 카테고리 확장성 — 외부 사용자가 커스텀 카테고리 정의 가능하도록

### 4.1 왜 해야 하는가

현재 `LogCategory`는 고정 `enum`으로 8개 케이스 폐쇄. 사내 라이브러리 특성상 팀별/모듈별로 `payment`, `analytics`, `videoPlayer` 같은 도메인 특화 카테고리가 필요해지며, 그때마다 JunLogger 본체를 수정하는 것은 비효율이다. Console.app 필터링이 카테고리 단위로 이뤄지므로 카테고리는 충분히 세분화될 필요가 있다.

업계 패턴은 두 가지다:

- **패턴 A — Protocol 기반**: `protocol LogCategoryProtocol: RawRepresentable where RawValue == String {}`. 사용자가 본인 모듈에서 `enum MyCategory: String, LogCategoryProtocol`을 정의.
- **패턴 B — Struct + ExpressibleByStringLiteral**: `public struct LogCategory: RawRepresentable, ExpressibleByStringLiteral`. `Log.debug("payment", ...)`처럼 문자열 리터럴이 자동 변환.

[SwiftLee의 OSLog 가이드](https://www.avanderlee.com/debugging/oslog-unified-logging/)는 `Logger` extension으로 카테고리를 정의하는 패턴을 권장하는데, 이는 패턴 B 사상에 가깝다.

### 4.2 제안 변경

**패턴 B (권장)**. 이유:

1. 호출부가 가장 자연스럽다(`Log.debug("Payment", "...")`).
2. 기존 enum 케이스를 정적 프로퍼티로 보존해 하위 호환이 깔끔하다.

```swift
// 예시 — 실제 구현 시 OSLog category 문자열 제약 확인
public struct LogCategory: RawRepresentable, ExpressibleByStringLiteral, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }

    public static let network: LogCategory = "Network"
    public static let ui: LogCategory = "UI"
    // ...
}
```

`Logger.logger(for:)` switch는 사라지고 **카테고리 → Logger 인스턴스 캐시 (딕셔너리)** 패턴으로 교체:

```swift
// 동시성 안전 캐시. Sendable 검증 필요(§8 참조).
private static let cache: OSAllocatedUnfairLock<[String: Logger]> = .init(...)
```

또는 단순히 `Logger(subsystem: subsystem, category: category.rawValue)`를 **매 호출마다 생성**해도 무방하다. `Logger`는 가벼운 struct이며, [WWDC 2020 세션 10168](https://developer.apple.com/videos/play/wwdc2020/10168)도 frequent 인스턴스화에 대해 우려하지 않는다.

### 4.3 호환성 고려

- 기존 enum `LogCategory.network` 등의 호출은 정적 프로퍼티로 보존되므로 **그대로 작동**한다.
- enum이 struct로 바뀌면 `switch`로 망라하던 코드가 컴파일 에러. 라이브러리 내부의 `Logger.logger(for:)` switch가 사라지므로 해결되지만, 외부 사용자가 `LogCategory`에 대해 `switch`를 했다면 영향. 가능성 낮으나 changelog에 명시 필요.
- ABI 변경. 메이저 버전.

### 4.4 작업 단계

1. `LogCategory.swift`를 `struct`로 재정의, 기존 8개를 정적 프로퍼티로 이전.
2. `CaseIterable` 호환을 원하면 별도 `allKnownCases`를 수동 노출.
3. `Logger+Extension.swift`의 static `Logger.network`/`ui`/... 인스턴스들과 `logger(for:)` switch를 캐시 또는 직접 생성 방식으로 교체.
4. README의 카테고리 표를 "기본 제공 카테고리 + 사용자 정의 예시"로 갱신.

### 4.5 검증 방법

- 빌드/테스트.
- 단위 테스트 추가: `Log.debug("CustomCategory", "msg")` 호출이 컴파일되고 출력에 `CustomCategory`가 카테고리로 들어가는지 확인.

### 4.6 우선순위 근거

라이브러리 채택 시 가장 자주 부딪히는 확장 요구. §1·§2와 시그니처 자체가 함께 변경되므로 같은 메이저 릴리스에 포함하면 마이그레이션 부담을 줄일 수 있다.

---

## 5. [MEDIUM] `notice` 레벨 추가 + 레벨별 디스크 기록 동작 문서화

### 5.1 왜 해야 하는가

[OSLogType 공식 문서](https://developer.apple.com/documentation/os/oslogtype)와 [Generating Log Messages from Your Code](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code)에 따르면 OSLogType 케이스는 다섯 가지(`debug`/`info`/`default`/`error`/`fault`)이며 각각의 디스크 기록 정책이 다르다:

| OSLogType | Logger 메서드 | 디스크 기록 | 의도 |
| --- | --- | --- | --- |
| `debug` | `debug`, `trace` | 아니오 (별도 설정 시만) | 개발 verbose. 프로덕션 zero cost. |
| `info` | `info` | log 도구 수집 시만 | 보조 정보. |
| `default` | `notice`, `log` | **예** (할당 한도 내) | 문제 해결의 필수 정보. |
| `error` | `warning`, `error` | 예 + activity chain 캡처 | 프로세스 수준 오류. |
| `fault` | `critical`, `fault` | 예 + activity chain 캡처 | 코드 버그. |

JunLogger는 `notice` (= `OSLogType.default`)에 해당하는 레벨이 없다. 이는 가장 중요한 "항상 디스크 기록되는 일반 운영 메시지" 레벨이 빠진 셈이다. 사용자는 `info`로 적었다가 프로덕션 디바이스에서 로그가 사라진 것을 보고 혼란을 겪을 수 있다.

또한 각 레벨의 디스크 기록 정책이 API 문서 주석에 명시되지 않아, 호출자는 모두 동일하게 영구 보존된다고 오해할 수 있다.

### 5.2 제안 변경

- `notice` 메서드 추가 (`OSLogType.default`에 매핑).
- 모든 레벨 헬퍼의 doc comment에 디스크 기록 정책 명시:
  - `debug`: "기본적으로 디스크에 저장되지 않음. 프로덕션에서는 사실상 비활성."
  - `info`: "log 수집 도구가 활성화된 경우에만 메모리에서 디스크로 이동."
  - `notice`: "기본 디스크 기록 레벨. 운영 상태 추적의 기준점."
  - `warning`/`error`: "디스크 기록 + 호출 activity 체인 캡처."
  - `fault`: "치명적 결함. 디스크 기록 + activity 체인 + crash 인접 활용."

### 5.3 호환성 고려

- 신규 API 추가. 기존 호출 영향 없음.
- §1과 함께 진행 시 `notice` 추가도 새 시그니처로 통일 가능.

### 5.4 작업 단계

1. `Logger+Extension.swift`에 `public func notice(_ message: OSLogMessage, ...)` 추가, 내부적으로 `self.log(level: .default, ...)` 호출.
2. `AppLogger.swift`에 `Log.notice(...)` facade 추가.
3. README의 "로그 레벨" 섹션에 `notice` 행 추가 + 각 레벨의 디스크 기록 동작 표 추가.
4. 단위 테스트: `Log.notice(.general, "msg")`가 크래시 없이 호출되는지.

### 5.5 검증 방법

- 빌드/테스트.
- 디바이스에서 출력 후 `log show --last 1m --predicate 'subsystem == "..."'`로 `notice` 레벨이 영구 저장되는지 확인.

### 5.6 우선순위 근거

OSLog의 의미론을 정확히 반영하는 라이브러리가 되기 위한 필수 보강. `info` 사용 습관이 굳어진 코드베이스에서 프로덕션 디버깅 시 로그 손실을 야기할 수 있는 함정을 사전 차단.

---

## 6. [MEDIUM] `OSSignposter`(iOS 15+) 분기 도입, 카테고리 통합, 미매칭 검증

### 6.1 왜 해야 하는가

[OSSignposter 공식 문서](https://developer.apple.com/documentation/os/ossignposter) (iOS 15.0+ / macOS 12.0+ / watchOS 8.0+ / tvOS 15.0+)는 기존 `os_signpost()` 함수 기반 API의 모든 사용 사례를 대체하며 다음 개선을 제공한다:

1. **`OSSignposter(logger:)`**: 기존 `Logger`의 subsystem/category를 그대로 재사용. → 로그와 signpost를 Instruments에서 같은 lane으로 묶을 수 있다.
2. **`beginInterval(_:id:_:)` → `OSSignpostIntervalState`**: 상태 객체가 begin/end 쌍을 추적. `endInterval(_:state:)`에 잘못된 state를 전달하면 런타임에 검출.
3. **`withIntervalSignpost(_:id:around:)`**: 클로저 기반 측정으로 throws/return 동작과도 자연스러운 매칭, end 누락 위험 제거.
4. **`OSSignposter.disabled`**: 테스트 환경에서 signpost를 끄는 표준 방법.

현재 JunLogger의 signpost 구현은:
- "Performance" 카테고리를 `OSLog(subsystem:category:)`로 매 호출마다 새로 생성 (3회 — `beginSignpost`에서 2회, `endSignpost`에서 1회). `Logger.performance`(이미 동일 카테고리)와 분리되어 Instruments에서 별도 추적.
- begin/end 미매칭 검증 없음. 사용자가 `endSignpost`를 빠뜨리면 무한 interval로 남는다.

### 6.2 제안 변경

iOS 15+ 환경에서는 `OSSignposter`를 사용하고, iOS 14 대상은 기존 `os_signpost`를 fallback으로 유지.

```swift
// 방향 제시
@available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
public static func withSignpost<Result>(
    _ name: StaticString,
    category: LogCategory = .performance,
    around work: () throws -> Result
) rethrows -> Result {
    let signposter = OSSignposter(logger: Logger.logger(for: category))
    return try signposter.withIntervalSignpost(name, around: work)
}
```

기존 `beginSignpost`/`endSignpost`는 deprecated 표시 후 다음 메이저에서 제거.

### 6.3 호환성 고려

- 기존 API는 deprecated로 유지. 호환성 유지.
- iOS 14를 지원하는 한 `#available` 분기가 필요. iOS 14 지원 종료 시 코드 정리 용이하도록 분기를 명확히 작성.

### 6.4 작업 단계

1. `Logger+Extension.swift`에 `@available(iOS 15, *)` 블록으로 `OSSignposter` 기반 헬퍼 추가.
2. 클로저 API(`withSignpost`)를 우선적으로 노출. begin/end 쌍 API도 `OSSignpostIntervalState` 반환 시그니처로 추가.
3. 기존 `beginSignpost(name:)`·`endSignpost(name:signpostID:)`에 `@available(*, deprecated, message: "Use withSignpost(_:around:)")` 표시.
4. "Performance" 하드코딩을 `LogCategory.performance` 파라미터로 교체. 사용자가 다른 카테고리 지정 가능하도록.
5. README의 성능 측정 섹션 갱신.

### 6.5 검증 방법

- Instruments의 "Logging" 또는 "os_signpost" instrument로 signpost가 의도한 카테고리에 들어가는지 확인.
- 단위 테스트는 `withSignpost { return 42 } == 42`처럼 클로저 반환값 검증.

### 6.6 우선순위 근거

기능적 결함은 아니지만 구조적 미흡. 도입 시점이 늦을수록 deprecation 마이그레이션 비용이 커진다.

---

## 7. [MEDIUM] 테스트 가능성 — `LoggingProvider` 프로토콜로 DI 가능하게

### 7.1 왜 해야 하는가

`os.Logger`는 `struct`이며 프로토콜을 conform하지 않는다. JunLogger의 `public enum Log` + static 함수 구조는 **호출자 코드의 단위 테스트에서 로그 호출 여부/내용 검증이 불가능**하다. 예를 들어 "결제 실패 시 `Log.error(.auth, ...)`가 호출되는가"를 검증할 수 없다.

업계 해결책:

- **방법 A (권장)**: 프로토콜 추상화 + DI. 프로덕션 구현체는 `Logger`를 내부에 보유, 테스트 구현체는 호출을 배열에 캡처.
- **방법 B**: `OSLogStore` (iOS 15+)로 실제 OSLog 엔트리를 읽어 assertion. 지연·플레이키 가능성.

JunLogger는 라이브러리 자체이므로 **사용자 측에서 mock 가능성**을 제공하는 것이 핵심 가치. 방법 A를 권장.

### 7.2 제안 변경

```swift
public protocol LoggingProvider {
    func log(level: OSLogType, category: LogCategory, message: OSLogMessage,
             file: String, function: String, line: Int)
}

public enum Log {
    public static var provider: LoggingProvider = OSLogProvider()
    // ...
}
```

테스트:

```swift
final class InMemoryProvider: LoggingProvider { var entries: [...] = []; ... }
Log.provider = InMemoryProvider()
```

### 7.3 호환성 고려

- 기본 동작 유지(자동 `OSLogProvider`). 영향 없음.
- 단, `static var`는 동시성 우려가 있어 §8과 함께 검토. `nonisolated(unsafe)` 또는 락 기반 보호 필요.
- §1과 함께 들어가야 시그니처 한 번에 정착.

### 7.4 작업 단계

1. `LoggingProvider` 프로토콜 정의 (별도 파일 `Sources/JunLogger/LoggingProvider.swift`).
2. 기존 `Logger.logger(for:)` 경로를 감싸는 `OSLogProvider` 기본 구현 추가.
3. `Log.*` static 메서드들이 `provider`를 통해 라우팅하도록 변경.
4. 테스트 타겟에 `InMemoryLogProvider` 헬퍼 추가 (테스트 외부 노출은 신중히).
5. README에 mocking 가이드 추가.

### 7.5 검증 방법

- 단위 테스트: 커스텀 provider 주입 후 `Log.info(...)` 호출 시 entry 캡처되는지.

### 7.6 우선순위 근거

라이브러리 채택 시 "사용자 측 테스트에서 mocking 가능한가"는 평가 기준. 한 번 API를 굳히면 나중에 추가하기 더 어려우므로 §1·§2와 함께 진행 권장.

---

## 8. [MEDIUM] Swift 6 strict concurrency 검증

### 8.1 왜 해야 하는가

Apple Developer Forums [Is OSLog Logger Sendable?](https://developer.apple.com/forums/thread/747816):

> "`Logger` should be `Sendable`. Under the covers it's an immutable struct with a single `OSLog` property, and that is just a wrapper around `os_log_t` which is definitely thread safe." — Apple DTS

Xcode 15.3 RC까지 strict concurrency 모드에서 `static let logger = Logger(...)` 패턴이 경고를 발생시켰으나 **Xcode 16 β3에서 `os.Logger`·`OSLogType` 등이 공식 `Sendable` 어노테이션을 받으면서 해소**되었다.

JunLogger는 `public enum Log`(자동 Sendable) + `static let` Logger 인스턴스 8개를 사용한다. Swift 6 strict 모드에서 클라이언트 코드가 컴파일 경고 없이 사용할 수 있어야 한다.

[Swift Concurrency Adoption Guidelines](https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html)는 라이브러리가 클라이언트의 strict 모드를 막지 않도록 `Sendable`을 명시적으로 다룰 것을 권장한다.

### 8.2 제안 변경

- `swift build -Xswiftc -strict-concurrency=complete`로 컴파일하여 경고 점검.
- 필요 시 static 인스턴스에 `nonisolated(unsafe) static let` 또는 `nonisolated(unsafe)` 선언 추가.
- 7번에서 도입된 `Log.provider`(`static var`)에는 동시성 보호 필요. `OSAllocatedUnfairLock` 또는 actor isolation.

### 8.3 호환성 고려

- ABI 변경 없음. 컴파일러 경고만 정리.

### 8.4 작업 단계

1. CI 또는 로컬에서 `swift build -Xswiftc -strict-concurrency=complete` 실행.
2. 발생한 경고에 대해 case별로 처리:
   - Logger static 인스턴스 → Xcode 16+에서는 자연스럽게 통과. 이전 Xcode 지원 필요 시 `nonisolated(unsafe)`.
   - `Log.provider`(7번) → 락 또는 actor.
3. Package.swift의 `swiftSettings`에 `.enableExperimentalFeature("StrictConcurrency")` 또는 `.swiftLanguageVersion(.v6)` 명시 검토.

### 8.5 검증 방법

- strict 모드 컴파일 경고 0개.
- 호출자 측 Swift 6 모드 프로젝트에서 import 후 경고 없음 확인.

### 8.6 우선순위 근거

라이브러리는 클라이언트보다 한 발 앞서 Swift 6를 검증해두어야 함. 미흡할 경우 클라이언트가 strict 모드를 켜는 순간 라이브러리 발 경고가 쏟아져 라이브러리 교체 압력이 발생.

---

## 9. 작업 순서 / 의존 관계

### 9.1 의존 그래프

```
§2 (prefix 제거) ────┐
                    ├──► §1 (OSLogMessage 전환) ──► §5 (notice 추가, 새 시그니처 사용)
§3 (#fileID)       ──┘                                │
                                                      ▼
                                                §7 (LoggingProvider) ──► §8 (Swift 6 검증)
§4 (카테고리 확장) ───────────────────────────────────┘
§6 (OSSignposter) ──────► (§1과 독립, 병행 가능)
```

### 9.2 권장 PR 분할

- **PR 1 — Foundation (`2.0.0` 메이저 베이스)**: §2 + §3을 한 번에. prefix 제거 + `#fileID` 전환. API 시그니처는 아직 `String`이지만 prefix가 빠져 후속 작업이 쉬워진다.
- **PR 2 — OSLogMessage 전환**: §1 + §5 (`notice` 신규는 새 시그니처로). 호출부 마이그레이션 가이드 동봉.
- **PR 3 — 카테고리 확장**: §4. enum→struct 변경. PR 2에 곁들이거나 분리.
- **PR 4 — Signpost 현대화**: §6. 독립 PR 가능. iOS 14 fallback 분기 포함.
- **PR 5 — Provider DI**: §7. PR 2의 시그니처가 확정된 뒤 진행.
- **PR 6 — Swift 6 strict 검증**: §8. 다른 PR 모두 완료 후 마무리.

### 9.3 릴리스 전략

- §2 + §3은 1.1.0 마이너로도 가능(prefix 변경이 출력 포맷만 바꾸는 경우). 그러나 호출 시그니처 변경이 들어가는 §1 이후 작업과 함께 묶어 `2.0.0` 메이저로 가는 것이 변경 비용 측면에서 합리적.
- `2.0.0`에 §1·§2·§3·§4·§5·§7을 묶고, §6은 같은 마이너 시리즈(`2.1.0`)에서 추가. §8은 패치/마이너로 흡수.

---

## 10. 마이그레이션 가이드 작성 항목 (향후 작업 시 함께 산출)

추후 `2.0.0` PR에서 다음 항목을 포함한 마이그레이션 가이드(`docs/migration-2.0.md`)를 작성할 것:

- 1.x → 2.0 호출부 변경 패턴 표
- 인터폴레이션 사용 사례 (privacy 마커 포함)
- 카테고리 확장 예시 (사용자 정의)
- LoggingProvider mocking 예시 (테스트 코드)
- 호환성 깨지는 케이스 목록 + 컴파일러 에러 메시지 매핑

---

## 11. 검증 체크리스트 (각 PR에서 공통 적용)

- [ ] `swift build` 성공
- [ ] `swift test` 성공
- [ ] `swift build -Xswiftc -strict-concurrency=complete` 경고 0
- [ ] iOS·macOS 빌드 SDK 분리 확인 (가능하면 `xcodebuild` 또는 SPM 멀티 플랫폼 검증)
- [ ] README의 코드 예시가 실제 컴파일되는지 (예시를 Tests에 흡수해서 자동 검증하면 이상적)
- [ ] CHANGELOG 갱신
- [ ] 메이저 변경 시 `docs/migration-X.Y.md` 추가

---

## 12. 참고 자료 (Primary Sources)

- [OSLogPrivacy](https://developer.apple.com/documentation/os/oslogprivacy)
- [OSLogType](https://developer.apple.com/documentation/os/oslogtype)
- [Logger](https://developer.apple.com/documentation/os/logger)
- [Logger.warning(_:)](https://developer.apple.com/documentation/os/logger/warning(_:))
- [OSSignposter](https://developer.apple.com/documentation/os/ossignposter)
- [Recording Performance Data](https://developer.apple.com/documentation/os/recording-performance-data)
- [Generating Log Messages from Your Code](https://developer.apple.com/documentation/os/generating-log-messages-from-your-code)
- [WWDC 2020 Session 10168 — Explore logging in Swift](https://developer.apple.com/videos/play/wwdc2020/10168)
- [WWDC 2023 Session 10226 — Debug with structured logging](https://developer.apple.com/videos/play/wwdc2023/10226/)
- [SE-0274 — Magic File Identifiers](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0274-magic-file.md)
- [SE-0285 — Ease #file Transition](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0285-ease-pound-file-transition.md)
- [apple/swift PR #24336 — OSLog SIL optimization](https://github.com/apple/swift/pull/24336/files)
- [Is OSLog Logger Sendable? — Apple Developer Forums](https://developer.apple.com/forums/thread/747816)
- [Logging in Swift — Peter Steinberger](https://steipete.me/posts/2020/logging-in-swift)
- [OSLog and Unified logging — SwiftLee](https://www.avanderlee.com/debugging/oslog-unified-logging/)
- [Filtering logs in Xcode 15 — nilcoalescing.com](https://nilcoalescing.com/blog/FilteringLogsInXcode15/)
- [Swift Concurrency Adoption Guidelines](https://www.swift.org/documentation/server/guides/libraries/concurrency-adoption-guidelines.html)
- [Apple Swift Log (참고용, 도입은 미권장)](https://github.com/apple/swift-log)
