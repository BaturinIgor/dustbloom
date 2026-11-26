package game

import (
	"errors"
	"testing"
	"time"
)

func TestManorUpgradeFlow(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	if f.ManorLevel() != 1 || len(cfg.Manor.Levels) != 29 {
		t.Fatalf("manor %d, levels %d", f.ManorLevel(), len(cfg.Manor.Levels))
	}
	next, _ := f.NextManor(cfg)
	if err := f.UpgradeManor(cfg, now); err != nil {
		t.Fatal(err)
	}
	if f.Coins != cfg.Farm.StartCoins-next.Coins || f.ManorReadyAt == nil {
		t.Fatalf("coins %d readyAt %v", f.Coins, f.ManorReadyAt)
	}
	if err := f.UpgradeManor(cfg, now); !errors.Is(err, ErrBusy) {
		t.Fatalf("second upgrade err = %v", err)
	}
	f.Settle(cfg, now.Add(time.Duration(next.Seconds)*time.Second))
	if f.ManorLevel() != 2 || f.ManorReadyAt != nil {
		t.Fatalf("after build: level %d", f.ManorLevel())
	}
	// level 3 needs player level 2
	if err := f.UpgradeManor(cfg, now.Add(time.Hour)); !errors.Is(err, ErrLocked) {
		t.Fatalf("player level gate err = %v", err)
	}
}

func TestManorSpeedupAndSlots(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	f.Items = map[string]int{"speed_build_1m": 1, "speed_recruit_1h": 1}
	if err := f.UpgradeManor(cfg, now); err != nil {
		t.Fatal(err)
	}
	tgt := SpeedTarget{Kind: TargetBuild}
	if _, err := f.UseSpeedups(cfg, tgt, map[string]int{"speed_recruit_1h": 1}, now); !errors.Is(err, ErrWrongTarget) {
		t.Fatalf("recruit on build err = %v", err)
	}
	if _, err := f.UseSpeedups(cfg, tgt, map[string]int{"speed_build_1m": 1}, now); err != nil {
		t.Fatal(err)
	}
	if f.ManorLevel() != 2 {
		t.Fatalf("speedup did not finish the upgrade: %d", f.ManorLevel())
	}
	base := f.ArmySlots(cfg)
	f.Manor = 3
	if f.ArmySlots(cfg) != base+1 {
		t.Fatalf("manor 3 slots %d, want %d", f.ArmySlots(cfg), base+1)
	}
	f.Manor = cfg.Manor.MaxLevel
	if err := f.UpgradeManor(cfg, now); !errors.Is(err, ErrMaxLevel) {
		t.Fatalf("max level err = %v", err)
	}
}

func TestOldSaveManorIsOne(t *testing.T) {
	f := &Farm{}
	if f.ManorLevel() != 1 {
		t.Fatal("old save manor should be 1")
	}
}
