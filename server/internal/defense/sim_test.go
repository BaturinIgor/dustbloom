package defense

import "testing"

// TestPacing guards the six-month pacing: a free player finishes in about
// 175 days, payers are faster but never trivially fast.
func TestPacing(t *testing.T) {
	b := Default()
	want := map[string][2]int{ // finish day range
		"f2p":       {165, 185},
		"f2p+ads":   {140, 175},
		"$15/month": {110, 140},
		"whale":     {80, 110},
	}
	for _, p := range Profiles() {
		logs := Simulate(b, p, 240)
		d := FinishDay(logs, b.TotalWaves())
		r := want[p.Name]
		if d < r[0] || d > r[1] {
			t.Errorf("%s finishes on day %d, want %d..%d (lands %v)", p.Name, d, r[0], r[1], LandDays(b, logs))
		}
	}
}

// TestNoHardWall: the free player never goes 14 days without a new wave.
func TestNoHardWall(t *testing.T) {
	b := Default()
	logs := Simulate(b, Profiles()[0], 200)
	last, lastDay := 0, 0
	for _, l := range logs {
		if l.Wave > last {
			last, lastDay = l.Wave, l.Day
		}
		if l.Wave < b.TotalWaves() && l.Day-lastDay > 14 {
			t.Fatalf("stuck at wave %d from day %d to %d", last, lastDay, l.Day)
		}
	}
}
