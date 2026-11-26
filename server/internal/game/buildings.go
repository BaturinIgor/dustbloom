package game

import (
	"errors"
	"fmt"
	"time"
)

// Errors returned by building actions.
var (
	ErrUnknownBuilding = errors.New("unknown_building")
	ErrManorTooLow     = errors.New("manor_too_low")
)

// Building effects: each level adds PerLevel percent, up to Cap.
const (
	EffectGrow         = "grow"          // crops grow faster (new plantings)
	EffectSell         = "sell"          // more coins when selling crops
	EffectBuildTime    = "build_time"    // scarecrows build faster
	EffectArmyPower    = "army_power"    // scarecrows hit harder and live longer
	EffectOrderReward  = "order_reward"  // more coins for orders
	EffectRaidCooldown = "raid_cooldown" // camps are ready again sooner
)

// BuildingsConfig lists the working buildings. Their level can never pass
// the manor's level, and they share one builder with the manor: only one
// construction runs at a time.
type BuildingsConfig struct {
	List []BuildingType `json:"list"`
}

// BuildingType is one working building. Levels[i] is the cost of reaching
// level i+1 from level i (so Levels[0] builds it when StartLevel is 0).
type BuildingType struct {
	ID          string            `json:"id"`
	Name        map[string]string `json:"name"`
	Effect      string            `json:"effect"`
	PerLevel    float64           `json:"perLevel"`
	Cap         float64           `json:"cap"`
	UnlockManor int               `json:"unlockManor"`
	StartLevel  int               `json:"startLevel"`
	Levels      []BuildLevel      `json:"levels"`
}

// BuildLevel is one construction step.
type BuildLevel struct {
	Coins   int            `json:"coins"`
	Crops   map[string]int `json:"crops,omitempty"`
	Seconds int            `json:"seconds"`
	// Power is the Мощь this level adds.
	Power int `json:"power"`
}

// Work is the building under construction.
type Work struct {
	Building string    `json:"building"`
	ReadyAt  time.Time `json:"readyAt"`
}

var knownEffects = map[string]bool{
	EffectGrow: true, EffectSell: true, EffectBuildTime: true,
	EffectArmyPower: true, EffectOrderReward: true, EffectRaidCooldown: true,
}

func (c *Config) indexBuildings() error {
	c.buildingsByID = map[string]BuildingType{}
	for _, b := range c.Buildings.List {
		if b.ID == "" || !knownEffects[b.Effect] || b.PerLevel <= 0 {
			return fmt.Errorf("config: building %q needs id, a known effect and perLevel", b.ID)
		}
		if _, dup := c.buildingsByID[b.ID]; dup {
			return fmt.Errorf("config: duplicate building %q", b.ID)
		}
		if b.StartLevel < 0 || b.StartLevel > len(b.Levels) {
			return fmt.Errorf("config: building %q has bad startLevel", b.ID)
		}
		for i, l := range b.Levels {
			if l.Seconds <= 0 || l.Coins < 0 {
				return fmt.Errorf("config: building %q level %d needs seconds > 0", b.ID, i+1)
			}
			for crop, n := range l.Crops {
				if _, ok := c.cropsByID[crop]; !ok || n <= 0 {
					return fmt.Errorf("config: building %q level %d has bad crop %q", b.ID, i+1, crop)
				}
			}
		}
		c.buildingsByID[b.ID] = b
	}
	return nil
}

// Building looks up a building type by id.
func (c *Config) Building(id string) (BuildingType, bool) {
	b, ok := c.buildingsByID[id]
	return b, ok
}

// BuildingLevel is the current level of a building (StartLevel if never touched).
func (f *Farm) BuildingLevel(cfg *Config, id string) int {
	if n, ok := f.Buildings[id]; ok {
		return n
	}
	b, _ := cfg.Building(id)
	return b.StartLevel
}

// Bonus is the summed percent of an effect over all buildings.
func (f *Farm) Bonus(cfg *Config, effect string) float64 {
	total := 0.0
	for _, b := range cfg.Buildings.List {
		if b.Effect != effect {
			continue
		}
		v := b.PerLevel * float64(f.BuildingLevel(cfg, b.ID))
		if b.Cap > 0 && v > b.Cap {
			v = b.Cap
		}
		total += v
	}
	return total
}

// faster shortens seconds by the effect's percent, never below 1 s.
func (f *Farm) faster(cfg *Config, effect string, seconds int) int {
	p := f.Bonus(cfg, effect)
	if p <= 0 {
		return seconds
	}
	return max(1, int(float64(seconds)*(100-p)/100+0.5))
}

// more raises an amount by the effect's percent.
func (f *Farm) more(cfg *Config, effect string, n int) int {
	p := f.Bonus(cfg, effect)
	if p <= 0 {
		return n
	}
	return int(float64(n)*(100+p)/100 + 0.5)
}

// Busy reports whether the builder is working (manor or a building).
func (f *Farm) Busy() bool {
	return f.ManorReadyAt != nil || f.Work != nil
}

// NextBuilding is the cost of a building's next level, or false at the top.
func (f *Farm) NextBuilding(cfg *Config, id string) (BuildLevel, bool) {
	b, ok := cfg.Building(id)
	if !ok {
		return BuildLevel{}, false
	}
	l := f.BuildingLevel(cfg, id)
	if l >= len(b.Levels) {
		return BuildLevel{}, false
	}
	return b.Levels[l], true
}

// settleBuildings finishes a construction whose time has come.
func (f *Farm) settleBuildings(cfg *Config, now time.Time) {
	if f.Work != nil && !now.Before(f.Work.ReadyAt) {
		if f.Buildings == nil {
			f.Buildings = map[string]int{}
		}
		f.Buildings[f.Work.Building] = f.BuildingLevel(cfg, f.Work.Building) + 1
		f.Work = nil
	}
}

// UpgradeBuilding pays for a building's next level and starts the work.
// The new level may not pass the manor's level.
func (f *Farm) UpgradeBuilding(cfg *Config, id string, now time.Time) error {
	f.Settle(cfg, now)
	b, ok := cfg.Building(id)
	if !ok {
		return ErrUnknownBuilding
	}
	if f.Busy() {
		return ErrBusy
	}
	next, ok := f.NextBuilding(cfg, id)
	if !ok {
		return ErrMaxLevel
	}
	if f.ManorLevel() < b.UnlockManor || f.BuildingLevel(cfg, id)+1 > f.ManorLevel() {
		return ErrManorTooLow
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
	f.Work = &Work{Building: id, ReadyAt: now.UTC().Add(time.Duration(next.Seconds) * time.Second)}
	return nil
}

// Power (Мощь) from the manor and the working buildings. Heroes, the army
// and the rest of the 18 sources will add to it later.
func (f *Farm) Power(cfg *Config) int {
	p := cfg.Manor.StartPower
	for i := 0; i < f.ManorLevel()-1 && i < len(cfg.Manor.Levels); i++ {
		p += cfg.Manor.Levels[i].Power
	}
	for _, b := range cfg.Buildings.List {
		for i := 0; i < f.BuildingLevel(cfg, b.ID) && i < len(b.Levels); i++ {
			p += b.Levels[i].Power
		}
	}
	return p
}
