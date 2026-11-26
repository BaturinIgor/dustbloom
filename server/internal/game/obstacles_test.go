package game

import (
	"errors"
	"testing"
)

func findObstacle(t *testing.T, f *Farm, cfg *Config, owned bool) (int, int) {
	t.Helper()
	for y := 0; y < f.Height; y++ {
		for x := 0; x < f.Width; x++ {
			if f.ObstacleAt(cfg, x, y) != "" && f.Owns(cfg, x, y) == owned {
				return x, y
			}
		}
	}
	t.Fatalf("no obstacle (owned=%v) on the farm", owned)
	return 0, 0
}

// Obstacles only stand on land bought later (the start plots are kept clear).
func ownAll(f *Farm) {
	for i := range f.Plots {
		f.Plots[i] = true
	}
}

func TestObstaclesBlockTillingUntilCleared(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	ownAll(f)
	f.Coins = 1000
	x, y := findObstacle(t, f, cfg, true)
	if err := f.Till(cfg, x, y); !errors.Is(err, ErrObstacle) {
		t.Fatalf("till on obstacle err = %v", err)
	}
	kind := f.ObstacleAt(cfg, x, y)
	xp := f.XP
	res, err := f.Clear(cfg, x, y)
	if err != nil {
		t.Fatal(err)
	}
	if res.Kind != kind || f.Coins != 1000-cfg.Obstacles[kind].Coins || f.XP != xp+cfg.Obstacles[kind].XP {
		t.Fatalf("clear result %+v coins %d xp %d", res, f.Coins, f.XP)
	}
	if f.ObstacleAt(cfg, x, y) != "" {
		t.Fatal("obstacle still there")
	}
	if _, err := f.Clear(cfg, x, y); !errors.Is(err, ErrNoObstacle) {
		t.Fatalf("second clear err = %v", err)
	}
	if err := f.Till(cfg, x, y); err != nil {
		t.Fatalf("till after clear: %v", err)
	}
}

func TestClearNeedsOwnedLandAndCoins(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	x, y := findObstacle(t, f, cfg, false)
	if _, err := f.Clear(cfg, x, y); !errors.Is(err, ErrNotOwned) {
		t.Fatalf("clear on unowned land err = %v", err)
	}
	ownAll(f)
	x, y = findObstacle(t, f, cfg, true)
	f.Coins = 0
	if _, err := f.Clear(cfg, x, y); !errors.Is(err, ErrNotEnough) {
		t.Fatalf("clear without coins err = %v", err)
	}
}

func TestNoObstaclesNearTheStartBeds(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	s := cfg.Farm.StartTilled
	for y := s.Y - 4; y < s.Y+s.Height+4; y++ {
		for x := s.X - 4; x < s.X+s.Width+4; x++ {
			if f.ObstacleAt(cfg, x, y) != "" {
				t.Fatalf("obstacle at %d,%d next to the start beds", x, y)
			}
		}
	}
}
