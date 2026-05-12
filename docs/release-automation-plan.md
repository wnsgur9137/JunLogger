# 릴리스 자동화 작업 계획 (Skill + GitHub Actions)

> 작성일: 2026-05-12
> 기준 시점: `77d50bc ⚙️ CLAUDE.md를 v2.x 아키텍처와 릴리스 정책 후크로 갱신`
> 작성 목적: `docs/release-management.md` 정책을 실제로 자동 적용하기 위해 도입할 두 가지 인프라(Claude Skill + GitHub Actions)의 상세 설계를 후속 작업자가 단독으로 PR을 만들 수 있는 수준으로 정리한다.

---

## 0. Context

`docs/release-management.md`로 릴리스/버전/태그/CHANGELOG 정책을 명문화했고, `CLAUDE.md`에 Claude가 매 세션 자동 참조하도록 후크를 박았다. 다만 정책 문서만 있고 실제 자동 적용 인프라가 없다. 이 문서는 두 가지를 같이 도입하기 위한 계획이다.

- **Claude Skill** — 사람 의도가 들어가는 부분(CHANGELOG 정리, 마이그레이션 가이드 초안, 태그 생성)을 일관된 절차로 수행한다.
- **GitHub Actions** — 사람/Claude를 통과해도 깨질 수 있는 부분(clean-room 빌드/테스트, 정책 위반 태그 차단, Release 페이지 publish)을 기계적으로 게이트한다.

두 인프라가 서로를 보완한다. Skill만 있으면 사람이 손으로 태그를 만들 때 보호가 안 되고, Actions만 있으면 사람이 CHANGELOG 정리·migration 작성·커밋 절차를 일관되게 따른다는 보장이 없다.

---

## 1. 작업 분담

```
┌───────────────── 사람 의도 영역 ─────────────────┐
│ PR 단위로 CHANGELOG [Unreleased] 항목 추가        │
│ 버전 결정 (SemVer 분류 표)                        │
│                                                  │
│   ┌──── Claude Skill: /release X.Y.Z ────┐       │
│   │ §2 참고 — CHANGELOG/migration/build/  │       │
│   │ commit/tag 까지                      │       │
│   └─────────────────────────────────────┘       │
└──────────────────────────────────────────────────┘
                       │
                       │ 사용자가 직접 push
                       ▼
┌──────────── 기계 검증·publish 영역 ──────────────┐
│   ┌──── GitHub Actions: release.yml ──────┐      │
│   │ §3 참고 — validate-tag → verify-build │      │
│   │ → publish (Release 페이지 생성)       │      │
│   └───────────────────────────────────────┘      │
└──────────────────────────────────────────────────┘
```

| 단계 | 담당 | 산출물 |
| --- | --- | --- |
| PR 단위 변경 메모 (`[Unreleased]` 추가) | Claude/사람 | CHANGELOG.md PR diff |
| 릴리스 결정 (버전 분류) | 사람 (Claude 추천) | 버전 번호 |
| CHANGELOG `[Unreleased]` → `[X.Y.Z]` 변환, 비교 링크 추가 | **Skill** | CHANGELOG.md |
| (MAJOR) migration guide 작성/링크 | **Skill** | `docs/migration-X.0.md`, README 링크 |
| 로컬 `swift build && swift test` | **Skill** | 통과 |
| 커밋 + annotated 태그 생성 | **Skill** (사용자 승인 후) | 커밋 SHA, 태그 |
| push (main + tag) | 사용자 트리거 | origin 갱신 |
| Clean-room 빌드/테스트 | **Actions** | CI 그린 |
| 태그 형식·메시지·CHANGELOG·migration 정합성 검증 | **Actions** | 8개 체크 통과 |
| Release 페이지 생성 (CHANGELOG 섹션 추출) | **Actions** | GitHub Release |
| (옵션) 사내 알림/DocC 배포 | **Actions** | — |

---

## 2. Claude Skill 설계

### 2.1 위치와 형식

`/Users/leejunhyeok/Xcode/wnsgur9137/JunLogger/.claude/commands/release.md`

Claude Code의 슬래시 명령으로 `/release X.Y.Z` 형태로 호출한다. Skill 내부에는 단계별 절차를 자연어로 명세하고, 각 단계의 검증·실패 처리·사용자 승인 시점을 명시한다.

대안 위치: `~/.claude/commands/release.md` (전역). 그러나 정책이 저장소별로 다르므로 **저장소 로컬**이 적절.

### 2.2 인자

- `X.Y.Z` (필수) — SemVer 버전. `2.1.0`, `2.0.1`, `3.0.0-beta.1` 형태 허용.
- 선택 플래그(미래 확장): `--dry-run`, `--skip-tests` (긴급 핫픽스).

### 2.3 동작 시퀀스

```
1. 인자 파싱
   - SemVer regex 검증: ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?$
   - 형식 위반 시 즉시 중단.

2. 분류 추론
   - 이전 태그(git tag --sort=-v:refname | head -1)와 비교해 MAJOR/MINOR/PATCH 자동 판정.
   - docs/release-management.md §1 표와 git diff 결과를 비교해 분류가 적합한지 점검.
   - 불일치 의심 시 사용자에게 확인.

3. [Unreleased] 점검
   - CHANGELOG.md의 [Unreleased] 섹션을 읽어 비어있는지 확인.
   - 비어있다면 git log <이전 태그>..HEAD --pretty=format:'%h %s'로
     커밋 목록을 분석해 초안 제안 + 사용자 승인.

4. CHANGELOG 변환
   - "## [Unreleased]" 헤더를 "## [X.Y.Z] - YYYY-MM-DD"로 치환.
   - 새 빈 "## [Unreleased]" 헤더를 위에 삽입.
   - 하단에 비교 링크 추가:
     [X.Y.Z]: https://github.com/wnsgur9137/JunLogger/compare/<이전>...X.Y.Z
   - [Unreleased] 링크도 X.Y.Z...HEAD로 갱신.

5. (MAJOR 시) Migration guide
   - docs/migration-X.0.md 존재 여부 확인.
   - 없으면 docs/migration-2.0.md 양식을 템플릿으로 초안 작성 + 사용자 승인.
   - README 상단의 "1.x → 2.0 마이그레이션" 링크 갱신.

6. 빌드/테스트
   - swift build (에러 0 + 경고 0 또는 사용자 확인)
   - swift test (전체 통과)
   - 실패 시 중단.

7. 커밋
   - 이모지+한국어 스타일 (existing project style):
     단일: "🚀 Release X.Y.Z"
     분할: "📝 CHANGELOG.md X.Y.Z 섹션 추가" + (MAJOR 시) "📝 docs/migration-X.0.md 추가"
   - 사용자에게 단일/분할 선택지 제시.

8. Annotated 태그
   - git tag -a X.Y.Z -m "Release X.Y.Z" HEAD
   - 사용자 명시 승인 후에만 실행.

9. Push 안내 (실행은 사용자)
   - 명령 제시:
     git push origin main
     git push origin X.Y.Z
   - push 후 GitHub Actions(.github/workflows/release.yml)가 자동 검증·publish 수행.

10. (MAJOR) 의존자 영향 공지 안내
    - .upToNextMajor(from: "<이전 메이저>.0.0") 사용자는 자동 업그레이드 안 됨.
    - 사내 채널·README 공지 권장.
```

### 2.4 결정 사항

- **위치**: `.claude/commands/release.md` (저장소 로컬).
- **사용자 승인 시점**: §2.3 단계 3(초안 제안), 5(migration 초안), 7(커밋 메시지/분할), 8(태그 생성). 가역 작업은 자동 진행, 비가역/의도 표현 작업은 승인.
- **dry-run 지원**: 1차 버전에서 제외. 추후 추가.
- **트랜잭션성**: 실패 시 자동 롤백은 미구현. 사용자가 git reset/`git tag -d`로 정리. 단계별로 중간 산출물이 명확히 분리되어 있어 수동 정리가 쉽다.

### 2.5 작업 단계

1. `.claude/commands/release.md` 작성 (§2.3 시퀀스를 자연어로 명세).
2. 샘플 시나리오 dry run: 가상의 `2.1.0` 패치 릴리스를 손으로 따라가며 누락 단계 점검.
3. `CLAUDE.md`의 "Release / Versioning" 섹션에 `/release` 명령 호출 안내 추가.
4. `docs/release-management.md` §8 체크리스트와 동기화 확인.

### 2.6 검증 방법

- 가상 시나리오로 손 dry run.
- `2.1.0`에서 실제 릴리스 시도해 실제 동작 검증.
- 실패 시나리오(빌드 깨짐, CHANGELOG 비어 있음, 잘못된 버전)에서 적절히 중단되는지 확인.

---

## 3. GitHub Actions 설계

### 3.1 파일 위치

`/Users/leejunhyeok/Xcode/wnsgur9137/JunLogger/.github/workflows/release.yml`

### 3.2 트리거

- `on: push: tags`로 SemVer 형식 태그만 트리거:
  - `[0-9]+.[0-9]+.[0-9]+` (정식 릴리스)
  - `[0-9]+.[0-9]+.[0-9]+-*` (pre-release)
- 다른 형식의 태그(예: 실험용 `wip-*`)는 자동 무시.

### 3.3 잡 구성 (3단계, 의존성으로 게이트)

#### 3.3.1 `validate-tag` (정책 게이트)

`docs/release-management.md` §1·§2·§3·§5 규약 위반을 사전 차단.

| # | 검증 | 구현 |
|---|---|---|
| 1 | 태그 이름 SemVer | 트리거 regex (자동) |
| 2 | annotated 태그 | `git for-each-ref --format='%(objecttype)' refs/tags/$VERSION` → `tag` |
| 3 | 메시지 `Release X.Y.Z` | `git tag -l --format='%(contents:subject)' $VERSION` |
| 4 | main 조상 | `git merge-base --is-ancestor $VERSION origin/main` |
| 5 | CHANGELOG `## [X.Y.Z]` 섹션 존재 | awk |
| 6 | CHANGELOG 비교 링크 존재 | grep `^\[X.Y.Z\]:.*compare/` |
| 7 | (MAJOR) `docs/migration-X.0.md` 존재 | `test -f` |
| 8 | 버전 monotonicity | `git tag --sort=-v:refname` 비교, `sort -V` |

각 검증은 한 step이며 `::error::` 메시지를 출력 + `exit 1`.

#### 3.3.2 `verify-build` (clean-room)

`needs: validate-tag`.

- `runs-on: macos-latest`
- `maxim-lobanov/setup-xcode@v1` (`xcode-version: latest-stable`)
- `swift build` + `swift test`

검증 통과 시에만 publish로 진행.

#### 3.3.3 `publish` (Release publish)

`needs: [validate-tag, verify-build]`.

- CHANGELOG에서 `## [X.Y.Z]` 섹션부터 다음 `## [` 직전까지 awk로 추출 → `release-body.md`.
- `softprops/action-gh-release@v2`:
  - `body_path: release-body.md`
  - `name: ${{ github.ref_name }}`
  - `prerelease: ${{ contains(github.ref_name, '-') }}` (이름에 `-` 포함 시 자동 prerelease)
- `permissions.contents: write` 필요 (`GITHUB_TOKEN`이 자동 제공).

### 3.4 전체 워크플로우 파일

```yaml
name: Release

on:
  push:
    tags:
      - '[0-9]+.[0-9]+.[0-9]+'
      - '[0-9]+.[0-9]+.[0-9]+-*'

permissions:
  contents: write

jobs:
  validate-tag:
    runs-on: ubuntu-latest
    outputs:
      version: ${{ steps.parse.outputs.version }}
      is_major: ${{ steps.parse.outputs.is_major }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - id: parse
        name: Parse version
        run: |
          VERSION="${GITHUB_REF_NAME}"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          MAJOR="${VERSION%%.*}"
          REST="${VERSION#*.}"
          MINOR="${REST%%.*}"
          PATCH_FULL="${REST#*.}"
          PATCH="${PATCH_FULL%%-*}"
          if [ "$MINOR" = "0" ] && [ "$PATCH" = "0" ]; then
            echo "is_major=true" >> "$GITHUB_OUTPUT"
          else
            echo "is_major=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Tag is annotated
        run: |
          TYPE=$(git for-each-ref --format='%(objecttype)' "refs/tags/${GITHUB_REF_NAME}")
          if [ "$TYPE" != "tag" ]; then
            echo "::error::lightweight 태그입니다. annotated 태그를 만들어야 합니다."
            exit 1
          fi

      - name: Tag message format
        run: |
          SUBJECT=$(git tag -l --format='%(contents:subject)' "${GITHUB_REF_NAME}")
          EXPECTED="Release ${GITHUB_REF_NAME}"
          if [ "$SUBJECT" != "$EXPECTED" ]; then
            echo "::error::태그 메시지 형식 위반. 기대: '$EXPECTED', 실제: '$SUBJECT'"
            exit 1
          fi

      - name: Tag is ancestor of main
        run: |
          git fetch origin main
          if ! git merge-base --is-ancestor "${GITHUB_REF_NAME}" origin/main; then
            echo "::error::태그가 main의 조상이 아닙니다."
            exit 1
          fi

      - name: CHANGELOG section exists
        run: |
          awk -v ver="${GITHUB_REF_NAME}" '
            $0 ~ "^## \\[" ver "\\]" { found=1 }
            END { exit found ? 0 : 1 }
          ' CHANGELOG.md || {
            echo "::error::CHANGELOG.md에 ## [${GITHUB_REF_NAME}] 섹션이 없습니다."
            exit 1
          }

      - name: CHANGELOG compare link exists
        run: |
          if ! grep -q "^\[${GITHUB_REF_NAME}\]:.*compare/" CHANGELOG.md; then
            echo "::error::CHANGELOG.md 하단 [${GITHUB_REF_NAME}] 비교 링크가 없습니다."
            exit 1
          fi

      - name: Migration guide exists (MAJOR only)
        if: steps.parse.outputs.is_major == 'true'
        run: |
          MAJOR="${GITHUB_REF_NAME%%.*}"
          if [ ! -f "docs/migration-${MAJOR}.0.md" ]; then
            echo "::error::MAJOR 릴리스인데 docs/migration-${MAJOR}.0.md가 없습니다."
            exit 1
          fi

      - name: Version monotonicity
        run: |
          PREV=$(git tag --sort=-v:refname | grep -v "^${GITHUB_REF_NAME}$" | head -1 || echo "")
          if [ -n "$PREV" ]; then
            HIGHEST=$(printf '%s\n%s\n' "$PREV" "${GITHUB_REF_NAME}" | sort -V | tail -1)
            if [ "$HIGHEST" != "${GITHUB_REF_NAME}" ]; then
              echo "::error::이전 태그($PREV)보다 낮거나 같은 버전입니다."
              exit 1
            fi
          fi

  verify-build:
    needs: validate-tag
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with:
          xcode-version: latest-stable
      - run: swift build
      - run: swift test

  publish:
    needs: [validate-tag, verify-build]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Extract CHANGELOG section
        run: |
          awk -v ver="${GITHUB_REF_NAME}" '
            $0 ~ "^## \\[" ver "\\]" { capture=1; next }
            capture && /^## \[/ { exit }
            capture { print }
          ' CHANGELOG.md > release-body.md
          test -s release-body.md || { echo "::error::release-body 추출 실패"; exit 1; }
      - uses: softprops/action-gh-release@v2
        with:
          body_path: release-body.md
          name: ${{ github.ref_name }}
          prerelease: ${{ contains(github.ref_name, '-') }}
```

### 3.5 실패 시 동작과 한계

- `validate-tag` 실패 → `verify-build`/`publish` 미실행. **Release 페이지 생성 안 됨**.
- 그러나 태그 자체는 origin에 이미 존재한다는 점이 한계. 자동 삭제는 위험하므로 **알림만**(GitHub UI의 워크플로우 실패 표시) 권장. 사람이 의식적으로 `git push --delete origin X.Y.Z`로 정리.
- `verify-build` 실패 → publish 안 됨. 사람이 코드를 고치고 `vX.Y.Z` 태그를 회수 후 재생성.
- **검증 불가 항목**:
  - SemVer 분류의 의미론적 적합성(시그니처 변경 vs 내부 변경 판정).
  - CHANGELOG 본문의 내용 품질(빈 섹션이 아닌지만 검증).
  - migration guide 완성도(파일 존재 여부만).
- 위 항목은 Skill(§2)의 사용자 승인 단계에서 1차 방어, Actions는 2차 게이트.

### 3.6 작업 단계

1. `.github/workflows/release.yml` 작성.
2. `.github/release.yml`(GitHub 자동 분류용)은 도입 보류. PR 라벨 체계가 정착된 후 §6에서 다시 검토.
3. 커밋 (push는 별도 결정).
4. push 후 즉시 동작 검증을 위해 **테스트용 dry-run 태그**(예: `0.0.0-test.1`)는 만들지 말 것. 워크플로우가 실제 Release를 publish하므로 실수가 외부 visible. 대신 코드 검증은 로컬에서 `act` 또는 GitHub Actions의 `workflow_dispatch` 임시 추가로.

### 3.7 검증 방법

- `act`(로컬 Actions runner)로 trigger 시뮬레이션(가능한 경우).
- 또는 워크플로우에 `workflow_dispatch` 트리거 임시 추가하여 수동 실행 후 제거.
- 실제 검증은 다음 릴리스(`2.0.1` 또는 `2.1.0`) 시점에 일어남. 첫 릴리스에서 의도대로 작동하는지 면밀히 확인.

---

## 4. 운영 모드 (결정 필요 항목)

| 항목 | 선택지 | 권장 |
| --- | --- | --- |
| Actions 검증 강도 | 엄격(8개) / 느슨(빌드만) | **엄격** |
| 검증 실패 태그 처리 | 자동 삭제 / 알림만 | **알림만** |
| Release publish 권한 | `GITHUB_TOKEN` / 별도 PAT | **`GITHUB_TOKEN`** |
| pre-release 표시 | 자동(이름에 `-`) / 명시 | **자동** |
| PR 라벨 체계 | 표준 5개 / 간단 3개 / 없음 | 일단 **없음**, 팀 성장 시 도입 |
| Skill 사용자 승인 단계 | 모든 단계 / 핵심 단계만 | **핵심 단계만**(가역 작업은 자동) |

---

## 5. 작업 순서 / PR 분할 안

### 5.1 의존 관계

```
[Skill]                  [Actions]
  │                         │
  ├─── 독립, 병렬 가능 ─────┤
  │                         │
  └────── 둘 다 도입 후 ────┘
              │
   첫 릴리스(2.0.1 or 2.1.0)
   에서 통합 dry run
```

Skill과 Actions는 서로 의존하지 않는다. 어느 쪽이든 먼저 도입 가능.

### 5.2 권장 PR 분할

- **PR A — Skill 도입**: `.claude/commands/release.md` + `CLAUDE.md`의 호출 안내 갱신. 외부 영향 0. 안전.
- **PR B — Actions 도입**: `.github/workflows/release.yml`. push 후부터 동작. **다음 태그부터 자동 적용**되므로 사전에 §6의 v2.0.0 소급 처리를 결정해둘 것.
- **PR C — (옵션) PR 라벨 체계 + `.github/release.yml`**: 팀이 커진 후. `release-management.md` §6 참고.

### 5.3 릴리스 전략

- PR A, PR B는 자체로 별도 릴리스 대상이 아니다(라이브러리 동작 무영향). CHANGELOG `[Unreleased]`에 항목만 추가.
- 다음 정식 릴리스(예: `2.0.1` 또는 `2.1.0`) 때 통합 시험.

---

## 6. v2.0.0 소급 처리 (별도 결정 사항)

현재 `2.0.0` 태그는 Actions 도입 이전에 push되어 워크플로우 트리거가 일어나지 않았다. GitHub Release 페이지도 없다.

선택지:

| 옵션 | 설명 | 비고 |
| --- | --- | --- |
| (a) 수동 1회 생성 | GitHub UI에서 `2.0.0` Release를 손으로 생성, body는 CHANGELOG의 `[2.0.0]` 섹션 복사 | 가장 단순, 권장 |
| (b) 태그 재push로 워크플로우 트리거 | `git push --delete origin 2.0.0 && git push origin 2.0.0` | 시간상 hash 동일하나 Actions 입장에서 새 push로 인식, 다만 강제 push 유발 위험 |
| (c) `workflow_dispatch` 트리거로 단발 실행 | 워크플로우에 input으로 버전 받는 dispatch 잡 추가 | 코드 복잡도 증가 |

권장: **(a) 수동 1회 생성**. 한 번만 하면 됨.

---

## 7. 아직 결정·작성 안 된 것 (체크리스트)

- [ ] Skill 도입 PR A
- [ ] Actions 도입 PR B
- [ ] PR B push 시점 결정
- [ ] v2.0.0 Release 페이지 소급 생성 (§6 옵션 a 권장)
- [ ] PR 라벨 체계 도입 시기 결정 (PR C)
- [ ] 첫 릴리스(`2.0.1` or `2.1.0`)에서 Skill+Actions 통합 dry run
- [ ] `docs/release-management.md` §6 라벨 표 갱신 (PR C 시점)
- [ ] (장기) Slack/사내 채널 알림 워크플로우 추가
- [ ] (장기) DocC + Swift Package Index `.spi.yml` 도입

---

## 8. 다음 액션 후보

| 옵션 | 내용 | 외부 영향 |
| --- | --- | --- |
| (1) Skill만 먼저 | `.claude/commands/release.md` 작성 + 커밋 | 0 (저장소 내부만) |
| (2) Actions만 먼저 + push | `.github/workflows/release.yml` 작성 + push | 다음 태그부터 외부 visible |
| (3) 둘 다 작성 + 커밋 (push 미정) | 인프라 준비 완료, 적용은 push 시 | 0 (push 전까지) |
| (4) 둘 다 + push + v2.0.0 소급 | 즉시 가동 + 과거 정리 | 즉시 외부 visible |

작업 재개 시 위 옵션 중 하나를 선택해 진행한다.

---

## 9. 참고 자료

- `docs/release-management.md` — 정책 본문 (이 문서가 자동화하려는 대상)
- `CLAUDE.md` — Claude가 매 세션 자동 참조하는 후크 (Skill 호출 안내가 들어갈 곳)
- `docs/improvement-plan.md` — 라이브러리 기능 개선 백로그 (별도, 본 문서와 무관)
- [softprops/action-gh-release v2 — GitHub Marketplace](https://github.com/softprops/action-gh-release)
- [maxim-lobanov/setup-xcode — GitHub Marketplace](https://github.com/maxim-lobanov/setup-xcode)
- [Automatically generated release notes — GitHub Docs](https://docs.github.com/en/repositories/releasing-projects-on-github/automatically-generated-release-notes)
- [Keep a Changelog 1.1.0](https://keepachangelog.com/en/1.1.0/)
