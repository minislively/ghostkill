package main

import (
	"fmt"
	"os"

	"github.com/minislively/ghostkill/internal/detector"
	"github.com/minislively/ghostkill/internal/killer"
)

const version = "0.1.0"

func main() {
	args := os.Args[1:]

	if len(args) > 0 {
		switch args[0] {
		case "--version", "-v":
			fmt.Printf("ghostkill v%s\n", version)
			return
		case "--help", "-h":
			printHelp()
			return
		}
	}

	fix := false
	for _, a := range args {
		if a == "--fix" || a == "-f" {
			fix = true
		}
	}

	issues := detector.Scan()

	if len(issues) == 0 {
		fmt.Println("✓ 환경이 깨끗합니다.")
		return
	}

	for _, issue := range issues {
		fmt.Printf("⚠ %s\n", issue.Description)
	}

	if fix {
		fmt.Println()
		killed := killer.Fix(issues)
		fmt.Printf("→ %d개 프로세스 정리 완료\n", killed)
	} else {
		fmt.Println("\n→ 정리하려면: ghostkill --fix")
	}
}

func printHelp() {
	fmt.Print(`ghostkill - macOS 프로세스 환경 진단 및 정리

사용법:
  ghostkill           현재 환경 진단
  ghostkill --fix     문제 프로세스 자동 정리
  ghostkill --version 버전 출력

GitHub: https://github.com/minislively/ghostkill
`)
}
