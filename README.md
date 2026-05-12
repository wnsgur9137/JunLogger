# JunLogger

iOS, macOS, watchOS, tvOS, visionOS를 위한 Apple OSLog 기반 로깅 라이브러리
인터폴레이션 레벨 privacy 마커와 컴파일 타임 lazy evaluation을 그대로 보존하는 얇은 facade

## 주요 기능

- **카테고리 기반 로깅**: 기본 8개 카테고리(Network, UI, Data, Domain, Lifecycle, Auth, Performance, General) 제공 + 사용자 정의 카테고리 자유 추가
- **OSLog native 인터폴레이션**: `\(value, privacy: .private)` 같은 privacy 마커가 호출 위치 그대로 작동
- **Lazy evaluation**: 로그 레벨이 비활성화된 환경에서 인자 표현식이 평가되지 않음
- **DI 가능**: `LoggingProvider` 프로토콜로 테스트 환경에서 로그를 끄거나 교체 가능
- **성능 측정**: Signpost API 제공
- **지원 OS**: iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+

## 요구사항

- iOS 14.0+ / macOS 11.0+ / watchOS 7.0+ / tvOS 14.0+ / visionOS 1.0+
- Swift 5.9+

## 설치

### Swift Package Manager

```swift
dependencies: [
    .package(url: "https://github.com/wnsgur9137/JunLogger.git", from: "2.0.0")
]
```

## 사용법

### 기본 사용

```swift
import JunLogger

Log[.network].debug("GET /api/users")
Log[.ui].info("HomeView appeared")
Log[.data].warning("Cache expired")
Log[.domain].error("UseCase failed")
Log[.general].fault("Unrecoverable state")
Log[.lifecycle].notice("Entered background")
```

`Log[.category]`는 `os.Logger` 인스턴스를 반환하므로 그 위의 `.debug` / `.info` / `.notice` / `.warning` / `.error` / `.critical` / `.fault` 등 모든 OSLog native 메서드를 자유롭게 사용할 수 있다.

### Privacy 마커

JunLogger는 호출 위치의 OSLog 인터폴레이션을 그대로 노출하므로 인자별 privacy 어노테이션이 작동한다.

```swift
Log[.auth].info("user: \(userID, privacy: .private)")
Log[.network].debug("POST \(path, privacy: .public) body: \(body, privacy: .sensitive)")
Log[.auth].error("token: \(jwt, privacy: .private(mask: .hash))")
```

호출자가 `String` 변수를 미리 만들어 `"\(savedMessage)"`로 넘기면 OSLog의 privacy/lazy 최적화 모두 손실되므로, 가능하면 인터폴레이션을 호출 위치에서 작성한다.

### 사용자 정의 카테고리

`LogCategory`는 `ExpressibleByStringLiteral`이므로 문자열 리터럴이 그대로 카테고리가 된다. 기본 8개 외의 도메인 카테고리를 자유롭게 추가할 수 있다.

```swift
Log["Payment"].info("Charged \(amount)")
Log["Analytics"].debug("event: \(name, privacy: .public)")

// 자주 쓰는 카테고리는 extension으로 정적 프로퍼티화하면 편리하다
extension LogCategory {
    public static let payment: LogCategory = "Payment"
    public static let analytics: LogCategory = "Analytics"
}

Log[.payment].info("Charged \(amount)")
```

### 로그 레벨과 디스크 기록 정책

| 메서드 | OSLogType | 디스크 기록 | 의도 |
| --- | --- | --- | --- |
| `debug` / `trace` | `.debug` | 기본 미저장 | 개발 verbose, 프로덕션 zero cost |
| `info` | `.info` | 수집 도구 활성화 시 | 보조 정보 |
| `notice` / `log` | `.default` | 항상 저장 (한도 내) | 운영 상태 추적 기준점 |
| `warning` / `error` | `.error` | 저장 + activity chain | 프로세스 오류 |
| `critical` / `fault` | `.fault` | 저장 + activity chain | 코드 결함 |

운영 환경에서 디바이스 로그를 반드시 남기고 싶다면 `notice` 또는 `error` 이상을 사용한다.

### 성능 측정 (Signpost)

```swift
let signpostID = Log.beginSignpost(name: "Data Loading")
await loadData()
Log.endSignpost(name: "Data Loading", signpostID: signpostID)
```

Instruments의 os_signpost 도구로 시각화한다.

### 로그 끄기 / 테스트 환경 (DI)

`Log.provider`를 교체해 모든 카테고리의 출력을 일괄 끄거나 임의 구현체로 교체한다.

```swift
import JunLogger

// 앱 시작 시점에 한 번만 설정
Log.provider = DisabledLogProvider()
```

테스트:

```swift
override func setUp() {
    super.setUp()
    Log.provider = DisabledLogProvider()
}

override func tearDown() {
    Log.provider = OSLogProvider()
    super.tearDown()
}
```

`Log.provider`는 `nonisolated(unsafe)`이므로 동시 변경은 피한다.

### 직접 Logger 사용 (1.x 호환 경로)

기존 `Logger.network` 등의 정적 프로퍼티는 그대로 유지된다. `Log.provider` DI 경로를 거치지 않는다는 점만 다르다.

```swift
import OSLog
import JunLogger

Logger.network.debug("...")
Logger.auth.error("...")
```

## 로그 확인

### Console.app

1. macOS의 Console.app 실행
2. 시뮬레이터 또는 연결된 디바이스 선택
3. 메타데이터 검색 사용
   - `subsystem:com.your.bundle.id`
   - `category:Network`

Xcode 15 이상의 Debug Console은 카테고리/타입/타임스탬프 컬럼을 토글하고, 검색창에 `category:Auth` 같은 메타데이터 쿼리를 받는다. 별도 prefix 없이도 시각적 구분과 필터링이 가능하다.

### `log` CLI

```sh
log stream --predicate 'subsystem == "com.your.bundle.id" AND category == "Network"'
log show --last 5m --predicate 'subsystem == "com.your.bundle.id"'
```

## 1.x → 2.0 마이그레이션

자세한 변환 가이드는 [docs/migration-2.0.md](docs/migration-2.0.md)를 참고한다.

요약:

```swift
// 1.x
Log.debug(.network, "API 호출 시작")
Log.error(.data, "저장 실패", error: dbError)

// 2.0
Log[.network].debug("API 호출 시작")
Log[.data].error("저장 실패: \(dbError.localizedDescription, privacy: .public)")
```
