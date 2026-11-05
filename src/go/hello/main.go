// Test program for Go on Maemo 5: goroutines, runtime info and an HTTPS request (TLS built into Go).
package main

import (
	"fmt"
	"net/http"
	"os"
	"runtime"
	"sync"
	"time"
)

func main() {
	var wg sync.WaitGroup
	for i := 0; i < 4; i++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			time.Sleep(time.Duration(n) * 10 * time.Millisecond)
			fmt.Println("goroutine", n)
		}(i)
	}
	wg.Wait()
	fmt.Println(runtime.GOOS, runtime.GOARCH, runtime.Version(), "cpus:", runtime.NumCPU())

	url := "https://github.com"
	if len(os.Args) > 1 {
		url = os.Args[1]
	}
	client := &http.Client{Timeout: 20 * time.Second}
	resp, err := client.Get(url)
	if err != nil {
		fmt.Println("https error:", err)
		os.Exit(1)
	}
	defer resp.Body.Close()
	fmt.Println(url, resp.Status, "TLS", resp.TLS.Version)
}
