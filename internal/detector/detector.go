package detector

import (
	"fmt"
	"os/exec"
	"strings"
)

type Issue struct {
	Description string
	PIDs        []int
	Tag         string
}

// 알려진 IDE/툴이 남기는 좀비 터미널 패턴
var zombiePatterns = []struct {
	pattern string
	label   string
}{
	{"kiro-cli-term", "Kiro CLI"},
	{"cursor-cli-term", "Cursor"},
	{"vscode-cli-term", "VS Code"},
	{"windsurf-cli-term", "Windsurf"},
}

// 중복 실행 감지 대상
var duplicateTargets = []struct {
	name      string
	threshold int
}{
	{"claude", 5},
	{"node", 10},
	{"bun", 5},
}

func Scan() []Issue {
	var issues []Issue

	// 1. 좀비 터미널 세션 감지
	for _, z := range zombiePatterns {
		pids := findPIDs(z.pattern)
		if len(pids) > 0 {
			issues = append(issues, Issue{
				Description: fmt.Sprintf("%s 좀비 터미널 세션 %d개 발견", z.label, len(pids)),
				PIDs:        pids,
				Tag:         "zombie",
			})
		}
	}

	// 2. 중복 프로세스 감지
	for _, d := range duplicateTargets {
		pids := findPIDs(d.name)
		if len(pids) >= d.threshold {
			issues = append(issues, Issue{
				Description: fmt.Sprintf("%s 인스턴스 %d개 실행 중 (기준: %d개)", d.name, len(pids), d.threshold),
				PIDs:        pids,
				Tag:         "duplicate",
			})
		}
	}

	return issues
}

func findPIDs(pattern string) []int {
	out, err := exec.Command("pgrep", "-f", pattern).Output()
	if err != nil {
		return nil
	}

	var pids []int
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		var pid int
		fmt.Sscanf(line, "%d", &pid)
		if pid > 0 {
			pids = append(pids, pid)
		}
	}
	return pids
}
