package main 

import (
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
)

const (
	segmentDir = "/data/segments"
	pollInterval = 10 * time.Millisecond
	maxWait = 3 * time.Second
)

func main() {

	http.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request){
		w.WriteHeader(200)
		w.Write([]byte("ok"))
	})

	http.HandleFunc("/", handleSegmentRequest)

	log.Println("Origin server running on : 8080")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		log.Fatal(err)
	}
}

func handleSegmentRequest(w http.ResponseWriter, r *http.Request) {
	path := filepath.Join(segmentDir, filepath.Clean(r.URL.Path))

	if !(strings.HasSuffix(path, ".m4s") || strings.HasSuffix(path, ".mp4") || strings.HasSuffix(path, ".mpd")){

		if r.URL.Path == "/" {
			w.WriteHeader(200)
			w.Write([]byte("origin alive"))
			return
		}

		http.NotFound(w, r)
		return
	}

	deadline := time.Now().Add(maxWait)

	for {
		if fileExists(path) {
			streamFile(w, r, path)
			return
		}

		if time.Now().After(deadline) {
			http.NotFound(w, r)
			return
		}

		time.Sleep(pollInterval)
	}
}

func fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func streamFile(w http.ResponseWriter, r *http.Request, path string) {
	f, err := os.Open(path)

	if err != nil {
		http.Error(w, "failed to open segment", 500)
		return 
	}

	defer f.Close()

	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "*")

	w.Header().Set("Cache-Control", "no-store, must-revalidate")

	w.WriteHeader(http.StatusOK)
	io.Copy(w, f)
}