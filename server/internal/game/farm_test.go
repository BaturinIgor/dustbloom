package game

import (
	"errors"
	"testing"
	"time"
)

func mustConfig(t *testing.T) *Config {
	t.Helper()
	cfg, err := DefaultConfig()
	if err != nil {
		t.Fatalf("DefaultConfig: %v", err)
	}
	return cfg
}

func TestNewFarmStartsWithTilledPatch(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	if f.Width != 16 || f.Height != 16 {
		t.Fatalf("size = %dx%d, want 16x16", f.Width, f.Height)
	}
	tilled := 0
	for _, tl := range f.Tiles {
		if tl.Tilled {
			tilled++
		}
	}
	r := cfg.Farm.StartTilled
	if tilled != r.Width*r.Height {
		t.Fatalf("tilled = %d, want %d", tilled, r.Width*r.Height)
	}
	if f.Coins != cfg.Farm.StartCoins {
		t.Fatalf("coins = %d, want %d", f.Coins, cfg.Farm.StartCoins)
	}
}

func TestPlantGrowHarvest(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	wheat, _ := cfg.Crop("dustwheat")

	if err := f.Plant(cfg, 6, 6, "dustwheat", now); err != nil {
		t.Fatalf("Plant: %v", err)
	}
	if f.Coins != cfg.Farm.StartCoins-wheat.SeedCost {
		t.Fatalf("coins after plant = %d", f.Coins)
	}
	if err := f.Plant(cfg, 6, 6, "dustwheat", now); !errors.Is(err, ErrOccupied) {
		t.Fatalf("second plant err = %v, want ErrOccupied", err)
	}
	if _, err := f.Harvest(cfg, 6, 6, now.Add(10*time.Second)); !errors.Is(err, ErrNotReady) {
		t.Fatalf("early harvest err = %v, want ErrNotReady", err)
	}
	res, err := f.Harvest(cfg, 6, 6, now.Add(time.Duration(wheat.GrowSeconds)*time.Second))
	if err != nil {
		t.Fatalf("Harvest: %v", err)
	}
	if res.Count != 1 || res.XP != wheat.XP || f.Barn["dustwheat"] != 1 {
		t.Fatalf("harvest result = %+v, barn = %v", res, f.Barn)
	}
	got, err := f.Sell(cfg, "dustwheat", 1)
	if err != nil || got != wheat.SellPrice {
		t.Fatalf("Sell = %d, %v", got, err)
	}
	if f.Coins != cfg.Farm.StartCoins-wheat.SeedCost+wheat.SellPrice || len(f.Barn) != 0 {
		t.Fatalf("coins after sell = %d, barn = %v", f.Coins, f.Barn)
	}
	if _, err := f.Sell(cfg, "dustwheat", 1); !errors.Is(err, ErrNoCrops) {
		t.Fatalf("sell from empty barn err = %v", err)
	}
	if f.Tiles[6*f.Width+6].Crop != "" {
		t.Fatal("tile not cleared after harvest")
	}
}

func TestPlantRules(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Now()
	cases := []struct {
		name string
		x, y int
		crop string
		want error
	}{
		{"grass", 0, 0, "dustwheat", ErrNotTilled},
		{"outside", -1, 3, "dustwheat", ErrOutOfBounds},
		{"far outside", 16, 0, "dustwheat", ErrOutOfBounds},
		{"unknown crop", 6, 6, "banana", ErrUnknownCrop},
	}
	for _, c := range cases {
		if err := f.Plant(cfg, c.x, c.y, c.crop, now); !errors.Is(err, c.want) {
			t.Errorf("%s: err = %v, want %v", c.name, err, c.want)
		}
	}
	f.Coins = 0
	if err := f.Plant(cfg, 6, 6, "dustwheat", now); !errors.Is(err, ErrNotEnough) {
		t.Errorf("broke: err = %v, want ErrNotEnough", err)
	}
}

func TestTill(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	if err := f.Till(cfg, 4, 0); err != nil {
		t.Fatalf("Till: %v", err)
	}
	if err := f.Till(cfg, 4, 0); !errors.Is(err, ErrAlreadyTilled) {
		t.Fatalf("re-till err = %v", err)
	}
	if f.Coins != cfg.Farm.StartCoins-cfg.Farm.TillCost {
		t.Fatalf("coins = %d", f.Coins)
	}
	f.Coins = 0
	if err := f.Till(cfg, 5, 0); !errors.Is(err, ErrNotEnough) {
		t.Fatalf("broke till err = %v", err)
	}
}

func TestLevelCurve(t *testing.T) {
	cases := map[int]int{0: 1, 9: 1, 10: 2, 29: 2, 30: 3, 60: 4}
	for xp, want := range cases {
		f := &Farm{XP: xp}
		if got := f.Level(); got != want {
			t.Errorf("XP %d: level %d, want %d", xp, got, want)
		}
	}
}

func TestProgressClamps(t *testing.T) {
	c := Crop{GrowSeconds: 100}
	t0 := time.Unix(1000, 0)
	if p := Progress(c, t0, t0.Add(-time.Second)); p != 0 {
		t.Errorf("before plant: %v", p)
	}
	if p := Progress(c, t0, t0.Add(50*time.Second)); p != 0.5 {
		t.Errorf("half: %v", p)
	}
	if p := Progress(c, t0, t0.Add(time.Hour)); p != 1 {
		t.Errorf("overgrown: %v", p)
	}
}

func TestParseConfigRejectsBadInput(t *testing.T) {
	bad := []string{
		`{`,
		`{"farm":{"width":0,"height":16}}`,
		`{"farm":{"width":4,"height":4},"crops":[{"id":"a","growSeconds":0}]}`,
		`{"farm":{"width":4,"height":4},"crops":[{"id":"a","growSeconds":1},{"id":"a","growSeconds":1}]}`,
	}
	for _, b := range bad {
		if _, err := ParseConfig([]byte(b)); err == nil {
			t.Errorf("ParseConfig(%s) succeeded, want error", b)
		}
	}
}

func TestLandPlots(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	if !f.Owns(cfg, 6, 6) || f.Owns(cfg, 0, 0) {
		t.Fatal("start plots wrong")
	}
	if err := f.Till(cfg, 0, 6); !errors.Is(err, ErrNotOwned) {
		t.Fatalf("till outside land err = %v", err)
	}
	coins, level := f.PlotPrice(cfg)
	if coins != cfg.Farm.PlotBaseCost || level != 1 {
		t.Fatalf("first plot price = %d coins, level %d", coins, level)
	}
	if err := f.BuyPlot(cfg, 3, 3); !errors.Is(err, ErrNotAdjacent) {
		t.Fatalf("far plot err = %v", err)
	}
	if err := f.BuyPlot(cfg, 1, 1); !errors.Is(err, ErrOwned) {
		t.Fatalf("owned plot err = %v", err)
	}
	if err := f.BuyPlot(cfg, 0, 1); err != nil {
		t.Fatalf("BuyPlot: %v", err)
	}
	if f.Coins != cfg.Farm.StartCoins-coins || !f.Owns(cfg, 0, 6) {
		t.Fatalf("after buy coins %d", f.Coins)
	}
	if err := f.Till(cfg, 0, 6); err != nil {
		t.Fatalf("till bought land: %v", err)
	}
	next, nextLevel := f.PlotPrice(cfg)
	if next <= coins || nextLevel < 2 {
		t.Fatalf("second plot should cost more and need a level: %d, %d", next, nextLevel)
	}
	f.Coins = 10000
	if err := f.BuyPlot(cfg, 0, 0); !errors.Is(err, ErrLocked) {
		t.Fatalf("level gate err = %v", err)
	}
}

func TestOldFarmGetsStartPlots(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Plots = nil
	if err := f.Till(cfg, 4, 4); err != nil && !errors.Is(err, ErrAlreadyTilled) {
		t.Fatalf("old farm till in start land: %v", err)
	}
}
