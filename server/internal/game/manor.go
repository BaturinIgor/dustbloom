package game

import (
	"errors"
	"fmt"
	"time"
)

// Errors returned by manor actions.
var (
	ErrBusy     = errors.New("busy")
	ErrMaxLevel = errors.New("max_level")
)

// TargetBuild speeds up construction (the manor upgrade).
const TargetBuild = "build"

// ManorConfig is the main building: 30 levels. Levels[i] is the cost of
// going from level i+1 to i+2. Every ArmySlotEvery levels adds an army slot;
// later buildings will be capped at the manor's level.
type ManorConfig struct {
	MaxLevel      int          `json:"maxLevel"`
	ArmySlotEvery int          `json:"armySlotEvery"`
	Levels        []ManorLevel `json:"levels"`
}

// ManorLevel is one upgrade step.
type ManorLevel struct {
	Coins       int            `json:"coins"`
	Crops       map[string]int `json:"crops"`
	Seconds     int            `json:"seconds"`
	PlayerLevel int            `json:"playerLevel"`
}

func (c *Config) validateManor() error {
	m := c.Manor
	if m.MaxLevel == 0 {
		return nil // configs without a manor (tests)
	}
	if len(m.Levels) != m.MaxLevel-1 {
		return fmt.Errorf("config: manor needs %d levels, has %d", m.MaxLevel-1, len(m.Levels))
	}
	for i, l := range m.Levels {
		if l.Seconds <= 0 || l.Coins < 0 {
			return fmt.Errorf("config: manor level %d needs seconds > 0", i+2)
		}
		for crop, n := range l.Crops {
			if _, ok := c.cropsByID[crop]; !ok || n <= 0 {
				return fmt.Errorf("config: manor level %d has bad crop %q", i+2, crop)
			}
		}
	}
	return nil
}

// ManorLevel is the manor's current level (old saves start at 1).
func (f *Farm) ManorLevel() int {
	return max(1, f.Manor)
}

// NextManor is the cost of the next manor level, or false at the top.
func (f *Farm) NextManor(cfg *Config) (ManorLevel, bool) {
	l := f.ManorLevel()
	if l >= cfg.Manor.MaxLevel || l-1 >= len(cfg.Manor.Levels) {
		return ManorLevel{}, false
	}
	return cfg.Manor.Levels[l-1], true
}

// settleManor finishes a manor upgrade whose time has come.
func (f *Farm) settleManor(now time.Time) {
	if f.ManorReadyAt != nil && !now.Before(*f.ManorReadyAt) {
		f.Manor = f.ManorLevel() + 1
		f.ManorReadyAt = nil
	}
}

// UpgradeManor pays for the next manor level and starts building it.
func (f *Farm) UpgradeManor(cfg *Config, now time.Time) error {
	f.Settle(cfg, now)
	if f.ManorReadyAt != nil {
		return ErrBusy
	}
	next, ok := f.NextManor(cfg)
	if !ok {
		return ErrMaxLevel
	}
	if f.Level() < next.PlayerLevel {
		return ErrLocked
	}
	for crop, n := range next.Crops {
		if f.Barn[crop] < n {
			return ErrNoCrops
		}
	}
	if f.Coins < next.Coins {
		return ErrNotEnough
	}
	for crop, n := range next.Crops {
		f.addCrops(crop, -n)
	}
	f.Coins -= next.Coins
	f.Manor = f.ManorLevel()
	ready := now.UTC().Add(time.Duration(next.Seconds) * time.Second)
	f.ManorReadyAt = &ready
	return nil
}
