// Command dustbloom-server runs the DUSTBLOOM game API.
//
//	go run ./cmd/dustbloom-server -addr :8080 -data ./dev-state.json
package main

import (
	"flag"
	"log"
	"net/http"
	"time"

	"github.com/BaturinIgor/dustbloom/server/internal/api"
	"github.com/BaturinIgor/dustbloom/server/internal/game"
	"github.com/BaturinIgor/dustbloom/server/internal/store"
	"github.com/BaturinIgor/dustbloom/server/internal/telemetry"
)

func main() {
	addr := flag.String("addr", ":8080", "listen address")
	data := flag.String("data", "", "optional JSON file to keep state between restarts")
	tel := flag.String("telemetry", "", "optional directory for analytics and feedback (JSON lines per day)")
	flag.Parse()

	cfg, err := game.DefaultConfig()
	if err != nil {
		log.Fatal(err)
	}
	st, err := store.NewMemory(*data)
	if err != nil {
		log.Fatal(err)
	}
	srv := &api.Server{Config: cfg, Store: st, Now: time.Now}
	if *tel != "" {
		sink, err := telemetry.NewFile(*tel)
		if err != nil {
			log.Fatal(err)
		}
		srv.Telemetry = sink
	}
	hs := &http.Server{
		Addr:              *addr,
		Handler:           srv.Handler(),
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("dustbloom-server listening on %s", *addr)
	log.Fatal(hs.ListenAndServe())
}
