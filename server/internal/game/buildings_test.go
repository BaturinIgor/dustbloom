package game

import (
	"errors"
	"testing"
	"time"
)

func TestBuildingCappedByManorAndSharesBuilder(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Coins = 1_000_000
	f.Barn = map[string]int{"dustwheat": 500, "emberpumpkin": 500}
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)

	// the well needs Усадьба 2
	if err := f.UpgradeBuilding(cfg, "well", now); !errors.Is(err, ErrManorTooLow) {
		t.Fatalf("well at manor 1: %v", err)
	}
	// the mill stands from the start at level 1; level 2 needs Усадьба 2
	if f.BuildingLevel(cfg, "mill") != 1 {
		t.Fatalf("mill starts at %d", f.BuildingLevel(cfg, "mill"))
	}
	if err := f.UpgradeBuilding(cfg, "mill", now); !errors.Is(err, ErrManorTooLow) {
		t.Fatalf("mill 2 at manor 1: %v", err)
	}
	if err := f.UpgradeManor(cfg, now); err != nil {
		t.Fatal(err)
	}
	// one builder: nothing else while the manor is under construction
	if err := f.UpgradeBuilding(cfg, "mill", now); !errors.Is(err, ErrBusy) {
		t.Fatalf("mill while manor builds: %v", err)
	}
	now = now.Add(time.Hour)
	if err := f.UpgradeBuilding(cfg, "well", now); err != nil {
		t.Fatalf("well at manor 2: %v", err)
	}
	if err := f.UpgradeManor(cfg, now); !errors.Is(err, ErrBusy) {
		t.Fatalf("manor while well builds: %v", err)
	}
	// a build speedup finishes the well
	f.Items = map[string]int{"speed_build_5m": 1}
	if _, err := f.UseSpeedups(cfg, SpeedTarget{Kind: TargetBuild}, map[string]int{"speed_build_5m": 1}, now); err != nil {
		t.Fatal(err)
	}
	if f.BuildingLevel(cfg, "well") != 1 || f.Work != nil {
		t.Fatalf("well level %d work %v", f.BuildingLevel(cfg, "well"), f.Work)
	}
	// level 2 would pass the manor (2)? no: 2 <= 2 is fine, 3 is not
	f.Buildings["well"] = 2
	if err := f.UpgradeBuilding(cfg, "well", now); !errors.Is(err, ErrManorTooLow) {
		t.Fatalf("well 3 at manor 2: %v", err)
	}
	if err := f.UpgradeBuilding(cfg, "nope", now); !errors.Is(err, ErrUnknownBuilding) {
		t.Fatalf("unknown building: %v", err)
	}
}

func TestBuildingBonuses(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Manor = 30
	f.Buildings = map[string]int{"well": 10, "mill": 10, "workshop": 30}
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)

	// well 10 = 15% faster for new plantings
	pumpkin, _ := cfg.Crop("emberpumpkin")
	if err := f.Plant(cfg, 6, 6, "emberpumpkin", now); err != nil {
		t.Fatal(err)
	}
	tl, _ := f.tile(6, 6)
	if want := int(float64(pumpkin.GrowSeconds)*0.85 + 0.5); tl.Grow != want {
		t.Fatalf("grow %d, want %d", tl.Grow, want)
	}
	if _, err := f.Harvest(cfg, 6, 6, now.Add(time.Duration(tl.Grow)*time.Second)); err != nil {
		t.Fatalf("harvest at the shorter time: %v", err)
	}
	// mill 10 = +20% coins
	f.Barn = map[string]int{"emberpumpkin": 10}
	coins, err := f.Sell(cfg, "emberpumpkin", 10)
	if err != nil || coins != pumpkin.SellPrice*10*120/100 {
		t.Fatalf("sell %d %v", coins, err)
	}
	// workshop 30 = 60% but capped at 50%
	if got := f.Bonus(cfg, EffectBuildTime); got != 50 {
		t.Fatalf("workshop bonus %v", got)
	}
	if f.Power(cfg) <= cfg.Manor.StartPower {
		t.Fatal("no power from buildings")
	}
}
