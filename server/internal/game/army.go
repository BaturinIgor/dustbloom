package game

import (
	"errors"
	"hash/fnv"
	"math/rand/v2"
	"time"
)

// Errors returned by army and raid actions.
var (
	ErrUnknownScarecrow = errors.New("unknown_scarecrow")
	ErrQueueFull        = errors.New("queue_full")
	ErrUnknownRaid      = errors.New("unknown_raid")
	ErrRaidCooldown     = errors.New("raid_cooldown")
	ErrNoArmy           = errors.New("no_army")
)

// Unit is one scarecrow in the army. Survivors heal fully after a raid.
type Unit struct {
	Type string `json:"type"`
}

// Build is a scarecrow in the workshop.
type Build struct {
	Type    string    `json:"type"`
	ReadyAt time.Time `json:"readyAt"`
}

// ArmySlots is how many scarecrows the farm can field at its level.
func (f *Farm) ArmySlots(cfg *Config) int {
	n := cfg.Army.BaseSlots + cfg.Army.SlotsPerLevel*(f.Level()-1)
	if cfg.Army.MaxSlots > 0 && n > cfg.Army.MaxSlots {
		n = cfg.Army.MaxSlots
	}
	return n
}

// Settle moves finished scarecrows from the workshop into the army while
// there is room. Every action calls it first, so time is the only input.
func (f *Farm) Settle(cfg *Config, now time.Time) {
	for len(f.Queue) > 0 && !now.Before(f.Queue[0].ReadyAt) && len(f.Army) < f.ArmySlots(cfg) {
		f.Army = append(f.Army, Unit{Type: f.Queue[0].Type})
		f.Queue = f.Queue[1:]
	}
	if len(f.Queue) == 0 {
		f.Queue = nil
	}
}

// BuildScarecrow spends barn crops and coins and queues a scarecrow. Builds
// run one after another: each starts when the previous one is done.
func (f *Farm) BuildScarecrow(cfg *Config, id string, now time.Time) error {
	f.Settle(cfg, now)
	sc, ok := cfg.Scarecrow(id)
	if !ok {
		return ErrUnknownScarecrow
	}
	if f.Level() < sc.UnlockLevel {
		return ErrLocked
	}
	if len(f.Queue) >= cfg.Army.QueueSize || len(f.Army)+len(f.Queue) >= f.ArmySlots(cfg) {
		return ErrQueueFull
	}
	for crop, n := range sc.Cost {
		if f.Barn[crop] < n {
			return ErrNoCrops
		}
	}
	if f.Coins < sc.Coins {
		return ErrNotEnough
	}
	for crop, n := range sc.Cost {
		f.addCrops(crop, -n)
	}
	f.Coins -= sc.Coins
	start := now.UTC()
	if len(f.Queue) > 0 && f.Queue[len(f.Queue)-1].ReadyAt.After(start) {
		start = f.Queue[len(f.Queue)-1].ReadyAt
	}
	f.Queue = append(f.Queue, Build{Type: id, ReadyAt: start.Add(time.Duration(sc.BuildSeconds) * time.Second)})
	return nil
}

// Hit is one blow in a battle, for the client to replay.
type Hit struct {
	Round    int  `json:"round"`
	FromArmy bool `json:"fromArmy"` // true: a scarecrow hits an enemy
	From     int  `json:"from"`     // index in the attacker's line-up
	To       int  `json:"to"`       // index in the defender's line-up
	Damage   int  `json:"damage"`
	Kill     bool `json:"kill"`
}

// RaidResult is the outcome of a raid.
type RaidResult struct {
	Raid    string `json:"raid"`
	Won     bool   `json:"won"`
	Lost    []int  `json:"lost"` // army indexes (before the raid) that fell
	Coins   int    `json:"coins"`
	XP      int    `json:"xp"`
	LevelUp bool   `json:"levelUp"`
	Hits    []Hit  `json:"hits"`
}

const maxRounds = 30

// Raid sends the whole army against a camp. The fight is simulated here, on
// the server; the client only replays the hits. Fallen scarecrows are gone.
func (f *Farm) Raid(cfg *Config, raidID string, now time.Time, seed uint64) (RaidResult, error) {
	f.Settle(cfg, now)
	raid, ok := cfg.Raid(raidID)
	if !ok {
		return RaidResult{}, ErrUnknownRaid
	}
	if f.Level() < raid.UnlockLevel {
		return RaidResult{}, ErrLocked
	}
	if ready, ok := f.RaidReadyAt[raidID]; ok && now.Before(ready) {
		return RaidResult{}, ErrRaidCooldown
	}
	if len(f.Army) == 0 {
		return RaidResult{}, ErrNoArmy
	}

	type fighter struct{ hp, atk int }
	ours := make([]fighter, len(f.Army))
	for i, u := range f.Army {
		sc, _ := cfg.Scarecrow(u.Type)
		ours[i] = fighter{sc.HP, sc.Attack}
	}
	theirs := make([]fighter, len(raid.Enemies))
	for i, e := range raid.Enemies {
		theirs[i] = fighter{e.HP, e.Attack}
	}
	rng := rand.New(rand.NewPCG(seed, hashString(raidID)))
	front := func(side []fighter) int {
		for i, x := range side {
			if x.hp > 0 {
				return i
			}
		}
		return -1
	}
	res := RaidResult{Raid: raidID}
	// Each round every living fighter strikes the front of the other side,
	// scarecrows first. Damage varies by +-20% so fights feel alive.
	for round := 1; round <= maxRounds && front(ours) >= 0 && front(theirs) >= 0; round++ {
		for _, side := range []bool{true, false} {
			atk, def := ours, theirs
			if !side {
				atk, def = theirs, ours
			}
			for i := range atk {
				if atk[i].hp <= 0 {
					continue
				}
				t := front(def)
				if t < 0 {
					break
				}
				dmg := max(1, int(float64(atk[i].atk)*(0.8+0.4*rng.Float64())+0.5))
				def[t].hp -= dmg
				res.Hits = append(res.Hits, Hit{Round: round, FromArmy: side, From: i, To: t, Damage: dmg, Kill: def[t].hp <= 0})
			}
		}
	}
	res.Won = front(theirs) < 0

	var survivors []Unit
	for i, u := range f.Army {
		if ours[i].hp > 0 {
			survivors = append(survivors, u)
		} else {
			res.Lost = append(res.Lost, i)
		}
	}
	f.Army = survivors
	if res.Won {
		before := f.Level()
		res.Coins, res.XP = raid.RewardCoins, raid.RewardXP
		f.Coins += res.Coins
		f.XP += res.XP
		res.LevelUp = f.Level() > before
		if f.RaidReadyAt == nil {
			f.RaidReadyAt = map[string]time.Time{}
		}
		f.RaidReadyAt[raidID] = now.UTC().Add(time.Duration(raid.CooldownSeconds) * time.Second)
	}
	f.Settle(cfg, now) // freed slots take waiting scarecrows
	return res, nil
}

func hashString(s string) uint64 {
	h := fnv.New64a()
	_, _ = h.Write([]byte(s))
	return h.Sum64()
}
