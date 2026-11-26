// Package telemetry keeps first-party analytics: game events sent by the
// client, every API action as the server saw it, and player feedback.
// Records are JSON lines in daily files (events-2026-11-26.jsonl,
// feedback-2026-11-26.jsonl) until hosting brings a database. No third-party
// SDKs, no advertising ids: events are linked only to the game account.
package telemetry

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"regexp"
	"sync"
	"time"
)

// Event is one thing that happened, from the client or the server.
type Event struct {
	At      time.Time      `json:"at"`
	Player  string         `json:"player,omitempty"`
	Source  string         `json:"source"` // "client" or "server"
	Name    string         `json:"name"`
	Session string         `json:"session,omitempty"`
	App     string         `json:"app,omitempty"`  // app version
	Lang    string         `json:"lang,omitempty"` // device language
	Props   map[string]any `json:"props,omitempty"`
}

// Feedback is a message from a player.
type Feedback struct {
	At     time.Time `json:"at"`
	Player string    `json:"player"`
	Mood   int       `json:"mood,omitempty"` // 1..5, 0 = not given
	Text   string    `json:"text"`
	App    string    `json:"app,omitempty"`
	Lang   string    `json:"lang,omitempty"`
	Level  int       `json:"level,omitempty"`
}

// Sink stores records. A nil *File drops everything (tests, local play).
type Sink interface {
	Events(evs []Event) error
	Feedback(fb Feedback) error
}

// File writes JSON lines into dir.
type File struct {
	mu  sync.Mutex
	dir string
}

// NewFile creates the directory if needed.
func NewFile(dir string) (*File, error) {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return nil, err
	}
	return &File{dir: dir}, nil
}

func (f *File) write(kind string, day time.Time, recs []any) error {
	if f == nil || len(recs) == 0 {
		return nil
	}
	f.mu.Lock()
	defer f.mu.Unlock()
	name := filepath.Join(f.dir, fmt.Sprintf("%s-%s.jsonl", kind, day.UTC().Format("2006-01-02")))
	out, err := os.OpenFile(name, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o600)
	if err != nil {
		return err
	}
	enc := json.NewEncoder(out)
	for _, r := range recs {
		if err := enc.Encode(r); err != nil {
			_ = out.Close()
			return err
		}
	}
	return out.Close()
}

// Events implements Sink.
func (f *File) Events(evs []Event) error {
	if len(evs) == 0 {
		return nil
	}
	recs := make([]any, len(evs))
	for i := range evs {
		recs[i] = evs[i]
	}
	return f.write("events", evs[0].At, recs)
}

// Feedback implements Sink.
func (f *File) Feedback(fb Feedback) error {
	return f.write("feedback", fb.At, []any{fb})
}

// Limits on what a client may send.
const (
	MaxBatch       = 100
	MaxProps       = 16
	MaxValueLen    = 120
	MaxFeedbackLen = 2000
)

var nameRe = regexp.MustCompile(`^[a-z][a-z0-9_]{0,39}$`)

// ValidName reports whether s is a good event or prop name.
func ValidName(s string) bool { return nameRe.MatchString(s) }

// CleanProps keeps valid keys with short strings, numbers and booleans.
func CleanProps(in map[string]any) map[string]any {
	if len(in) == 0 {
		return nil
	}
	out := map[string]any{}
	for k, v := range in {
		if len(out) >= MaxProps || !ValidName(k) {
			continue
		}
		switch t := v.(type) {
		case string:
			if len(t) > MaxValueLen {
				t = t[:MaxValueLen]
			}
			out[k] = t
		case float64, bool:
			out[k] = t
		}
	}
	if len(out) == 0 {
		return nil
	}
	return out
}
