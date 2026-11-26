package game

import (
	"errors"
	"testing"
	"time"
)

func TestFirstQuestsAreActive(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	qs := f.ActiveQuests(cfg)
	if len(qs) != cfg.Quests.Active || qs[0].ID != cfg.Quests.List[0].ID {
		t.Fatalf("active = %v", qs)
	}
}

func TestHarvestQuestClaim(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	q := f.ActiveQuests(cfg)[0]
	if _, err := f.ClaimQuest(cfg, q.ID); !errors.Is(err, ErrQuestNotDone) {
		t.Fatalf("claim early: %v", err)
	}
	f.Stats = map[string]int{q.Goal: q.Count}
	coins := f.Coins
	res, err := f.ClaimQuest(cfg, q.ID)
	if err != nil {
		t.Fatal(err)
	}
	if f.Coins != coins+q.Coins || res.Coins != q.Coins {
		t.Fatalf("coins %d -> %d", coins, f.Coins)
	}
	if _, err := f.ClaimQuest(cfg, q.ID); !errors.Is(err, ErrUnknownQuest) {
		t.Fatalf("claimed twice: %v", err)
	}
	for _, a := range f.ActiveQuests(cfg) {
		if a.ID == q.ID {
			t.Fatal("claimed quest still active")
		}
	}
}

func TestActionsCountTowardQuests(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	f.Coins = 10000
	now := time.Now()
	x, y := -1, -1
	for i, tl := range f.Tiles {
		if tl.Tilled {
			x, y = i%f.Width, i/f.Width
			break
		}
	}
	if err := f.Plant(cfg, x, y, "dustwheat", now); err != nil {
		t.Fatal(err)
	}
	crop, _ := cfg.Crop("dustwheat")
	if _, err := f.Harvest(cfg, x, y, now.Add(time.Duration(crop.GrowSeconds)*time.Second)); err != nil {
		t.Fatal(err)
	}
	if f.Stats["plant"] != 1 || f.Stats["harvest"] != 1 || f.Stats["harvest:dustwheat"] != 1 {
		t.Fatalf("stats = %v", f.Stats)
	}
	if _, err := f.Sell(cfg, "dustwheat", 1); err != nil {
		t.Fatal(err)
	}
	if f.Stats["sell"] != 1 {
		t.Fatalf("stats = %v", f.Stats)
	}
}

func TestLockedQuestsWaitForLevel(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	for _, q := range f.ActiveQuests(cfg) {
		if q.UnlockLevel > 1 {
			t.Fatalf("%s shows at level 1", q.ID)
		}
	}
	f.XP = 100000
	f.QuestsDone = nil
	for _, q := range cfg.Quests.List[:20] {
		f.QuestsDone = append(f.QuestsDone, q.ID)
	}
	if qs := f.ActiveQuests(cfg); len(qs) == 0 || qs[0].ID != cfg.Quests.List[20].ID {
		t.Fatalf("after 20 claims active = %v", qs)
	}
}

func TestBadQuestGoalIsRejected(t *testing.T) {
	raw := RawDefaultConfig()
	cfg, _ := ParseConfig(raw)
	cfg.Quests.List = append(cfg.Quests.List, Quest{ID: "x", Goal: "harvest:nope", Count: 1})
	if err := cfg.validateQuests(); err == nil {
		t.Fatal("unknown crop goal accepted")
	}
}
