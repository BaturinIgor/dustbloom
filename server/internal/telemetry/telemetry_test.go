package telemetry

import (
	"bufio"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"
)

func TestFileWritesDailyJSONLines(t *testing.T) {
	dir := t.TempDir()
	f, err := NewFile(dir)
	if err != nil {
		t.Fatal(err)
	}
	at := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	if err := f.Events([]Event{{At: at, Name: "harvest", Source: "client"}, {At: at, Name: "sell", Source: "client"}}); err != nil {
		t.Fatal(err)
	}
	if err := f.Feedback(Feedback{At: at, Player: "p1", Text: "nice", Mood: 5}); err != nil {
		t.Fatal(err)
	}
	file, err := os.Open(filepath.Join(dir, "events-2026-11-26.jsonl"))
	if err != nil {
		t.Fatal(err)
	}
	defer file.Close()
	n := 0
	for s := bufio.NewScanner(file); s.Scan(); n++ {
		if !strings.Contains(s.Text(), `"source":"client"`) {
			t.Fatalf("line %q", s.Text())
		}
	}
	if n != 2 {
		t.Fatalf("%d lines", n)
	}
	if _, err := os.Stat(filepath.Join(dir, "feedback-2026-11-26.jsonl")); err != nil {
		t.Fatal(err)
	}
	var nilFile *File
	if err := nilFile.Events([]Event{{At: at, Name: "x"}}); err != nil {
		t.Fatal("nil sink must drop events")
	}
}

func TestCleanProps(t *testing.T) {
	p := CleanProps(map[string]any{"crop": "dustwheat", "n": 3.0, "ok": true, "Bad Key": 1.0, "obj": map[string]any{}, "long": strings.Repeat("a", 500)})
	if len(p) != 4 || len(p["long"].(string)) != MaxValueLen {
		t.Fatalf("props %v", p)
	}
	if ValidName("Harvest") || !ValidName("raid_win") {
		t.Fatal("names")
	}
}
