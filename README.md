# Wise Vibe - 바이브 코딩 + AI 소스 리뷰

MacOS(Seoul 기준)에서 **바이브 코딩** 환경(Gemini/Claude/Ollama 등)을 구성하고, GitHub 저장소에 대한 **AI 기반 소스 리뷰**와 **배포·보안 addon**을 한 번에 설정합니다.

---

## 저장소 구조

| 파일 | 설명 |
|------|------|
| `install.sh` | **단일 진입점.** curl 원라인 설치 + 바이브 환경 구성. `~/.wise_vibe/share/` 에 `.env.example`, `review_source.sh`, `get-stars.sh`, `install.sh` 다운로드. 설치 직후 서비스 선택(1~5)·API 키·.env 저장. `setup_vibe` 는 로컬 `install.sh --setup` 실행 |
| `uninstall.sh` | curl 원라인으로 설치 환경 초기화. `~/.wise_vibe` 삭제 및 셸 프로파일에서 PATH 제거 |
| `.env.example` | 서비스별 API 키·모델 등 환경 변수 템플릿 (Gemini, Claude, Ollama, Cursor, Cline 블록) |
| `review_source.sh` | GitHub 저장소 클론 → 저장소 URL·개요(README)·구조 다이어그램(소스별 설명)·상세 분석(소스별 설명·AI)·review_addon 생성 |
| `get-stars.sh` | GitHub 사용자 스타 저장소 URL만 가져와 `USER-stars.list` 생성. **이미 파일이 있으면 스킵 후 URL 개수만 표시.** `review_all.sh` 에서 해당 파일이 있으면 API 호출 없이 이 목록 사용. 설치 시 `get_stars` 로 PATH에서 실행 가능 |
| `review_all.sh` | GitHub 사용자 스타 저장소 전체 목록(페이지네이션) 조회 → 시작/끝 번호·G/C/B/S 선택 입력 → `_sources/` 하위에 클론·`review_source` 실행. 이미 REVIEW.md 있으면 스킵. `USER-stars.list` 가 있으면 API 대신 해당 파일 사용. `./review_all.sh [username]` |
| `README.md` | 본 문서 |
| `LICENSE` | MIT |

---

## 설치 및 실행

### 1. 설치 (최초 1회)

```bash
curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/install.sh | bash
```

- **단일 파일**: `install.sh` 하나로 다운로드·설치·바이브 환경 구성(서비스 선택 1~5, API 키, .env 저장)까지 진행합니다.
- **로컬에 다운로드되는 파일**: `~/.wise_vibe/share/` 에 **.env.example**, **review_source.sh**, **get-stars.sh**, **install.sh** 가 저장됩니다. **review_source**, **get_stars** 명령은 `~/.wise_vibe/bin` 에서 실행됩니다.
- **setup_vibe**: `setup_vibe` 명령은 로컬 `~/.wise_vibe/share/install.sh --setup` 을 실행해 서비스 선택 메뉴를 띄웁니다(터미널 입력 정상 동작).
- **PATH**: `~/.wise_vibe/bin` 이 셸 프로파일(`.zshrc` 또는 `.bash_profile`)에 추가됩니다.
- **의존성**: Homebrew, Node, tree 가 없으면 설치를 시도합니다.

### 2. 환경 초기화 (제거)

설치한 Wise Vibe 환경을 되돌리려면 아래를 실행합니다. **curl로 원격 uninstall.sh를 실행**하며, 확인 후 `~/.wise_vibe` 삭제와 셸 프로파일에서 `wise_vibe` PATH 한 줄을 제거합니다. Homebrew, Node, tree, Gemini/Claude CLI 등은 제거하지 않습니다.

```bash
curl -fsSL https://raw.githubusercontent.com/WisemanLim/pub-wise-vibe/refs/heads/main/uninstall.sh | bash
```

- 실행 시 "계속하시겠습니까? (y/N):" 에서 **y** 입력 후 엔터하면 초기화가 진행됩니다. (curl 파이프 실행 시에도 터미널에서 입력받도록 처리됨)
- 확인 없이 제거하려면: `curl -fsSL .../uninstall.sh | bash -s -- -y`
- 완료 후 새 터미널을 열거나 `source ~/.zshrc`(또는 `source ~/.bash_profile`)를 실행해 PATH 변경을 반영하세요.

### 3. 셸 반영 후 바이브 환경 재구성 (선택)

설치 시 이미 서비스 선택이 한 번 진행됩니다. 나중에 서비스를 바꾸거나 다시 설정하려면:

```bash
source ~/.zshrc   # 또는 source ~/.bash_profile
setup_vibe
```

- **실행 명령**: `setup_vibe` (PATH에 등록). 로컬 `install.sh --setup` 을 호출해 1~5번 서비스 선택, API 키·추가 정보 입력, 'Hi' 테스트, `.env` 저장을 진행합니다.

---

## 요구사항 (Pre-PRD 기준)

- **OS**: MacOS (Linux/Kali/Ubuntu에서도 git·bash·curl 사용 가능하나, 설치 스크립트는 MacOS 기준).
- **필수**: Git, **Node.js 20+** (`brew install node`), **tree** (`brew install tree`).
- **선택**: Homebrew(미설치 시 설치 스크립트에서 안내), VSCode(Claude/Cline 등 확장 사용 시).
- **바이브 CLI**: `setup_vibe` 완료 후 `gemini` 또는 `claude` 명령 사용 가능.
- **리뷰**: `review_source` 는 로컬에 설치된 `review_source.sh` 를 사용하며, Gemini/Claude CLI가 있으면 AI 분석을 수행합니다. `get_stars` 는 스타 저장소 URL 목록(`USER-stars.list`)을 생성하며, `review_all.sh` 에서 해당 파일이 있으면 API 호출 없이 사용할 수 있습니다.

---

## 명령어 상세

### setup_vibe

- **역할**: 바이브 코딩에 쓸 서비스 선택(1~5) → API 키·모델 등 입력 → 'Hi' 테스트 → 현재 디렉터리 `.env` 에 저장(없으면 생성, 있으면 temp 출력 후 수동 병합 안내).
- **실행 위치**: 프로젝트 루트에서 실행 권장(`.env` 가 해당 디렉터리에 생성됨).
- **동작 방식**: 로컬 `~/.wise_vibe/share/install.sh --setup` 을 호출합니다. (설치 시와 동일한 설정 플로우.)

### review_source

- **사용법**: `review_source <github_url> [url2 ...]` (실행 디렉터리의 `.env` 또는 `~/.wise_vibe/share/.env.example` 에서 API 키를 로드·export 함.)
- **역할**:
  1. GitHub 저장소 클론(여러 URL 시 저장소 이름으로 디렉터리 생성).
  2. AI 리뷰 서비스 선택: **G**emini / **C**laude / **B**oth(비교) / **S**KIP(clone만). 기본값 G. 환경에 따라 설치 여부(✓/✗) 표시.
  3. clone한 저장소 경로에서 **REVIEW.md** 생성:
     - **저장소 URL** 표시
     - **1. 개요**: 저장소에 README.md가 있으면 해당 내용(앞 200줄)
     - **2. 구조 다이어그램**: 트리 + **주요 경로 설명**(소스별 첫 주석/독스트링 기반 한 줄 설명)
     - **구성 요소**: FE/BE/DB·설치 파일 수
     - **3. (Gemini/Claude) 상세 분석**: 구성요소별 파일·기능 목록(소스별 설명·함수/클래스 추출) + AI 분석. AI CLI 실패 시에도 로컬 상세 분석은 포함됨.
     - **4. 개선 addon**: 배포·보안·CI 등 권고
  4. Both 선택 시 **REVIEW_gemini.md**, **REVIEW_claude.md** 와 **REVIEW.md** 비교 요약.
  5. 모든 과정 후 상위 디렉터리로 복귀.

### get_stars (선택)

- **사용법**: `get_stars [GitHub_username]` (기본값: WisemanLim). 설치 시 `~/.wise_vibe/bin` 에 등록되어 PATH에서 실행 가능.
- **역할**: 해당 사용자의 스타 저장소 **URL만** GitHub API로 가져와 현재 디렉터리에 **`USER-stars.list`** 를 생성합니다. **이미 `USER-stars.list` 가 있으면** API를 호출하지 않고 스킵하며, 기존 파일의 URL 개수만 표시합니다. 이 파일이 있으면 `review_all.sh` 가 API 호출 없이 이 목록을 사용합니다.
- **요구**: `curl`, `jq`(권장), `GITHUB_TOKEN`(선택).

### review_all (선택)

- **사용법**: `./review_all.sh [GitHub_username]` (기본값: WisemanLim). `review_source`가 PATH에 있어야 함.
- **역할**:
  1. **`USER-stars.list`** 가 현재 디렉터리(또는 상위)에 있으면 API 호출 없이 해당 파일의 URL 목록을 사용합니다. 없으면 해당 사용자의 **스타 저장소 전체** 목록을 GitHub API로 가져옵니다(페이지네이션, 전체 개수 표시). (`get_stars` 로 미리 생성 가능.)
  2. **시작 번호**(0 또는 비우면 전체), **끝 번호**(비우면 마지막까지) 입력으로 처리 범위 지정.
  3. **선택 (G/C/B/S)** 입력: G=Gemini, C=Claude, B=Both, S=SKIP(clone만). 선택한 값이 모든 대상 repo에 적용됩니다.
  4. **`_sources/`** 디렉터리를 만들고, 그 안에서 각 repo를 클론한 뒤 `review_source <url>` 실행. 이미 `_sources/<repo>/REVIEW.md` 가 있으면 해당 repo는 스킵.
- **요구**: `curl`, `jq`(권장, 없으면 grep/sed로 파싱). `GITHUB_TOKEN`(선택) 설정 시 API 제한 완화(스타 수가 많을 때 권장).

---

## 서비스 선택 (setup_vibe 1~5번)

| 번호 | 서비스 | 필요 입력 | 비고 |
|------|--------|-----------|------|
| 1 | Gemini CLI | API 키 (https://aistudio.google.com/apikey), 모델(기본 gemini-2.0-pro-exp) | npm 전역 설치, 'Hi' 테스트, **review_source 사용 가능** |
| 2 | Claude Code | API 키 (console.anthropic.com), 모델(기본 claude-3.7-sonnet) | npm 전역 설치, 'Hi' 테스트, **review_source 사용 가능** |
| 3 | Continue + Ollama | Ollama 모델(기본 deepseek-coder:6.7b-q4_K_M) | API 키 불필요, 로컬 GPU, VSCode Continue 권장 |
| 4 | Cursor | API 키, 기본 모델 | IDE 설치. **review_source 미지원** → 아래 "Cursor/Cline 리뷰 가이드" 참고 |
| 5 | Cline | OpenAI/Anthropic API 키, Provider | VSCode 확장. **review_source 미지원** → 아래 "Cursor/Cline 리뷰 가이드" 참고 |

- **.env 활용**: 이미 `.env` 가 있으면 해당 서비스 블록 변수를 불러와 “현재 값 사용(Y/N)” 선택(기본 Y) 후 재사용하거나 새로 입력할 수 있습니다.
- **저장**: 입력값은 서비스 블록별로 `.env` 또는 `.env.temp` 형태로 저장되며, `.env` 가 없으면 생성, 있으면 수동 병합 안내가 나옵니다.

---

## Cursor (IDE) · Cline 상세 가이드

### Cursor (4번 선택 시)

- **설치**
  1. [cursor.com](https://cursor.com)에서 다운로드 후 설치.
  2. 실행 후 **Settings (Cmd+,)** → **Cursor Settings** → **API** 에서 OpenAI / Gemini / Anthropic 등 연결.
  3. 프로젝트 규칙은 `.cursor/rules/` (예: `bio.md`) 에 추가 권장.
- **사용**
  - **Cmd+K**: 인라인 편집  
  - **Cmd+L**: 채팅  
  - **Agent**: 멀티파일 작업  
  - 터미널에서 `cursor-agent` (CLI) 사용 가능.
- **참고**: `review_source` 는 **Gemini/Claude CLI**만 사용하므로 Cursor에서는 사용할 수 없습니다. 리뷰가 필요하면 아래 "review_source와 유사한 방법"을 따르세요.

### Cline (5번 선택 시)

- **설치**
  1. VSCode 실행 후 **Extensions (Cmd+Shift+X)** 에서 **Cline** 검색.
  2. **cline-ai.cline** 설치 후 VSCode 재시작.
  3. **Ctrl+Shift+J** 또는 사이드바 Cline 아이콘 → **Settings** → **API Key** (OpenAI 또는 Anthropic) 설정.
  4. CLI에서 설치: `code --install-extension cline-ai.cline`
- **사용**
  - 사이드바 **Cline** 패널에서 채팅. **Plan/Act** 모드로 파일 생성·수정 가능.
  - `@파일명`, `@폴더명` 으로 컨텍스트 지정.
- **참고**: `review_source` 는 **Gemini/Claude CLI**만 사용하므로 Cline에서는 사용할 수 없습니다. 리뷰가 필요하면 아래 "review_source와 유사한 방법"을 따르세요.

---

## review_source와 유사한 방법 (Cursor / Cline 사용자)

`review_source.sh` 는 **터미널에서 동작하는 Gemini/Claude CLI**를 전제로 하므로, **Cursor** 또는 **Cline**만 사용하는 환경에서는 그대로 실행할 수 없습니다. 아래 방법으로 **동일한 결과(REVIEW.md + 배포·보안 addon)** 에 가깝게 진행할 수 있습니다.

### 1. 저장소 클론 및 폴더 열기

```bash
git clone <repo_url>
cd <repo_name>
```

- **Cursor**: **File > Open Folder** 로 `<repo_name>` 선택.
- **Cline**: **VSCode**에서 **File > Open Folder** 로 `<repo_name>` 선택.

### 2. AI로 REVIEW.md 생성 (Cursor 또는 Cline 채팅)

채팅에 아래 프롬프트를 그대로 붙여 넣어 요청합니다.

```
이 저장소를 분석해서 REVIEW.md를 만들어줘. 다음 내용을 한국어 Markdown으로 작성해줘.

1. 구조 다이어그램: FE/BE/DB/설치 스크립트 관계를 텍스트 다이어그램으로 요약
2. 디렉토리별 상세: 파일 목록, 기능, 호출 관계
3. BE API 예제: 엔드포인트 사용법 (curl 예시)
4. 총론: 전체 개요, 부족점(보안/HTTPS/Docker-compose 등), 개선 권고사항
```

생성된 내용을 프로젝트 루트에 `REVIEW.md` 로 저장하면 됩니다.

### 3. review_addon과 유사한 산출물이 필요할 때

- **옵션 A**: Gemini 또는 Claude CLI를 한 번만 설치한 뒤, 해당 저장소에서 `review_source <repo_url>` 을 한 번 실행해 **review_addon** (docker-compose, nginx.conf, security_audit.sh 등)만 생성해 두고, 이후 코드 편집·리뷰는 Cursor/Cline으로 진행.
- **옵션 B**: 본 저장소(pub-wise-vibe)의 `review_source.sh` 가 생성하는 **review_addon** 구조를 참고해, Cursor/Cline 채팅으로 "docker-compose.prod.yml, nginx.conf, security_audit.sh, SECURITY.md 를 이 프로젝트에 맞게 작성해줘"처럼 요청해 수동으로 동일한 addon을 만듦.

---

## 환경 변수 (.env / .env.example)

- **위치**: 프로젝트 루트의 `.env` (또는 `ENV_FILE` 로 지정한 파일). `setup_vibe` 실행 시 **현재 디렉터리**의 `.env` 를 로드합니다.
- **템플릿**: `cp .env.example .env` 후 값을 채우거나, `setup_vibe` 에서 입력한 값이 자동으로 반영됩니다.
- **주요 변수 예**:
  - **Gemini**: `GEMINI_API_KEY`, `GEMINI_MODEL`
  - **Claude**: `ANTHROPIC_API_KEY`, `CLAUDE_MODEL`
  - **Ollama**: `OLLAMA_BASE_URL`, `OLLAMA_MODEL`
  - **Cursor**: `CURSOR_API_KEY`, `CURSOR_PRIMARY_MODEL`
  - **Cline**: `OPENAI_API_KEY`, `CLINE_PROVIDER`
- **보안**: `.env` 는 `.gitignore` 에 포함되어 커밋되지 않도록 합니다.

---

## 모델 선택 (2026년 2월 기준, 비용 vs 성능)

각 서비스별로 **비용 최적** 모델과 **성능 최적** 모델 중에서 선택할 수 있습니다. `.env` 또는 `setup_vibe` 실행 시 해당 변수에 원하는 모델을 지정하면 됩니다.

| 서비스 | 비용 최적 모델 | 성능 최적 모델 | 참고 (가격·특성) |
|--------|----------------|----------------|-------------------|
| **Gemini** | `gemini-2.5-flash` | `gemini-2.5-pro` / `gemini-3-pro-preview` | Flash: 가격·성능 균형. Pro: 고품질·긴 컨텍스트. [Google AI Pricing](https://ai.google.dev/gemini-api/docs/pricing) |
| **Claude** | `claude-haiku-4.5` | `claude-opus-4.5` | Haiku 4.5: $1 in / $5 out. Opus 4.5: $5 in / $25 out (per 1M tokens). [Anthropic Pricing](https://docs.anthropic.com/en/docs/about-claude/pricing) |
| **Ollama** | `deepseek-coder:6.7b-q4_K_M` | `qwen2.5-coder:32b` 또는 `deepseek-coder:33b-instruct-q4_K_M` | 로컬 무료. 소형은 적은 VRAM/RAM, 대형은 24GB+ VRAM 또는 32GB+ RAM 권장. |
| **Cursor** | `gemini-3-flash` / Sonnet | `claude-opus-4.6` / `gpt-4o` / `gemini-3-pro` | Pro 요금제($20/월) 내 사용량 소진. [Cursor Pricing](https://www.cursor.com/pricing) |
| **Cline** (OpenAI) | `gpt-4o-mini` | `gpt-4o` | mini: 약 $0.15/0.60, gpt-4o: $2.50/10 per 1M. [OpenAI Pricing](https://platform.openai.com/docs/pricing) |
| **Cline** (Anthropic) | `claude-haiku-4.5` | `claude-opus-4.5` | Claude API와 동일 요금. |

- **선택 방법**: `.env.example` 에는 서비스별로 비용 최적이 기본으로 들어 있습니다. 성능 최적을 쓰려면 해당 블록에서 주석을 바꾸거나, `GEMINI_MODEL` / `CLAUDE_MODEL` / `OLLAMA_MODEL` / `CURSOR_PRIMARY_MODEL` 등을 원하는 모델명으로 설정하면 됩니다.
- **모델 ID**: API별 최신 모델 ID는 각 제공처 문서를 확인하세요. 위 표는 2026년 2월 기준 요약입니다.

---

## review_source 출력 구조

```
<repo_name>/
├── REVIEW.md              # 저장소 URL, 1.개요(README), 2.구조 다이어그램+주요 경로 설명, 3.상세 분석(소스별 설명·AI), 4.개선 addon (단일 선택 시). Both 시 G/C 비교 요약 포함
├── REVIEW_gemini.md       # Both 선택 시
├── REVIEW_claude.md       # Both 선택 시
└── review_addon/
    ├── dist/
    │   └── docker-compose.prod.yml   # Fullstack( frontend/backend/db/redis/nginx ) 배포 권고
    ├── nginx.conf                    # HTTPS, HSTS, TLS 1.3, 보안 헤더
    ├── security_audit.sh             # OWASP 점검(시크릿/HTTPS/.env 권한)
    ├── ci-cd/
    │   └── github-actions.yml        # CI 파이프라인 예시
    ├── prometheus.yml                # 모니터링 스크래핑 설정
    ├── .env.example                  # 배포용 환경 변수 예시
    └── SECURITY.md                   # 보안 체크리스트
```

- **REVIEW.md 내용**: 저장소 URL → 1. 개요(README.md) → 2. 구조 다이어그램·주요 경로별 한 줄 설명 → 구성 요소(FE/BE/DB 파일 수) → 3. 상세 분석(구성요소별 파일·소스별 설명·함수/클래스 목록·BE API 후보·AI 분석) → 4. 개선 addon. AI CLI 미동작 시에도 로컬 상세 분석(소스별 설명·기능 목록)은 포함됩니다.
- **addon 활용**: `./review_addon/security_audit.sh` 실행, `docker-compose -f review_addon/dist/docker-compose.prod.yml up` 등으로 배포·보안 검토에 사용할 수 있습니다.

---

## 인프라·보안 참고 (Pre-PRD)

- **네트워크**: Ollama 기본 `localhost:11434`, API 키는 환경 변수로만 관리.
- **배포**: HTTPS 사용, docker-compose·nginx 권고. addon의 `nginx.conf`·`docker-compose.prod.yml` 참고.
- **보안**: install.sh `set -e`, `.env` 미커밋, addon의 `security_audit.sh` 로 시크릿·HTTPS 이슈 점검.

---

## 라이선스

MIT | [WisemanLim/pub-wise-vibe](https://github.com/WisemanLim/pub-wise-vibe)
