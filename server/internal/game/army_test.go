package game

import (
	"errors"
	"testing"
	"time"
)

func TestBuildScarecrowQueue(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	guard, _ := cfg.Scarecrow("straw_guard")

	if err := f.BuildScarecrow(cfg, "straw_guard", now); !errors.Is(err, ErrNoCrops) {
		t.Fatalf("build with empty barn err = %v", err)
	}
	f.Barn = map[string]int{"dustwheat": 10}
	for i := 0; i < 2; i++ {
		if err := f.BuildScarecrow(cfg, "straw_guard", now); err != nil {
			t.Fatalf("build %d: %v", i, err)
		}
	}
	if len(f.Barn) != 0 || f.Coins != cfg.Farm.StartCoins-2*guard.Coins {
		t.Fatalf("barn = %v coins = %d", f.Barn, f.Coins)
	}
	// builds run one after another
	if !f.Queue[1].ReadyAt.Equal(now.Add(2 * time.Duration(guard.BuildSeconds) * time.Second)) {
		t.Fatalf("second build ready at %v", f.Queue[1].ReadyAt)
	}
	f.Settle(cfg, now.Add(time.Duration(guard.BuildSeconds)*time.Second))
	if len(f.Army) != 1 || len(f.Queue) != 1 {
		t.Fatalf("after one build time: army %d queue %d", len(f.Army), len(f.Queue))
	}
	if err := f.BuildScarecrow(cfg, "moon_witch", now); !errors.Is(err, ErrLocked) {
		t.Fatalf("locked scarecrow err = %v", err)
	}
	if err := f.BuildScarecrow(cfg, "nope", now); !errors.Is(err, ErrUnknownScarecrow) {
		t.Fatalf("unknown scarecrow err = %v", err)
	}
}

func TestArmySlotsLimitBuilds(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Now()
	f.Barn = map[string]int{"dustwheat": 100}
	f.Coins = 1000
	f.Army = []Unit{{"straw_guard"}, {"straw_guard"}}
	if err := f.BuildScarecrow(cfg, "straw_guard", now); err != nil {
		t.Fatal(err)
	}
	if err := f.BuildScarecrow(cfg, "straw_guard", now); !errors.Is(err, ErrQueueFull) {
		t.Fatalf("over the %d slots err = %v", f.ArmySlots(cfg), err)
	}
}

func TestRaidWinAndCooldown(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	rats, _ := cfg.Raid("dust_rats")

	if _, err := f.Raid(cfg, "dust_rats", now, 1); !errors.Is(err, ErrNoArmy) {
		t.Fatalf("raid without army err = %v", err)
	}
	f.Army = []Unit{{"pumpkin_brute"}, {"straw_guard"}, {"straw_guard"}}
	coins := f.Coins
	res, err := f.Raid(cfg, "dust_rats", now, 1)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Won || f.Coins != coins+rats.RewardCoins || len(res.Hits) == 0 {
		t.Fatalf("raid result %+v", res)
	}
	if len(f.Army)+len(res.Lost) != 3 {
		t.Fatalf("army %d + lost %d != 3", len(f.Army), len(res.Lost))
	}
	if _, err := f.Raid(cfg, "dust_rats", now.Add(time.Minute), 2); !errors.Is(err, ErrRaidCooldown) {
		t.Fatalf("raid during cooldown err = %v", err)
	}
}

func TestRaidIsDeterministicAndCanBeLost(t *testing.T) {
	cfg := mustConfig(t)
	now := time.Now()
	run := func(seed uint64) RaidResult {
		f := NewFarm(cfg)
		f.XP = 1000 // unlock everything
		f.Army = []Unit{{"straw_guard"}}
		res, err := f.Raid(cfg, "scrap_golem", now, seed)
		if err != nil {
			t.Fatal(err)
		}
		if len(f.Army) != 0 {
			t.Fatalf("lone guard survived the golem")
		}
		return res
	}
	a, b := run(7), run(7)
	if a.Won || len(a.Hits) != len(b.Hits) || a.Hits[0] != b.Hits[0] {
		t.Fatalf("same seed gave different fights or a win: %+v vs %+v", a, b)
	}
}

func TestDefaultConfigScarecrowsAreAffordable(t *testing.T) {
	cfg := mustConfig(t)
	for _, sc := range cfg.Scarecrows {
		if len(sc.Cost) == 0 {
			t.Errorf("%s costs no crops", sc.ID)
		}
	}
	if cfg.Army.BaseSlots < 1 || cfg.Army.QueueSize < 1 {
		t.Fatal("army config missing")
	}
}
