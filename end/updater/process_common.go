package updater

import (
	"fmt"
	"net/http"
	"time"
)

func waitForHealth(url string, timeout time.Duration) error {
	client := &http.Client{Timeout: 5 * time.Second}
	deadline := time.Now().Add(timeout)
	for time.Now().Before(deadline) {
		resp, err := client.Get(url)
		if err == nil {
			resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 300 {
				return nil
			}
		}
		time.Sleep(time.Second)
	}
	return fmt.Errorf("健康检查超时: %s", url)
}
