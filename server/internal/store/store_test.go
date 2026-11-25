package store

import (
	"errors"
	"path/filepath"
	"testing"

	"github.com/BaturinIgor/dustbloom/server/internal/game"
)

func TestSnapshotSurvivesRestart(t *testing.T) {
	cfg, err := game.DefaultConfig()
	if err != nil {
		t.Fatal(err)
	}
	path := filepath.Join(t.TempDir(), "state.json")
	m, err := NewMemory(path)
	if err != nil {
		t.Fatal(err)
	}
	p, err := m.GuestLogin("device-1234", func() *game.Farm { return game.NewFarm(cfg) })
	if err != nil {
		t.Fatal(err)
	}
	if err := m.WithFarm(p.Token, func(f *game.Farm) error { f.Coins = 777; return nil }); err != nil {
		t.Fatal(err)
	}

	m2, err := NewMemory(path)
	if err != nil {
		t.Fatal(err)
	}
	var coins int
	if err := m2.WithFarm(p.Token, func(f *game.Farm) error { coins = f.Coins; return nil }); err != nil {
		t.Fatal(err)
	}
	if coins != 777 {
		t.Fatalf("coins after restart = %d, want 777", coins)
	}
}

func TestUnknownToken(t *testing.T) {
	m, _ := NewMemory("")
	err := m.WithFarm("missing", func(*game.Farm) error { return nil })
	if !errors.Is(err, ErrNoPlayer) {
		t.Fatalf("err = %v, want ErrNoPlayer", err)
	}
}
