// Package defense holds the Farm Defense balance formulas shared by the
// balance simulator, the server (offline-progress checks) and, through
// balance.json, the iOS client.
package defense

import (
	_ "embed"
	"encoding/json"
	"math"
)

//go:embed balance.json
var balanceJSON []byte

// Balance is the tunable economy. Every formula below reads only from it.
type Balance struct {
	Lands              int     `json:"lands"`
	WavesPerLand       int     `json:"wavesPerLand"`
	WaveSeconds        float64 `json:"waveSeconds"`
	KillWindowSeconds  float64 `json:"killWindowSeconds"`
	HPBase             float64 `json:"hpBase"`
	HPGrowth           float64 `json:"hpGrowth"`
	BossEvery          int     `json:"bossEvery"`
	BossMult           float64 `json:"bossMult"`
	LandBossMult       float64 `json:"landBossMult"`
	RewardBase         float64 `json:"rewardBase"`
	RewardGrowth       float64 `json:"rewardGrowth"`
	SeedShare          float64 `json:"seedShare"`
	OfflineEfficiency  float64 `json:"offlineEfficiency"`
	OfflineCapHours    float64 `json:"offlineCapHours"`
	OfflineCapPerLand  float64 `json:"offlineCapPerLand"`
	OfflineCapMaxHours float64 `json:"offlineCapMaxHours"`
	HeroBaseDps        float64 `json:"heroBaseDps"`
	CropBaseDps        float64 `json:"cropBaseDps"`
	LevelCostBase      float64 `json:"levelCostBase"`
	LevelCostGrowth    float64 `json:"levelCostGrowth"`
	MilestoneEvery     int     `json:"milestoneEvery"`
	MilestoneMult      float64 `json:"milestoneMult"`
	HeroSlotsStart     int     `json:"heroSlotsStart"`
	HeroSlotsMax       int     `json:"heroSlotsMax"`
	CropSlotsStart     int     `json:"cropSlotsStart"`
	CropSlotsPerLand   int     `json:"cropSlotsPerLand"`
	CropSlotsMax       int     `json:"cropSlotsMax"`
	SummonGems         float64 `json:"summonGems"`
	ShardsPerSummon    float64 `json:"shardsPerSummon"`
	AdSummonShare      float64 `json:"adSummonShare"`
	ShardPowerK        float64 `json:"shardPowerK"`
	ShardPowerExp      float64 `json:"shardPowerExp"`
	PrestigeFromWave   int     `json:"prestigeFromWave"`
	PrestigeGrainK     float64 `json:"prestigeGrainK"`
	PrestigeGrainExp   float64 `json:"prestigeGrainExp"`
	PrestigePerGrain   float64 `json:"prestigePerGrain"`
	PrestigeMinGain    float64 `json:"prestigeMinGain"`
	IronPerDay         float64 `json:"ironPerDay"`
	GearK              float64 `json:"gearK"`
	GearExp            float64 `json:"gearExp"`
	PollenPerDay       float64 `json:"pollenPerDay"`
	TalentK            float64 `json:"talentK"`
	TalentExp          float64 `json:"talentExp"`
	// LandHP is a per-land HP factor fitted by `balance-sim -fit` so that a
	// free player finishes each land on the target day.
	LandHP []float64 `json:"landHP"`
	// LandTargetDays is the day a free player should finish each land.
	LandTargetDays []int `json:"landTargetDays"`
}

// Parse reads a balance from JSON.
func Parse(data []byte) (Balance, error) {
	var b Balance
	err := json.Unmarshal(data, &b)
	return b, err
}

// Default returns the shipped balance.
func Default() Balance {
	var b Balance
	if err := json.Unmarshal(balanceJSON, &b); err != nil {
		panic(err)
	}
	return b
}

// TotalWaves is the last wave of the last land.
func (b Balance) TotalWaves() int { return b.Lands * b.WavesPerLand }

// Land returns the 1-based land of a 1-based global wave.
func (b Balance) Land(wave int) int {
	if wave < 1 {
		return 1
	}
	return (wave-1)/b.WavesPerLand + 1
}

// WaveHP is the total enemy HP of a wave, bosses included.
func (b Balance) WaveHP(wave int) float64 {
	hp := b.HPBase * math.Pow(b.HPGrowth, float64(wave-1))
	if l := b.Land(wave); l <= len(b.LandHP) {
		hp *= b.LandHP[l-1]
	}
	inLand := (wave-1)%b.WavesPerLand + 1
	switch {
	case inLand == b.WavesPerLand || inLand == b.WavesPerLand/2:
		hp *= b.LandBossMult
	case inLand%b.BossEvery == 0:
		hp *= b.BossMult
	}
	return hp
}

// RequiredDPS is the damage per second needed to clear a wave before it
// reaches the fence.
func (b Balance) RequiredDPS(wave int) float64 { return b.WaveHP(wave) / b.KillWindowSeconds }

// WaveCoins is the coin reward for clearing a wave once.
func (b Balance) WaveCoins(wave int) float64 {
	return b.RewardBase * math.Pow(b.RewardGrowth, float64(wave-1))
}

// FarmCoinsPerSecond is the income while replaying the highest cleared wave.
func (b Balance) FarmCoinsPerSecond(wave int) float64 {
	if wave < 1 {
		wave = 1
	}
	return b.WaveCoins(wave) / b.WaveSeconds
}

// LevelCost is the price of raising a hero or crop from level to level+1.
func (b Balance) LevelCost(level int) float64 {
	return b.LevelCostBase * math.Pow(b.LevelCostGrowth, float64(level-1))
}

// LevelMult is the damage multiplier of a level: linear growth plus a
// doubling every milestone (25, 50, 75...).
func (b Balance) LevelMult(level int) float64 {
	if level < 1 {
		return 0
	}
	return float64(level) * math.Pow(b.MilestoneMult, float64(level/b.MilestoneEvery))
}

// ShardMult is the account-wide multiplier from scarecrow stars. It has
// diminishing returns so paying speeds players up without breaking the game.
func (b Balance) ShardMult(shards float64) float64 {
	return 1 + b.ShardPowerK*math.Pow(shards, b.ShardPowerExp)
}

// GearMult is the multiplier from equipment forged with iron.
func (b Balance) GearMult(iron float64) float64 {
	return math.Pow(1+iron/b.GearK, b.GearExp)
}

// HarvestGrains is how many Harvest grains a Great Harvest at maxWave yields
// in total (the player receives the difference to what they already own).
func (b Balance) HarvestGrains(maxWave int) float64 {
	if maxWave < b.PrestigeFromWave {
		return 0
	}
	return math.Floor(b.PrestigeGrainK * math.Pow(float64(maxWave)/100, b.PrestigeGrainExp))
}

// PrestigeMult is the permanent multiplier from Harvest grains.
func (b Balance) PrestigeMult(grains float64) float64 { return 1 + b.PrestigePerGrain*grains }

// HeroSlots and CropSlots open with lands.
func (b Balance) HeroSlots(land int) int { return min(b.HeroSlotsMax, b.HeroSlotsStart+land-1) }
func (b Balance) CropSlots(land int) int {
	return min(b.CropSlotsMax, b.CropSlotsStart+b.CropSlotsPerLand*(land-1))
}

// OfflineCap is how many hours of offline income the Barn holds; the Barn
// is upgraded along the lands.
func (b Balance) OfflineCap(land int) float64 {
	return math.Min(b.OfflineCapMaxHours, b.OfflineCapHours+b.OfflineCapPerLand*float64(land-1))
}

// TalentMult is the multiplier from talents and buildings, bought with
// pollen that every player earns daily; it keeps a stuck player moving.
func (b Balance) TalentMult(pollen float64) float64 {
	return 1 + b.TalentK*math.Pow(pollen, b.TalentExp)
}
