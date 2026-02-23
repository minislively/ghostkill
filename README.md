# ghostkill

macOS 프로세스 환경 진단 및 정리 CLI 도구.

IDE(Kiro, Cursor, VS Code 등)가 백그라운드에 남긴 좀비 터미널 세션과 중복 프로세스를 한 줄로 탐지하고 정리합니다.

## 설치

```bash
brew install minislively/tap/ghostkill
```

또는 직접 빌드:

```bash
git clone https://github.com/minislively/ghostkill
cd ghostkill
go build -o ghostkill ./cmd/ghostkill
```

## 사용법

```bash
# 현재 환경 진단
ghostkill

# 문제 프로세스 자동 정리
ghostkill --fix
```

### 출력 예시

```
⚠ Kiro CLI 좀비 터미널 세션 15개 발견
⚠ claude 인스턴스 21개 실행 중 (기준: 5개)

→ 정리하려면: ghostkill --fix
```

## 감지 항목

| 항목 | 설명 |
|------|------|
| 좀비 터미널 세션 | IDE가 종료 후 남긴 zsh 세션 |
| 중복 프로세스 | 기준치 이상으로 실행 중인 dev 툴 |

## 지원 IDE / 툴

- Kiro CLI
- Cursor
- VS Code
- Windsurf

## Contributing

PR 환영합니다.

## License

MIT
