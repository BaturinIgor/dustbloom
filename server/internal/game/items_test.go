package game

import (
	"errors"
	"testing"
	"time"
)

func TestNewFarmGetsStartItems(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	for id, n := range cfg.Items.StartItems {
		if f.Items[id] != n {
			t.Errorf("start %s = %d, want %d", id, f.Items[id], n)
		}
	}
	if !cfg.IsItem("speed_any_24h") || !cfg.IsItem("speed_recruit_1m") || cfg.IsItem("speed_any_2m") {
		t.Fatal("speedup ids wrong")
	}
}

func TestSpeedUpCrop(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Items = map[string]int{"speed_grow_15m": 1, "speed_recruit_5m": 1}
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	wheat, _ := cfg.Crop("dustwheat")
	if err := f.Plant(cfg, 6, 6, "dustwheat", now); err != nil {
		t.Fatal(err)
	}
	tgt := SpeedTarget{Kind: TargetGrow, X: 6, Y: 6}
	if _, err := f.UseSpeedups(cfg, tgt, map[string]int{"speed_recruit_5m": 1}, now); !errors.Is(err, ErrWrongTarget) {
		t.Fatalf("recruit speedup on crop err = %v", err)
	}
	saved, err := f.UseSpeedups(cfg, tgt, map[string]int{"speed_grow_15m": 1}, now)
	if err != nil {
		t.Fatal(err)
	}
	if saved != min(900, wheat.GrowSeconds) || f.Items["speed_grow_15m"] != 0 {
		t.Fatalf("saved %d, left %v", saved, f.Items)
	}
	if _, err := f.Harvest(cfg, 6, 6, now); err != nil {
		t.Fatalf("harvest after speedup: %v", err)
	}
	if _, err := f.UseSpeedups(cfg, tgt, map[string]int{"speed_recruit_5m": 1}, now); !errors.Is(err, ErrNothingToSpeed) {
		t.Fatalf("empty tile err = %v", err)
	}
}

func TestSpeedUpQueueShiftsAll(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Coins, f.Barn = 1000, map[string]int{"dustwheat": 50}
	f.Items = map[string]int{"speed_any_1m": 1}
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	for i := 0; i < 2; i++ {
		if err := f.BuildScarecrow(cfg, "straw_guard", now); err != nil {
			t.Fatal(err)
		}
	}
	// two 20 s builds: a 1 min speedup finishes both
	if _, err := f.UseSpeedups(cfg, SpeedTarget{Kind: TargetRecruit}, map[string]int{"speed_any_1m": 1}, now); err != nil {
		t.Fatal(err)
	}
	if len(f.Army) != 2 || len(f.Queue) != 0 {
		t.Fatalf("army %d queue %d", len(f.Army), len(f.Queue))
	}
}

func TestPlanSpeedupsWastesLittle(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	f.Queue = []Build{{Type: "straw_guard", ReadyAt: now.Add(47 * time.Minute)}}
	f.Items = map[string]int{
		"speed_any_1h": 2, "speed_recruit_30m": 1, "speed_any_15m": 3, "speed_any_1m": 5, "speed_grow_1h": 4,
	}
	plan, err := f.PlanSpeedups(cfg, SpeedTarget{Kind: TargetRecruit}, now)
	if err != nil {
		t.Fatal(err)
	}
	// 30m + 15m + 1m + 1m = 47m exactly; the grow speedups are never touched
	want := map[string]int{"speed_recruit_30m": 1, "speed_any_15m": 1, "speed_any_1m": 2}
	if len(plan) != len(want) {
		t.Fatalf("plan %v, want %v", plan, want)
	}
	for id, n := range want {
		if plan[id] != n {
			t.Fatalf("plan %v, want %v", plan, want)
		}
	}

	// 70 min left with only 1 h items: one hour fits, the rest takes one more
	f.Queue[0].ReadyAt = now.Add(70 * time.Minute)
	f.Items = map[string]int{"speed_any_1h": 3}
	plan, _ = f.PlanSpeedups(cfg, SpeedTarget{Kind: TargetRecruit}, now)
	if plan["speed_any_1h"] != 2 {
		t.Fatalf("cover plan %v", plan)
	}
	if _, err := f.UseSpeedups(cfg, SpeedTarget{Kind: TargetRecruit}, plan, now); err != nil {
		t.Fatal(err)
	}
	if len(f.Queue) != 0 || f.Items["speed_any_1h"] != 1 {
		t.Fatalf("queue %v items %v", f.Queue, f.Items)
	}

	f.Items = nil
	f.Queue = []Build{{Type: "straw_guard", ReadyAt: now.Add(time.Minute)}}
	if _, err := f.PlanSpeedups(cfg, SpeedTarget{Kind: TargetRecruit}, now); !errors.Is(err, ErrNoItems) {
		t.Fatalf("empty storage err = %v", err)
	}
}

func TestOpenChestIsDeterministic(t *testing.T) {
	cfg := mustConfig(t)
	a, b := NewFarm(cfg), NewFarm(cfg)
	a.Items = map[string]int{"chest_wood": 3}
	b.Items = map[string]int{"chest_wood": 3}
	ga, err := a.OpenChest(cfg, "chest_wood", 3, 42)
	if err != nil {
		t.Fatal(err)
	}
	gb, _ := b.OpenChest(cfg, "chest_wood", 3, 42)
	if len(ga) == 0 || len(ga) != len(gb) {
		t.Fatalf("loot %v vs %v", ga, gb)
	}
	for id, n := range ga {
		if gb[id] != n {
			t.Fatalf("loot %v vs %v", ga, gb)
		}
	}
	if a.Items["chest_wood"] != 0 {
		t.Fatal("chest not spent")
	}
	if _, err := a.OpenChest(cfg, "chest_wood", 1, 1); !errors.Is(err, ErrNoItems) {
		t.Fatalf("no chest err = %v", err)
	}
	if _, err := a.OpenChest(cfg, "speed_any_1m", 1, 1); !errors.Is(err, ErrNotAChest) {
		t.Fatalf("open speedup err = %v", err)
	}
}

func TestLevelUpGrantsChests(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Items = nil
	up, got := f.gainXP(cfg, 100) // level 1 -> 5
	if !up || f.Level() != 5 {
		t.Fatalf("level %d", f.Level())
	}
	if got["chest_wood"] != 4 || got["chest_iron"] != 1 || f.Items["chest_iron"] != 1 {
		t.Fatalf("level-up loot %v", got)
	}
}

func TestRaidWinDrops(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Items = nil
	for i := 0; i < 3; i++ {
		f.Army = append(f.Army, Unit{Type: "pumpkin_brute"})
	}
	res, err := f.Raid(cfg, "dust_rats", time.Now(), 7)
	if err != nil || !res.Won {
		t.Fatalf("raid %v %v", res.Won, err)
	}
	if f.Items["speed_recruit_1m"] != 2 || res.Items["speed_recruit_1m"] != 2 {
		t.Fatalf("drops %v / %v", f.Items, res.Items)
	}
}

func TestParseConfigRejectsBadItems(t *testing.T) {
	bad := `{"farm":{"width":4,"height":4,"plotSize":4},"items":{"chests":[{"id":"c","rolls":1,"drops":[{"item":"nope","min":1,"max":1,"weight":1}]}]}}`
	if _, err := ParseConfig([]byte(bad)); err == nil {
		t.Fatal("bad chest drop accepted")
	}
}
