# 릴리스 / 버전 관리 정책

> 이 문서는 JunLogger의 버전·태그·CHANGELOG·GitHub Releases 운영 규약을 정의한다.
> 사람을 위한 가이드인 동시에, 자동화 도구(Claude Code 포함)가 따를 수 있는 **결정 규칙**을 명세한다.
> 변경 시 `CLAUDE.md`의 해당 섹션도 함께 갱신할 것.

---

## 1. SemVer 결정 규칙

다음 표에 따라 MAJOR / MINOR / PATCH를 결정한다. 모호하면 더 큰 쪽으로 올린다.

| 변경 유형 | 버전 | 예 |
| --- | --- | --- |
| public API 시그니처/시맨틱 변경, 제거, 이름 변경 | **MAJOR** | `Log.debug(.network, "...")` → `Log[.network].debug("...")` |
| `@available(*, deprecated)` 추가 | MINOR | 메서드는 살아있지만 warning |
| 새 public API 추가 (기존 호환) | MINOR | `Log[.x].notice(...)` 노출 |
| 새 카테고리, 새 옵션 등 호환 추가 | MINOR | `LogCategory.payment` 정적 추가 |
| `@available` 최소 OS 상향 (deployment target 올림) | **MAJOR** | iOS 14 → iOS 15 |
| `@available(iOS 16, *)` 같은 새 API를 분기 추가 | MINOR | 하위 호환 보장 |
| `swift-tools-version` 상향 | **MAJOR** | 구 Xcode 차단됨 |
| 버그 수정만, public surface 변화 없음 | PATCH | OSLog 호출 누락 수정 |
| 문서/주석/내부 리팩토링만 | PATCH (또는 릴리스 생략) | README, 내부 helper 정리 |

근거: [semver.org](https://semver.org/) + Apple SPM 권장(`upToNextMajor(from:)`이 기본 의존 형태).

---

## 2. 태그 규약

- **형식**: `X.Y.Z` (v 접두사 **없음**)
- **타입**: annotated (`git tag -a`)
- **메시지**: `Release X.Y.Z` (한 줄)
- **가리키는 커밋**: 해당 릴리스의 모든 변경(CHANGELOG, 문서 포함)이 반영된 main HEAD
- **pre-release**: `X.Y.Z-beta.N`, `X.Y.Z-rc.N`. SPM은 명시적 `.exact(...)` 또는 `.upToNextMajor(from: "X.Y.Z-beta.1")`에서만 선택. 일반 의존자는 자동으로 받지 않음.

생성 절차:

```sh
# 1. main HEAD가 해당 릴리스의 최종 커밋인지 확인
git log --oneline -5

# 2. annotated 태그 생성
git tag -a 2.1.0 -m "Release 2.1.0"

# 3. 원격에 push (브랜치도 함께 push 됐는지 확인)
git push origin 2.1.0
git push origin main
```

근거: Apple swift-log / swift-collections / swift-argument-parser / TCA / Alamofire / Nuke / SwiftLint 10개 라이브러리 전수 조사 결과 v 접두사 없음 + annotated가 표준.

---

## 3. CHANGELOG.md

- **위치**: 저장소 루트 (`/CHANGELOG.md`)
- **형식**: [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
- **섹션 순서**: `Added` → `Changed` → `Deprecated` → `Removed` → `Fixed` → `Security`
- **상단에 `[Unreleased]` 섹션을 항상 유지**. 다음 릴리스 전까지 모든 변경을 여기서 누적.
- 각 버전 헤더: `## [X.Y.Z] - YYYY-MM-DD`
- 하단에 비교 링크: `[2.0.0]: https://github.com/wnsgur9137/JunLogger/compare/1.0.1...2.0.0`
- breaking change는 별도 `### Breaking` 서브섹션 또는 `Removed`/`Changed`에 명시. 마이그레이션 가이드 링크 필수.

PR 단위 갱신 규칙:
1. 모든 PR은 머지 전에 `[Unreleased]` 섹션을 업데이트한다.
2. 릴리스 시점에 `[Unreleased]` 헤더만 `## [X.Y.Z] - YYYY-MM-DD`로 교체하고, 새 빈 `[Unreleased]`를 위에 둔다.

---

## 4. GitHub Releases

- **태그를 push한 직후 반드시 Release 페이지를 생성**한다(태그만 두지 않음).
- 본문 구조:
  ```
  ## Highlights
  - 한 줄로 이번 릴리스의 핵심
  
  ## Breaking Changes
  - (MAJOR일 때만) 항목 + 마이그레이션 가이드 링크
  
  ## Added / Changed / Removed / Fixed
  - CHANGELOG와 동일 항목, PR 링크 포함
  
  ## Migration
  - MAJOR일 때 `docs/migration-X.0.md` 링크 필수
  
  ## Compatibility
  - iOS / macOS / Swift 최소 버전. 변경 시에만.
  
  ## Notes
  - upToNextMajor 사용자에게 영향 등 운영 메모
  ```
- MAJOR 릴리스에는 본문 최상단에 다음 경고를 포함:
  > ⚠️ Breaking change. `Package.swift`의 의존성 버전 제약을 `.upToNextMajor(from: "X.0.0")` 또는 `.exact("X.0.0")`로 갱신해야 자동 업그레이드된다.

자동화 (장기 검토):
- `.github/release.yml`에 PR label(`semver-minor`/`semver-patch`/`breaking`) 기반 카테고리 분류 정의 → GitHub `Generate release notes` 자동 사용.

---

## 5. 마이그레이션 가이드

- **언제 작성하나**: MAJOR 릴리스 시 의무. MINOR 릴리스에서도 deprecation을 추가했다면 작성 권장.
- **위치**: `docs/migration-X.0.md` (MAJOR마다 한 파일).
- **필수 섹션**: (1) 변경 동기, (2) 1.x → X.0 변환 표, (3) 사라진 시그니처 목록, (4) 새 기능, (5) 흔한 컴파일 에러와 대처법, (6) 일괄 변환 가능한 정규식 패턴.
- README 상단·CHANGELOG·GitHub Release 본문 세 곳 모두에서 링크 노출.

---

## 6. PR 라벨 (도입 시)

다음 라벨을 PR에 부착해 CHANGELOG / Release notes 자동 분류 기준으로 사용한다.

| 라벨 | 의미 |
| --- | --- |
| `semver-major` | breaking change 포함 |
| `semver-minor` | 새 기능 추가 (호환) |
| `semver-patch` | 버그 수정 |
| `documentation` | 문서만 |
| `internal` | 내부 변경, 릴리스 노트에서 제외 |

`.github/release.yml`을 도입하면 GitHub이 위 라벨로 자동 분류된 노트를 생성한다.

---

## 7. 의존자 영향 공지

MAJOR 릴리스를 만들 때 다음을 잊지 않는다:

1. `.upToNextMajor(from: "1.0.0")`로 고정한 사용자는 v2.0을 **자동으로 받지 않는다**. Release 본문에 명시.
2. `swift-tools-version`을 올렸다면 그것 자체가 사용자 호환성에 영향. Release 본문에 명시.
3. `@available` 최소 버전을 올렸다면 deployment target이 낮은 사용자는 빌드가 깨진다. Release 본문에 명시.

---

## 8. 릴리스 체크리스트 (사람·자동화 공용)

릴리스를 만들 때 다음 단계를 순서대로 수행한다. 각 단계는 검증 가능한 산출물을 남긴다.

```
☐ 1. 변경 분류 결정 (§1 표) → MAJOR / MINOR / PATCH
☐ 2. `[Unreleased]` 섹션을 새 버전 헤더로 변환, 새 빈 `[Unreleased]`를 위에 둠
☐ 3. CHANGELOG 하단 비교 링크 추가
☐ 4. MAJOR 시 `docs/migration-X.0.md` 작성/갱신
☐ 5. README 상단 마이그레이션 링크 갱신
☐ 6. `swift build` / `swift test` 그린
☐ 7. CHANGELOG·README·migration 변경을 단일 또는 분할 커밋
☐ 8. annotated 태그 생성 (`git tag -a X.Y.Z -m "Release X.Y.Z"`)
☐ 9. `git push origin main` → `git push origin X.Y.Z`
☐ 10. GitHub Releases 페이지에 §4 양식으로 Release 본문 작성
☐ 11. (MAJOR 시) 사내/사용자 채널에 영향 공지
```

---

## 9. 비고

- 이 정책은 활동 빈도가 낮은 라이브러리에서도 일관성을 유지하기 위한 최소 규약이다. 팀이 성장하면 §6 PR 라벨과 GitHub Actions 자동화를 도입한다.
- Apple 1st-party는 CHANGELOG 없이 GitHub Releases만 사용하기도 한다. 본 정책은 Alamofire/SwiftLint/Nuke의 이중 운영을 채택한 더 보수적인 형태다.
- 변경 시 본 문서와 `CLAUDE.md`의 릴리스 섹션을 함께 갱신할 것.
