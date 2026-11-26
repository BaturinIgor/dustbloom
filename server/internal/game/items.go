package game

import (
	"errors"
	"fmt"
	"math/rand/v2"
	"sort"
	"time"
)

// Errors returned by storage (Склад) actions.
var (
	ErrUnknownItem    = errors.New("unknown_item")
	ErrNoItems        = errors.New("not_enough_items")
	ErrWrongTarget    = errors.New("wrong_target")
	ErrNothingToSpeed = errors.New("nothing_to_speed_up")
	ErrUnknownTarget  = errors.New("unknown_target")
	ErrNotAChest      = errors.New("not_a_chest")
	ErrNotASpeedup    = errors.New("not_a_speedup")
	errBadItemsConfig = errors.New("config: items")
)

// Coins is the pseudo item id a chest uses to drop coins.
const Coins = "coins"

// Speedup targets. "any" works on everything.
const (
	TargetAny     = "any"
	TargetRecruit = "recruit" // the scarecrow workshop queue
	TargetGrow    = "grow"    // one crop on a tile
)

// ItemsConfig describes what the storage can hold. Speedups are generated
// from targets x denominations: id "speed_<target>_<label>", e.g. speed_any_5m.
type ItemsConfig struct {
	SpeedupTargets []string        `json:"speedupTargets"`
	SpeedupSeconds []int           `json:"speedupSeconds"`
	Chests         []Chest         `json:"chests"`
	StartItems     map[string]int  `json:"startItems"`
	LevelUp        []LevelUpReward `json:"levelUp"`
}

// LevelUpReward is granted on reaching every level divisible by Every.
type LevelUpReward struct {
	Every int            `json:"every"`
	Items map[string]int `json:"items"`
}

// Chest opens into Rolls random drops.
type Chest struct {
	ID    string            `json:"id"`
	Name  map[string]string `json:"name"`
	Rolls int               `json:"rolls"`
	Drops []Drop            `json:"drops"`
}

// Drop is one weighted line of a chest's loot table.
type Drop struct {
	Item   string `json:"item"`
	Min    int    `json:"min"`
	Max    int    `json:"max"`
	Weight int    `json:"weight"`
}

// Speedup is a parsed speedup item.
type Speedup struct {
	ID      string
	Target  string
	Seconds int
}

// SpeedupLabel is the short duration in an item id: 1m, 15m, 1h, 24h.
func SpeedupLabel(seconds int) string {
	if seconds < 3600 {
		return fmt.Sprintf("%dm", seconds/60)
	}
	return fmt.Sprintf("%dh", seconds/3600)
}

// SpeedupID builds the item id for a target and duration.
func SpeedupID(target string, seconds int) string {
	return "speed_" + target + "_" + SpeedupLabel(seconds)
}

func (c *Config) indexItems() error {
	c.speedups = map[string]Speedup{}
	for _, t := range c.Items.SpeedupTargets {
		for _, s := range c.Items.SpeedupSeconds {
			if s < 60 {
				return fmt.Errorf("%w: speedup seconds must be >= 60", errBadItemsConfig)
			}
			id := SpeedupID(t, s)
			c.speedups[id] = Speedup{ID: id, Target: t, Seconds: s}
		}
	}
	c.chestsByID = map[string]Chest{}
	for _, ch := range c.Items.Chests {
		if ch.ID == "" || ch.Rolls <= 0 || len(ch.Drops) == 0 {
			return fmt.Errorf("%w: chest %q needs id, rolls and drops", errBadItemsConfig, ch.ID)
		}
		if _, dup := c.chestsByID[ch.ID]; dup {
			return fmt.Errorf("%w: duplicate chest %q", errBadItemsConfig, ch.ID)
		}
		c.chestsByID[ch.ID] = ch
	}
	check := func(where string, items map[string]int) error {
		for id, n := range items {
			if n <= 0 || (id != Coins && !c.IsItem(id)) {
				return fmt.Errorf("%w: %s has bad item %q", errBadItemsConfig, where, id)
			}
		}
		return nil
	}
	for _, ch := range c.Items.Chests {
		for _, d := range ch.Drops {
			if d.Weight <= 0 || d.Min <= 0 || d.Max < d.Min || (d.Item != Coins && !c.IsItem(d.Item)) {
				return fmt.Errorf("%w: chest %q has bad drop %q", errBadItemsConfig, ch.ID, d.Item)
			}
		}
	}
	if err := check("startItems", c.Items.StartItems); err != nil {
		return err
	}
	for _, l := range c.Items.LevelUp {
		if l.Every <= 0 {
			return fmt.Errorf("%w: levelUp every must be > 0", errBadItemsConfig)
		}
		if err := check("levelUp", l.Items); err != nil {
			return err
		}
	}
	for _, r := range c.Raids {
		if err := check("raid "+r.ID, r.Drops); err != nil {
			return err
		}
	}
	return nil
}

// IsItem reports whether id is a known storage item.
func (c *Config) IsItem(id string) bool {
	if _, ok := c.speedups[id]; ok {
		return true
	}
	_, ok := c.chestsByID[id]
	return ok
}

// Speedup looks up a speedup item.
func (c *Config) Speedup(id string) (Speedup, bool) {
	s, ok := c.speedups[id]
	return s, ok
}

// Chest looks up a chest item.
func (c *Config) Chest(id string) (Chest, bool) {
	ch, ok := c.chestsByID[id]
	return ch, ok
}

// LevelUpItems is what reaching level gives.
func (c *Config) LevelUpItems(level int) map[string]int {
	out := map[string]int{}
	for _, l := range c.Items.LevelUp {
		if level%l.Every == 0 {
			for id, n := range l.Items {
				out[id] += n
			}
		}
	}
	return out
}

// Grant adds items (and coins) to the farm.
func (f *Farm) Grant(items map[string]int) {
	for id, n := range items {
		if id == Coins {
			f.Coins += n
			continue
		}
		if f.Items == nil {
			f.Items = map[string]int{}
		}
		f.Items[id] += n
		if f.Items[id] <= 0 {
			delete(f.Items, id)
		}
	}
}

// gainXP adds XP and grants every level-up reward on the way. It returns
// whether the level changed and what was granted.
func (f *Farm) gainXP(cfg *Config, xp int) (bool, map[string]int) {
	before := f.Level()
	f.XP += xp
	after := f.Level()
	var got map[string]int
	for l := before + 1; l <= after; l++ {
		for id, n := range cfg.LevelUpItems(l) {
			if got == nil {
				got = map[string]int{}
			}
			got[id] += n
		}
	}
	f.Grant(got)
	return after > before, got
}

// SpeedTarget names what a speedup is used on.
type SpeedTarget struct {
	Kind string `json:"kind"` // recruit | grow
	X    int    `json:"x"`
	Y    int    `json:"y"`
}

// Remaining is how many seconds the target still needs.
func (f *Farm) Remaining(cfg *Config, t SpeedTarget, now time.Time) (int, error) {
	switch t.Kind {
	case TargetRecruit:
		if len(f.Queue) == 0 {
			return 0, ErrNothingToSpeed
		}
		return ceilSeconds(f.Queue[len(f.Queue)-1].ReadyAt.Sub(now)), nil
	case TargetGrow:
		tl, err := f.tile(t.X, t.Y)
		if err != nil {
			return 0, err
		}
		if tl.Crop == "" || tl.PlantedAt == nil {
			return 0, ErrNothingToSpeed
		}
		crop, ok := cfg.Crop(tl.Crop)
		if !ok {
			return 0, ErrUnknownCrop
		}
		return ceilSeconds(time.Duration(crop.GrowSeconds)*time.Second - now.Sub(*tl.PlantedAt)), nil
	}
	return 0, ErrUnknownTarget
}

func ceilSeconds(d time.Duration) int {
	if d <= 0 {
		return 0
	}
	return int((d + time.Second - 1) / time.Second)
}

// UseSpeedups spends the given speedups on a target and returns the seconds
// saved. Every item must fit the target (its own kind or "any").
func (f *Farm) UseSpeedups(cfg *Config, t SpeedTarget, use map[string]int, now time.Time) (int, error) {
	f.Settle(cfg, now)
	left, err := f.Remaining(cfg, t, now)
	if err != nil {
		return 0, err
	}
	if left <= 0 {
		return 0, ErrNothingToSpeed
	}
	total := 0
	for id, n := range use {
		s, ok := cfg.Speedup(id)
		if !ok {
			if cfg.IsItem(id) {
				return 0, ErrNotASpeedup
			}
			return 0, ErrUnknownItem
		}
		if s.Target != TargetAny && s.Target != t.Kind {
			return 0, ErrWrongTarget
		}
		if n <= 0 || f.Items[id] < n {
			return 0, ErrNoItems
		}
		total += s.Seconds * n
	}
	if total == 0 {
		return 0, ErrNoItems
	}
	for id, n := range use {
		f.Grant(map[string]int{id: -n})
	}
	d := time.Duration(total) * time.Second
	switch t.Kind {
	case TargetRecruit:
		for i := range f.Queue {
			f.Queue[i].ReadyAt = f.Queue[i].ReadyAt.Add(-d)
			if f.Queue[i].ReadyAt.Before(now) {
				f.Queue[i].ReadyAt = now.UTC()
			}
		}
		f.Settle(cfg, now)
	case TargetGrow:
		tl, _ := f.tile(t.X, t.Y)
		p := tl.PlantedAt.Add(-d)
		tl.PlantedAt = &p
	}
	return min(total, left), nil
}

// PlanSpeedups picks speedups from the storage that cover the target with as
// little waste as possible: whole items that fit first (largest first, the
// target's own kind before "any"), then the smallest single item that covers
// the rest. If the storage can't cover it all, it uses everything that fits.
func (f *Farm) PlanSpeedups(cfg *Config, t SpeedTarget, now time.Time) (map[string]int, error) {
	left, err := f.Remaining(cfg, t, now)
	if err != nil {
		return nil, err
	}
	if left <= 0 {
		return nil, ErrNothingToSpeed
	}
	type cand struct {
		s        Speedup
		have     int
		specific bool
	}
	var cs []cand
	for id, n := range f.Items {
		s, ok := cfg.Speedup(id)
		if ok && n > 0 && (s.Target == t.Kind || s.Target == TargetAny) {
			cs = append(cs, cand{s, n, s.Target == t.Kind})
		}
	}
	if len(cs) == 0 {
		return nil, ErrNoItems
	}
	sort.Slice(cs, func(i, j int) bool {
		if cs[i].s.Seconds != cs[j].s.Seconds {
			return cs[i].s.Seconds > cs[j].s.Seconds
		}
		if cs[i].specific != cs[j].specific {
			return cs[i].specific
		}
		return cs[i].s.ID < cs[j].s.ID
	})
	plan := map[string]int{}
	for i := range cs {
		k := min(cs[i].have, left/cs[i].s.Seconds)
		if k > 0 {
			plan[cs[i].s.ID] += k
			cs[i].have -= k
			left -= k * cs[i].s.Seconds
		}
	}
	if left > 0 {
		for i := len(cs) - 1; i >= 0; i-- { // smallest first
			if cs[i].have > 0 && cs[i].s.Seconds >= left {
				// prefer the target's own kind at the same size
				j := i
				for j > 0 && cs[j-1].s.Seconds == cs[i].s.Seconds && cs[j-1].have > 0 {
					j--
				}
				plan[cs[j].s.ID]++
				left = 0
				break
			}
		}
	}
	return plan, nil
}

// OpenChest opens count chests and grants the loot.
func (f *Farm) OpenChest(cfg *Config, id string, count int, seed uint64) (map[string]int, error) {
	ch, ok := cfg.Chest(id)
	if !ok {
		if cfg.IsItem(id) {
			return nil, ErrNotAChest
		}
		return nil, ErrUnknownItem
	}
	if count <= 0 || f.Items[id] < count {
		return nil, ErrNoItems
	}
	f.Grant(map[string]int{id: -count})
	total := 0
	for _, d := range ch.Drops {
		total += d.Weight
	}
	rng := rand.New(rand.NewPCG(seed, hashString(id)))
	got := map[string]int{}
	for c := 0; c < count; c++ {
		for r := 0; r < ch.Rolls; r++ {
			pick := rng.IntN(total)
			for _, d := range ch.Drops {
				if pick < d.Weight {
					got[d.Item] += d.Min + rng.IntN(d.Max-d.Min+1)
					break
				}
				pick -= d.Weight
			}
		}
	}
	f.Grant(got)
	return got, nil
}

// SortedItems lists item ids in a stable display order (for tests and logs).
func SortedItems(items map[string]int) []string {
	ids := make([]string, 0, len(items))
	for id := range items {
		ids = append(ids, id)
	}
	sort.Strings(ids)
	return ids
}
