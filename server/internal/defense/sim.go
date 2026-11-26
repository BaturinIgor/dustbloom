package defense

import "math"

// Profile describes how a simulated player plays and pays.
type Profile struct {
	Name           string
	GemsPerDay     float64 // quests, achievements, cards, pass, packs
	AdSummons      float64 // free summons from optional ads per day
	OfflineBonus   float64 // +x to offline income (Harvest card)
	OfflineHours   float64 // extra offline cap hours (Harvest card)
	IronMult       float64 // dungeon iron multiplier (bought refills, packs)
	PollenMult     float64 // talent pollen multiplier (event passes, packs)
	SessionMinutes float64
	SessionHours   []float64 // local hours of the day when the player opens the game
}

// Standard profiles the balance is tuned against.
func Profiles() []Profile {
	h := []float64{8, 13, 19, 23}
	return []Profile{
		{Name: "f2p", GemsPerDay: 150, IronMult: 1, PollenMult: 1, SessionMinutes: 10, SessionHours: h},
		{Name: "f2p+ads", GemsPerDay: 150, AdSummons: 3, IronMult: 1, PollenMult: 1, SessionMinutes: 10, SessionHours: h},
		{Name: "$15/month", GemsPerDay: 320, AdSummons: 3, OfflineBonus: 0.2, OfflineHours: 2, IronMult: 1.2, PollenMult: 1.5, SessionMinutes: 10, SessionHours: h},
		{Name: "whale", GemsPerDay: 3000, AdSummons: 3, OfflineBonus: 0.2, OfflineHours: 2, IronMult: 1.3, PollenMult: 2.5, SessionMinutes: 10, SessionHours: h},
	}
}

// DayLog is the state at the end of one simulated day.
type DayLog struct {
	Day       int
	Wave      int
	Land      int
	Harvests  int
	DPS       float64
	PowerMult float64
}

type state struct {
	b             Balance
	coins, seeds  float64
	heroes, crops []int
	wave, maxWave int
	shards, iron  float64
	pollen        float64
	gems          float64
	grains        float64
	harvests      int
	stuckSince    float64 // sim hours since last new wave
}

func newState(b Balance) *state {
	s := &state{b: b, heroes: make([]int, b.HeroSlotsMax), crops: make([]int, b.CropSlotsMax)}
	s.heroes[0], s.heroes[1], s.crops[0] = 1, 1, 1
	return s
}

func (s *state) land() int { return s.b.Land(s.wave + 1) }

func (s *state) accountMult() float64 {
	return s.b.ShardMult(s.shards) * s.b.GearMult(s.iron) * s.b.PrestigeMult(s.grains) * s.b.TalentMult(s.pollen)
}

func (s *state) dps() float64 {
	sum := 0.0
	for _, l := range s.heroes {
		sum += s.b.HeroBaseDps * s.b.LevelMult(l)
	}
	for _, l := range s.crops {
		sum += s.b.CropBaseDps * s.b.LevelMult(l)
	}
	return sum * s.accountMult()
}

// spend buys the upgrade with the best damage gain per coin until broke.
func (s *state) spend() {
	buy := func(levels []int, open int, base float64, wallet *float64) {
		for {
			best, bestRatio := -1, 0.0
			for i := 0; i < open; i++ {
				l := levels[i]
				gain := base * (s.b.LevelMult(l+1) - s.b.LevelMult(l))
				c := s.b.LevelCost(l + 1)
				if c > *wallet {
					continue
				}
				if r := gain / c; r > bestRatio {
					best, bestRatio = i, r
				}
			}
			if best < 0 {
				return
			}
			*wallet -= s.b.LevelCost(levels[best] + 1)
			levels[best]++
		}
	}
	buy(s.heroes, s.b.HeroSlots(s.land()), s.b.HeroBaseDps, &s.coins)
	buy(s.crops, s.b.CropSlots(s.land()), s.b.CropBaseDps, &s.seeds)
}

func (s *state) earn(coins float64) {
	s.coins += coins
	s.seeds += coins * s.b.SeedShare
}

// push clears waves for up to `seconds`; returns seconds left over.
func (s *state) push(seconds float64, now float64) float64 {
	for seconds >= s.b.WaveSeconds && s.wave < s.b.TotalWaves() {
		next := s.wave + 1
		if s.dps() < s.b.RequiredDPS(next) {
			break
		}
		s.wave = next
		if next > s.maxWave {
			s.maxWave = next
			s.stuckSince = now
		}
		s.earn(s.b.WaveCoins(next))
		seconds -= s.b.WaveSeconds
		s.spend()
	}
	return seconds
}

func (s *state) tryHarvest(now float64) {
	if s.maxWave < s.b.PrestigeFromWave || now-s.stuckSince < 24 {
		return
	}
	total := s.b.HarvestGrains(s.maxWave)
	if s.b.PrestigeMult(total) < s.b.PrestigeMult(s.grains)*s.b.PrestigeMinGain {
		return
	}
	s.grains = total
	s.harvests++
	// Great Harvest: levels and coins reset, the player restarts the current land.
	for i := range s.heroes {
		s.heroes[i] = 0
	}
	s.heroes[0], s.heroes[1] = 1, 1
	for i := range s.crops {
		s.crops[i] = 0
	}
	s.crops[0] = 1
	s.coins, s.seeds = 0, 0
	s.wave = (s.b.Land(s.maxWave) - 1) * s.b.WavesPerLand
	s.stuckSince = now
}

// Simulate plays `days` days of the profile and logs each day.
func Simulate(b Balance, p Profile, days int) []DayLog {
	s := newState(b)
	logs := make([]DayLog, 0, days)
	last := 0.0 // hour of the last session end
	for d := 0; d < days; d++ {
		s.gems += p.GemsPerDay
		s.shards += p.AdSummons * b.ShardsPerSummon * b.AdSummonShare // ad summons are basic ones
		s.iron += b.IronPerDay * p.IronMult
		s.pollen += b.PollenPerDay * p.PollenMult
		for _, h := range p.SessionHours {
			now := float64(d)*24 + h
			if now > last { // offline income
				hrs := math.Min(now-last, b.OfflineCap(s.land())+p.OfflineHours)
				s.earn(b.FarmCoinsPerSecond(s.wave) * 3600 * hrs * b.OfflineEfficiency * (1 + p.OfflineBonus))
			}
			for s.gems >= b.SummonGems {
				s.gems -= b.SummonGems
				s.shards += b.ShardsPerSummon
			}
			s.tryHarvest(now)
			s.spend()
			left := s.push(p.SessionMinutes*60, now)
			s.earn(b.FarmCoinsPerSecond(s.wave) * left) // auto-farm the rest of the session
			s.spend()
			s.push(left, now)
			last = now + p.SessionMinutes/60
		}
		logs = append(logs, DayLog{Day: d + 1, Wave: s.maxWave, Land: b.Land(max(s.maxWave, 1)), Harvests: s.harvests, DPS: s.dps(), PowerMult: s.accountMult()})
	}
	return logs
}

// FinishDay is the first day the profile clears the final wave, or 0.
func FinishDay(logs []DayLog, total int) int {
	for _, l := range logs {
		if l.Wave >= total {
			return l.Day
		}
	}
	return 0
}

// LandDays returns, per land, the first day the profile cleared it (0 = never).
func LandDays(b Balance, logs []DayLog) []int {
	out := make([]int, b.Lands)
	for _, l := range logs {
		for k := 1; k <= b.Lands; k++ {
			if out[k-1] == 0 && l.Wave >= k*b.WavesPerLand {
				out[k-1] = l.Day
			}
		}
	}
	return out
}

// Fit adjusts LandHP so the free profile clears each land on its target
// day: the first value is capped so the starting squad wins the first waves
// easily, then each next value is bisected for the land that ends there.
func Fit(b Balance, free Profile, days int) Balance {
	b.LandHP = make([]float64, b.Lands+1)
	start := 0.5 * b.StartDPS() * b.KillWindowSeconds / b.HPBase
	for i := range b.LandHP {
		b.LandHP[i] = start
	}
	for k := 0; k < b.Lands; k++ {
		base := b.LandHP[k]
		lo, hi := math.Log(base)-6, math.Log(base)+14
		set := func(x float64) {
			for j := k + 1; j <= b.Lands; j++ {
				b.LandHP[j] = x
			}
		}
		for i := 0; i < 40; i++ {
			mid := (lo + hi) / 2
			set(math.Exp(mid))
			d := LandDays(b, Simulate(b, free, days))[k]
			if d == 0 || d > b.LandTargetDays[k] {
				hi = mid
			} else {
				lo = mid
			}
		}
		set(math.Exp(lo))
	}
	return b
}
