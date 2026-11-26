package game

import (
	"errors"
	"fmt"
	"slices"
	"strings"
)

var (
	ErrUnknownQuest = errors.New("unknown_quest")
	ErrQuestNotDone = errors.New("quest_not_done")
)

// Quest is one task on the quest list. Goal is a counter key from Stats
// ("harvest:dustwheat", "raid_win", ...) or a derived value: "level",
// "manor", "building:<id>", "plots", "army". Quests come in list order;
// a few are active at a time.
type Quest struct {
	ID          string         `json:"id"`
	Goal        string         `json:"goal"`
	Count       int            `json:"count"`
	UnlockLevel int            `json:"unlockLevel,omitempty"`
	Coins       int            `json:"coins"`
	XP          int            `json:"xp"`
	Items       map[string]int `json:"items,omitempty"`
}

// QuestConfig is the list and how many quests show at once.
type QuestConfig struct {
	Active int     `json:"active"`
	List   []Quest `json:"list"`
}

// QuestResult is what claiming gave.
type QuestResult struct {
	Quest   string         `json:"quest"`
	Coins   int            `json:"coins"`
	XP      int            `json:"xp"`
	LevelUp bool           `json:"levelUp"`
	Items   map[string]int `json:"items,omitempty"`
}

func (f *Farm) count(key string, n int) {
	if f.Stats == nil {
		f.Stats = map[string]int{}
	}
	f.Stats[key] += n
}

// QuestProgress is the current value of a quest's goal (capped at Count).
func (f *Farm) QuestProgress(cfg *Config, q Quest) int {
	var v int
	switch {
	case q.Goal == "level":
		v = f.Level()
	case q.Goal == "manor":
		v = f.ManorLevel()
	case q.Goal == "plots":
		v = f.PlotsBought(cfg)
	case q.Goal == "army":
		v = len(f.Army)
	case strings.HasPrefix(q.Goal, "building:"):
		v = f.BuildingLevel(cfg, strings.TrimPrefix(q.Goal, "building:"))
	default:
		v = f.Stats[q.Goal]
	}
	return min(v, q.Count)
}

// ActiveQuests are the first unclaimed quests open at the farm's level.
func (f *Farm) ActiveQuests(cfg *Config) []Quest {
	var out []Quest
	for _, q := range cfg.Quests.List {
		if len(out) >= cfg.Quests.Active {
			break
		}
		if slices.Contains(f.QuestsDone, q.ID) || f.Level() < q.UnlockLevel {
			continue
		}
		out = append(out, q)
	}
	return out
}

// ClaimQuest takes the reward of an active, finished quest.
func (f *Farm) ClaimQuest(cfg *Config, id string) (QuestResult, error) {
	i := slices.IndexFunc(f.ActiveQuests(cfg), func(q Quest) bool { return q.ID == id })
	if i < 0 {
		return QuestResult{}, ErrUnknownQuest
	}
	q := f.ActiveQuests(cfg)[i]
	if f.QuestProgress(cfg, q) < q.Count {
		return QuestResult{}, ErrQuestNotDone
	}
	f.QuestsDone = append(f.QuestsDone, q.ID)
	f.Coins += q.Coins
	f.Grant(q.Items)
	up, items := f.gainXP(cfg, q.XP)
	return QuestResult{Quest: q.ID, Coins: q.Coins, XP: q.XP, LevelUp: up, Items: mergeItems(q.Items, items)}, nil
}

// validateQuests checks that every quest names a known goal and reward.
func (c *Config) validateQuests() error {
	seen := map[string]bool{}
	for _, q := range c.Quests.List {
		if q.ID == "" || q.Count <= 0 || seen[q.ID] {
			return fmt.Errorf("config: quest %q needs a unique id and count > 0", q.ID)
		}
		seen[q.ID] = true
		if !c.knownGoal(q.Goal) {
			return fmt.Errorf("config: quest %q has unknown goal %q", q.ID, q.Goal)
		}
		for it, n := range q.Items {
			if !c.IsItem(it) || n <= 0 {
				return fmt.Errorf("config: quest %q has bad item %q", q.ID, it)
			}
		}
	}
	if len(c.Quests.List) > 0 && c.Quests.Active <= 0 {
		c.Quests.Active = 3
	}
	return nil
}

func (c *Config) knownGoal(g string) bool {
	switch g {
	case "level", "manor", "plots", "army", "harvest", "plant", "till", "sell", "build", "raid_win", "order", "clear", "plot":
		return true
	}
	kind, id, ok := strings.Cut(g, ":")
	if !ok {
		return false
	}
	switch kind {
	case "harvest":
		_, ok = c.Crop(id)
	case "build":
		_, ok = c.Scarecrow(id)
	case "raid_win":
		_, ok = c.Raid(id)
	case "building":
		_, ok = c.Building(id)
	default:
		ok = false
	}
	return ok
}
