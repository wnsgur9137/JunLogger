# JunLogger 1.x → 2.0 마이그레이션 가이드

## 무엇이 바뀌었나

JunLogger 2.0은 wrapper 메서드 방식의 facade를 버리고 `Log[.category]`가 `os.Logger` 인스턴스를 직접 반환하는 subscript 패턴으로 전환했다. 이 변경의 동기는 **OSLog의 인터폴레이션 레벨 privacy 마커와 컴파일 타임 lazy evaluation을 보존**하기 위함이다.

1.x의 `Log.debug(.network, "...")`처럼 메시지를 `String`으로 받는 wrapper는 Swift 컴파일러의 OSLog SIL 최적화 패스가 동작하지 않아 다음 두 가지가 모두 손실됐다.

- `\(value, privacy: .private)` 어노테이션이 무시되어 모든 값이 `.public`으로 노출.
- 로그 레벨이 비활성화된 환경에서도 메시지 인자 표현식이 매번 평가.

2.0은 wrapper를 제거하고 사용자가 직접 `Logger` 인스턴스에 인터폴레이션을 적도록 한다. 호출 위치가 OSLog native call site가 되어 두 최적화가 모두 자연 보존된다.

## 변환 표

| 1.x | 2.0 |
| --- | --- |
| `Log.debug(.network, "msg")` | `Log[.network].debug("msg")` |
| `Log.info(.ui, "msg")` | `Log[.ui].info("msg")` |
| `Log.warning(.data, "msg")` | `Log[.data].warning("msg")` |
| `Log.error(.domain, "msg")` | `Log[.domain].error("msg")` |
| `Log.fault(.general, "msg")` | `Log[.general].fault("msg")` |
| `Log.debug("msg")` | `Log[.general].debug("msg")` |
| (없음) | `Log[.lifecycle].notice("msg")` *(신규)* |
| `Log.error(.auth, "fail", error: e)` | `Log[.auth].error("fail: \(e.localizedDescription, privacy: .public)")` |
| `Log.beginSignpost(name: "X")` | 동일. 변경 없음. |
| `Log.endSignpost(name: "X", signpostID: id)` | 동일. 변경 없음. |
| `Logger.network.debug("...")` (직접 사용) | 동일. 변경 없음. |

## 사라진 시그니처

- `Log.debug`/`info`/`warning`/`error`/`fault` static 메서드. 모두 subscript 패턴으로 대체.
- 메시지 헬퍼의 `file`/`function`/`line` 파라미터. OSLog가 호출 위치를 자동 캡처하므로 불필요.
- 메시지 본문의 이모지·`[file:line] function -` prefix. Console.app·Xcode 15 Debug Console의 메타데이터 컬럼이 같은 정보를 제공.
- `error(_:_:error:)`/`fault(_:_:error:)`의 `Error?` 인자. 호출자가 `\(e.localizedDescription, privacy: .public)`로 직접 인터폴레이션.

## 새 기능

### 1. Privacy 마커

```swift
Log[.auth].info("user: \(userID, privacy: .private)")
Log[.network].debug("body: \(body, privacy: .sensitive)")
Log[.auth].error("token: \(jwt, privacy: .private(mask: .hash))")
```

### 2. Lazy evaluation

로그 레벨이 비활성화된 환경에서 인자 표현식이 평가되지 않는다. 다음 패턴이 안전해진다.

```swift
Log[.data].debug("snapshot: \(makeExpensiveSnapshot(), privacy: .public)")
```

### 3. 커스텀 카테고리

`LogCategory`가 `struct + ExpressibleByStringLiteral`이라 문자열 리터럴이 그대로 카테고리가 된다.

```swift
Log["Payment"].info("Charged \(amount)")

extension LogCategory {
    public static let payment: LogCategory = "Payment"
}
Log[.payment].info("Charged \(amount)")
```

### 4. `notice` 레벨

`OSLogType.default`에 해당하는 `notice` 레벨이 노출된다 (OSLog native API가 그대로 보임). 디스크 기록을 보장하는 운영 메시지에 사용.

```swift
Log[.lifecycle].notice("Entered background")
```

### 5. DI

`LoggingProvider`를 교체해 출력을 일괄 끄거나 임의 구현체로 교체.

```swift
Log.provider = DisabledLogProvider()    // 모든 카테고리 no-op
Log.provider = OSLogProvider(subsystem: "com.custom.subsystem")
```

## 호환되는 API (그대로 사용 가능)

- `Logger.network` / `Logger.ui` / ... 등 8개 static 인스턴스: 직접 사용 그대로 동작.
- `Log.beginSignpost(name:)` / `Log.endSignpost(name:signpostID:)`: 동일.
- `LogCategory.network` / `.ui` / ... 등 8개 정적 프로퍼티: 동일 접근 형태 유지.

## 흔한 컴파일 에러와 해결

### `Cannot convert value of type ... to expected argument type 'LogCategory'`

```swift
// 1.x
Log.debug(.network, "msg")
// 컴파일 에러: 2.0의 Log에는 debug 메서드가 없음
```

해결:

```swift
Log[.network].debug("msg")
```

### `Value of type 'Log.Type' has no member 'debug'`

위와 동일 원인. subscript 패턴으로 변경.

### `Argument 'error' missing` 또는 `Extra argument 'error' in call`

```swift
// 1.x
Log.error(.auth, "fail", error: someError)
```

해결: 호출자가 직접 인터폴레이션.

```swift
Log[.auth].error("fail: \(someError.localizedDescription, privacy: .public)")
```

### `'#file' has been renamed to '#fileID'`

라이브러리 코드에는 `#file` 사용처가 사라졌다. 호출자 코드의 `#file` 사용은 영향받지 않는다.

## 일괄 변환 예시 (정규식)

`sed`/IDE의 정규식 검색으로 다음 패턴을 일괄 변환할 수 있다. 단, `error:` 인자를 사용하는 호출은 손으로 옮긴다.

```text
검색:  Log\.(debug|info|warning|notice|error|fault)\(\.(\w+),\s*(.+)\)
치환:  Log[.$2].$1($3)
```

## 향후 변경 예고

- §6 — `OSSignposter` 기반 새 signpost API (`Log[.x].withSignpost { ... }`) 도입. 기존 `Log.beginSignpost` / `Log.endSignpost`는 한 마이너 동안 유지 후 제거.
- §8 — Swift 6 strict concurrency 모드 검증 완료. 호환성 영향 없을 예정.

자세한 후속 작업 계획은 [docs/improvement-plan.md](improvement-plan.md)를 참고.
