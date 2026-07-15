# 💚 Claude Menubar Monitor

macOS 메뉴바에서 Claude 사용량을 한눈에 확인하세요.

노치 옆에 짧게, 클릭하면 자세히.

## 미리보기

```
💚 7%              ← 메뉴바 (세션 사용률)
┌─────────────────────────────┐
│ 🧡 Claude (Pro)              │
│                              │
│ Session: 🟩⬜⬜⬜⬜⬜⬜⬜⬜⬜  7% (~4h) │
│ Weekly:  🟩⬜⬜⬜⬜⬜⬜⬜⬜⬜  5% (~5d) │
│                              │
│ Last checked: 2026-07-15     │
│──────────────────────────────│
│ Refresh                      │
│ Open Claude                  │
└─────────────────────────────┘
```

## 아이콘

| 아이콘 | 의미 | 세션 사용률 |
|--------|------|------------|
| 💚 | 여유 | 60% 미만 |
| 🧡 | 슬슬 아끼기 | 60-89% |
| ❤️‍🔥 | 위험 | 90% 이상 |

## 설치 (한 줄)

```bash
curl -sL https://raw.githubusercontent.com/Plum-igaw/claude-token-menubar/main/install.sh | bash
```

## 필요한 것

- macOS (Apple Silicon / Intel)
- Python 3 (macOS 기본 설치됨)
- [Claude Code](https://docs.claude.com/en/docs/claude-code) 로그인 (토큰 인증에 필요)

## Claude Code 로그인

Claude Code CLI가 없으면:

```bash
npx @anthropic-ai/claude-code
```

브라우저에서 Claude 계정으로 로그인하면 끝. 실제로 CLI를 사용할 필요는 없고, 로그인만 하면 됩니다.

## 동작 원리

1. macOS 키체인에서 Claude Code OAuth 토큰을 읽음 (읽기 전용)
2. `https://api.anthropic.com/api/oauth/usage` 엔드포인트 조회
3. 5시간 세션 / 7일 주간 사용률을 메뉴바에 표시
4. 토큰 만료 시 refresh token으로 자동 갱신

**저장하는 것:** 사용률 퍼센트와 리셋 시각만 로컬 캐시 (`~/.claude-usage-cache.json`)

**저장하지 않는 것:** 비밀번호, API Key, 계정 인증정보

## 갱신 주기

- 5분마다 자동 갱신
- 수동: 메뉴바 클릭 → Refresh

## 수동 설치

SwiftBar가 이미 있으면:

```bash
# 플러그인 폴더에 복사
cp claude-usage.5m.sh claude-usage-helper.py ~/swiftbar-plugins/
chmod +x ~/swiftbar-plugins/claude-usage.5m.sh ~/swiftbar-plugins/claude-usage-helper.py
```

## 삭제

```bash
rm ~/swiftbar-plugins/claude-usage.5m.sh ~/swiftbar-plugins/claude-usage-helper.py
rm ~/.claude-usage-cache.json
```

## 라이선스

MIT
