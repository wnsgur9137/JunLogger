---
description: JunLogger 릴리스 워크플로우 (CHANGELOG/migration/build/tag) 일관 실행
argument-hint: <X.Y.Z>
---

# /release — JunLogger 릴리스 슬래시 명령

이 명령은 `docs/release-management.md` 정책과 `docs/release-automation-plan.md` §2의 설계를 그대로 자동화한다. `$ARGUMENTS`로 받은 버전 `X.Y.Z`에 대해 CHANGELOG 갱신·migration guide·로컬 빌드/테스트·커밋·annotated 태그 생성까지 수행하고, push와 GitHub Release publish는 사용자/Actions에 위임한다.

## 인자

`$ARGUMENTS` = `X.Y.Z` (필수). `2.1.0`, `2.0.1`, `3.0.0-beta.1` 같은 SemVer 형식.

## 절대 규칙

- 사용자 명시 승인 없이 `git push`, `git tag` 삭제, `git reset --hard`, `git rebase`, GitHub Release publish, `gh` API를 통한 외부 작업은 **금지**.
- 어느 단계에서든 빌드/테스트가 실패하면 즉시 중단하고 사용자에게 보고. 자동 우회 금지.
- 커밋 메시지는 이 저장소의 스타일(이모지 prefix + 한국어 본문 + Co-Authored-By trailer)을 따른다.

## 실행 순서

### 1. 인자 파싱과 형식 검증

- `$ARGUMENTS`가 빈 문자열이면 사용자에게 버전을 묻고 중단.
- 정규식 `^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$`로 검증. 위반 시 중단.

### 2. SemVer 분류 추론과 사용자 확인

- 이전 정식 태그를 구한다: `git tag --sort=-v:refname | grep -v -- '-' | head -1`.
- MAJOR/MINOR/PATCH 차이를 식별. 예: `2.0.0 → 2.1.0`이면 MINOR.
- `docs/release-management.md` §1 표와 비교해 분류가 합당한지 검증.
  - PATCH로 분류했는데 `git diff <이전>..HEAD -- Sources/` 출력에 public 시그니처 변경이 보이면 사용자에게 분류 적합성 확인.
  - MAJOR로 분류했는데 Sources/ 변경이 거의 없으면 사용자에게 확인.
- 추론 결과(MAJOR/MINOR/PATCH)와 근거를 한 줄로 사용자에게 보고.

### 3. CHANGELOG `[Unreleased]` 점검

- `CHANGELOG.md`의 `## [Unreleased]` 섹션이 비어 있는지 확인.
- 비어 있으면 `git log <이전 태그>..HEAD --oneline`을 보고 Added/Changed/Fixed 초안을 제안 + 사용자 승인을 받은 뒤 `[Unreleased]`에 채운다.
- 사용자가 거부하면 작업을 중단하고 직접 채워달라고 요청.

### 4. CHANGELOG 변환

- `## [Unreleased]` 한 줄을 `## [X.Y.Z] - YYYY-MM-DD`로 치환. 날짜는 시스템의 현재 날짜(로컬 시간).
- 새 빈 `## [Unreleased]` 헤더를 그 위에 삽입.
- 파일 하단에 비교 링크 추가:
  ```
  [X.Y.Z]: https://github.com/wnsgur9137/JunLogger/compare/<이전 태그>...X.Y.Z
  ```
- `[Unreleased]` 링크도 `X.Y.Z...HEAD`를 가리키도록 갱신.
- Edit 도구로 수행. 이후 사용자가 diff를 검토할 수 있게 변경 위치를 보고.

### 5. (MAJOR 시) Migration guide

- MAJOR가 아니면 이 단계 스킵.
- `docs/migration-X.0.md` 존재 여부 확인.
- 없으면 `docs/migration-2.0.md`를 템플릿으로 초안을 만들고 사용자에게 보여준 뒤 승인을 받는다.
- README의 "X.x → X+1.0 마이그레이션" 링크가 최신을 가리키는지 확인하고 필요 시 갱신.

### 6. 로컬 빌드/테스트

- `swift build` 실행. 에러 발생 시 즉시 중단하고 출력 보고.
- `swift test` 실행. 실패 시 중단.
- 통과 시 한 줄로 결과 보고("build OK / tests N passed").

### 7. 커밋 (단일 또는 분할)

- 변경 범위에 따라 분할 또는 단일 커밋을 사용자에게 제안.
  - 분할 예: `📝 CHANGELOG.md X.Y.Z 섹션 추가` + (MAJOR 시) `📝 docs/migration-X.0.md 추가`.
  - 단일 예: `🚀 Release X.Y.Z`.
- 메시지 본문은 한국어로, 무엇이 왜 변경됐는지 1~3문장.
- `Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>` trailer 포함.
- 사용자 승인 후 `git add` + `git commit`. 다른 파일이 섞이지 않도록 명시적 파일 단위 add.

### 8. Annotated 태그 생성

- 사용자에게 태그 생성 의사 명시적 확인.
- 명령: `git tag -a X.Y.Z -m "Release X.Y.Z" HEAD`.
- 생성 후 `git show X.Y.Z --no-patch --oneline | head -3`로 결과 검증.

### 9. Push 안내 (실행은 사용자가 직접)

다음 명령을 그대로 사용자에게 보여준다:

```
git push origin main
git push origin X.Y.Z
```

push 직후 `.github/workflows/release.yml`이 자동 트리거되어 validate-tag → verify-build → publish 잡이 실행되고, 통과 시 GitHub Release 페이지가 생성됨을 안내.

### 10. (MAJOR 시) 의존자 영향 공지 안내

다음 메시지를 사용자가 사내 채널·README 공지에 사용할 수 있도록 제시:

```
JunLogger X.0.0 릴리스 안내
- Breaking change 포함. 마이그레이션 가이드: docs/migration-X.0.md
- .upToNextMajor(from: "<이전 메이저>.0.0")로 의존하는 프로젝트는 자동 업그레이드되지 않습니다.
  Package.swift를 .upToNextMajor(from: "X.0.0")으로 변경 후 swift package update 실행이 필요합니다.
```

## 실패 처리

- 어떤 단계가 실패하든 부분 진행 상태를 사용자에게 보고. 자동 롤백 금지.
- 사용자가 직접 정리할 수 있도록 다음 명령을 안내(필요 시):
  - 커밋 되돌리기: `git reset --soft HEAD~1` 후 unstage
  - 태그 삭제: `git tag -d X.Y.Z` (push 전이라면 안전)
  - CHANGELOG 복원: 마지막 커밋 이전으로 revert

## 검증

이 명령이 의도대로 작동하는지는 다음 시점에 확인한다:
- 다음 정식 릴리스(`2.0.1` 또는 `2.1.0`)에서 실제 사용.
- 각 단계의 사용자 승인 시점이 적절한지(과도하거나 부족하지 않은지) 사용자 피드백을 받아 본 파일을 수정.

## 참조

- 정책: [`docs/release-management.md`](../../docs/release-management.md)
- 설계: [`docs/release-automation-plan.md`](../../docs/release-automation-plan.md) §2
- 정책 후크: [`CLAUDE.md`](../../CLAUDE.md) "Release / Versioning" 섹션
