package game

import (
	"testing"
	"time"
)

// xpForLevel is the total XP that reaches level l (each level needs 10 more).
func xpForLevel(l int) int {
	xp, need := 0, 10
	for i := 1; i < l; i++ {
		xp += need
		need += 10
	}
	return xp
}

// Every raid must be beatable at its unlock level by a full army of the
// best scarecrow open by then, and (after the tutorial raid) must not be
// a walkover for a third of it.
func TestRaidsAreBeatableAtTheirLevel(t *testing.T) {
	cfg := mustConfig(t)
	now := time.Now()
	for _, raid := range cfg.Raids {
		lvl := raid.UnlockLevel
		var best Scarecrow
		for _, sc := range cfg.Scarecrows {
			if sc.UnlockLevel <= lvl && sc.HP*sc.Attack > best.HP*best.Attack {
				best = sc
			}
		}
		try := func(n int) (wins int) {
			for seed := uint64(1); seed <= 20; seed++ {
				f := NewFarm(cfg)
				f.XP = xpForLevel(lvl)
				for i := 0; i < n; i++ {
					f.Army = append(f.Army, Unit{best.ID})
				}
				res, err := f.Raid(cfg, raid.ID, now, seed)
				if err != nil {
					t.Fatalf("%s: %v", raid.ID, err)
				}
				if res.Won {
					wins++
				}
			}
			return wins
		}
		f := NewFarm(cfg)
		f.XP = xpForLevel(lvl)
		full := f.ArmySlots(cfg)
		if w := try(full); w < 14 {
			t.Errorf("%s (lv %d): full army of %d %s wins only %d/20", raid.ID, lvl, full, best.ID, w)
		}
		// the first raid is the tutorial: it may be easy
		if w := try(max(1, full/3)); lvl > 1 && w > 10 {
			t.Errorf("%s (lv %d): a third of the army (%d %s) still wins %d/20", raid.ID, lvl, max(1, full/3), best.ID, w)
		}
	}
}
