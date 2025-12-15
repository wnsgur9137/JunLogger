# JunLogger

iOS, macOS, watchOS, tvOS, visionOS를 위한 간편하고 강력한 로깅 라이브러리
Apple의 통합 로깅 시스템(OSLog)을 기반으로 한 인터페이스

## 주요 기능

- **카테고리 기반 로깅**: Network, UI, Data, Domain, Lifecycle, Auth, Performance, General
- **다양한 로그 레벨**: Debug, Info, Warning, Error, Fault
- **성능 측정**: Signpost를 활용한 성능 프로파일링
- **풍부한 컨텍스트**: 파일명, 함수명, 라인 번호 자동 포함
- **애플 생태계 전체 지원**: iOS 14+, macOS 11+, watchOS 7+, tvOS 14+, visionOS 1+

## 요구사항

- iOS 14.0+
- macOS 11.0+
- watchOS 7.0+
- tvOS 14.0+
- visionOS 1.0+
- Swift 5.9+

## 설치

### Swift Package Manager

Xcode에서 `File > Add Package Dependencies...`를 선택하고 다음 URL을 입력:

```
https://github.com/wnsgur9137/JunLogger.git
```

또는 `Package.swift` 파일에 직접 추가:

```swift
dependencies: [
    .package(url: "https://github.com/wnsgur9137/JunLogger.git", from: "1.0.0")
]
```

## 로그 카테고리

| 카테고리 | 용도 |
|---------|------|
| `.network` | API 호출, 네트워크 요청/응답 |
| `.ui` | 화면 전환, 사용자 인터랙션 |
| `.data` | Repository, Database, Cache |
| `.domain` | UseCase, 비즈니스 로직 |
| `.lifecycle` | 앱 시작/종료, 백그라운드 전환 |
| `.auth` | 인증, 보안 관련 |
| `.performance` | 성능 측정 |
| `.general` | 일반 로그 |

### Xcode 콘솔에서 확인

Xcode 콘솔에서 이모지와 함께 로그 표시:
- 🔨 Debug
- ℹ️ Info
- ⚠️ Warning
- ❗ Error
- 🚨 Fault

## 사용법

### 기본 로깅

```swift
import JunLogger

// 카테고리와 함께 로그 출력
Log.debug(.network, "API 호출 시작")
Log.info(.ui, "HomeView appeared")
Log.warning(.data, "데이터 경고")
Log.error(.domain, "데이터 처리 실패", error: someError)
Log.fault(.general, "크래시 발생 가능")

// 카테고리 생략 시 .general 사용
Log.debug("일반 디버그 로그")
Log.info("일반 정보 로그")
```

### 카테고리별 로깅

```swift
// Network 카테고리
Log.debug(.network, "GET /api/users")
Log.info(.network, "응답 수신: 200 OK")

// UI 카테고리
Log.info(.ui, "화면 전환: HomeView -> ProfileView")
Log.debug(.ui, "버튼 탭: \(buttonTitle)")

// Data 카테고리
Log.debug(.data, "CoreData 저장 시작")
Log.error(.data, "데이터베이스 저장 실패", error: dbError)

// Domain 카테고리
Log.info(.domain, "UseCase 실행: FetchUserUseCase")
Log.warning(.domain, "비즈니스 로직 경고")

// Lifecycle 카테고리
Log.info(.lifecycle, "앱 시작됨")
Log.debug(.lifecycle, "백그라운드로 전환")

// Auth 카테고리
Log.info(.auth, "로그인 성공")
Log.error(.auth, "인증 실패", error: authError)
```

### 성능 측정

```swift
// 성능 측정 시작
let signpostID = Log.beginSignpost(name: "데이터 로딩")

// 시간이 걸리는 작업 수행
await loadData()

// 성능 측정 종료
Log.endSignpost(name: "데이터 로딩", signpostID: signpostID)
```

Instruments의 os_signpost 도구를 사용하여 성능 데이터를 시각화

### Logger 직접 사용

카테고리별 Logger를 직접 사용 가능:

```swift
import OSLog
import JunLogger

Logger.network.debug("네트워크 요청 시작")
Logger.ui.info("UI 업데이트 완료")
Logger.data.warning("캐시 만료 경고")
Logger.domain.error("도메인 로직 오류", error: error)
```

## 로그 확인

### Console.app에서 확인

1. macOS의 Console.app 실행
2. 시뮬레이터 또는 연결된 디바이스 선택
3. 검색 필터 사용:
   - `subsystem:com.junhyeok.Streaming` (또는 앱의 Bundle Identifier)
   - `category:Network` - 네트워크 로그만 보기
   - `category:UI` - UI 로그만 보기