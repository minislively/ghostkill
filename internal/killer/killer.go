package killer

import (
	"fmt"
	"os/exec"

	"github.com/minislively/ghostkill/internal/detector"
)

func Fix(issues []detector.Issue) int {
	killed := 0
	for _, issue := range issues {
		// duplicate 태그는 자동 kill 하지 않음 (위험할 수 있음)
		if issue.Tag == "duplicate" {
			fmt.Printf("  skip: %s (수동으로 확인 필요)\n", issue.Description)
			continue
		}
		for _, pid := range issue.PIDs {
			err := exec.Command("kill", "-9", fmt.Sprintf("%d", pid)).Run()
			if err == nil {
				killed++
			}
		}
	}
	return killed
}
