package game

import (
	"errors"
	"time"
)

// Errors returned by farm actions. The API maps them to stable codes the
// client can show in any language.
var (
	ErrOutOfBounds   = errors.New("out_of_bounds")
	ErrNotTilled     = errors.New("not_tilled")
	ErrAlreadyTilled = errors.New("already_tilled")
	ErrOccupied      = errors.New("occupied")
	ErrEmpty         = errors.New("empty")
	ErrNotReady      = errors.New("not_ready")
	ErrUnknownCrop   = errors.New("unknown_crop")
	ErrNotEnough     = errors.New("not_enough_coins")
	ErrLocked        = errors.New("crop_locked")
	ErrNoCrops       = errors.New("not_enough_crops")
)

// Tile is one cell of the farm.
type Tile struct {
	Tilled    bool       `json:"tilled"`
	Crop      string     `json:"crop,omitempty"`
	PlantedAt *time.Time `json:"plantedAt,omitempty"`
}

// Farm is a player's farm state.
type Farm struct {
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Coins  int    `json:"coins"`
	XP     int    `json:"xp"`
	Tiles  []Tile `json:"tiles"` // row-major, index = y*Width + x

	// Barn holds harvested crops: they are sold for coins or built into scarecrows.
	Barn map[string]int `json:"barn,omitempty"`
	// Army is the scarecrows ready to fight; Queue is the workshop.
	Army  []Unit  `json:"army,omitempty"`
	Queue []Build `json:"queue,omitempty"`
	// RaidReadyAt holds each raid's cooldown end.
	RaidReadyAt map[string]time.Time `json:"raidReadyAt,omitempty"`
}

// NewFarm creates a starting farm from the config.
func NewFarm(cfg *Config) *Farm {
	f := &Farm{
		Width:  cfg.Farm.Width,
		Height: cfg.Farm.Height,
		Coins:  cfg.Farm.StartCoins,
		Tiles:  make([]Tile, cfg.Farm.Width*cfg.Farm.Height),
	}
	for y := 0; y < f.Height; y++ {
		for x := 0; x < f.Width; x++ {
			if cfg.Farm.StartTilled.Contains(x, y) {
				f.Tiles[y*f.Width+x].Tilled = true
			}
		}
	}
	return f
}

// Level is derived from XP: each level needs 10 more XP than the last.
func (f *Farm) Level() int {
	level, need, xp := 1, 10, f.XP
	for xp >= need {
		xp -= need
		level++
		need += 10
	}
	return level
}

func (f *Farm) tile(x, y int) (*Tile, error) {
	if x < 0 || y < 0 || x >= f.Width || y >= f.Height {
		return nil, ErrOutOfBounds
	}
	return &f.Tiles[y*f.Width+x], nil
}

// Till turns grass into soil.
func (f *Farm) Till(cfg *Config, x, y int) error {
	t, err := f.tile(x, y)
	if err != nil {
		return err
	}
	if t.Tilled {
		return ErrAlreadyTilled
	}
	if f.Coins < cfg.Farm.TillCost {
		return ErrNotEnough
	}
	f.Coins -= cfg.Farm.TillCost
	t.Tilled = true
	return nil
}

// Plant puts a seed into tilled, empty soil.
func (f *Farm) Plant(cfg *Config, x, y int, cropID string, now time.Time) error {
	t, err := f.tile(x, y)
	if err != nil {
		return err
	}
	crop, ok := cfg.Crop(cropID)
	if !ok {
		return ErrUnknownCrop
	}
	if f.Level() < crop.UnlockLevel {
		return ErrLocked
	}
	if !t.Tilled {
		return ErrNotTilled
	}
	if t.Crop != "" {
		return ErrOccupied
	}
	if f.Coins < crop.SeedCost {
		return ErrNotEnough
	}
	f.Coins -= crop.SeedCost
	planted := now.UTC()
	t.Crop = cropID
	t.PlantedAt = &planted
	return nil
}

// HarvestResult tells the client what to celebrate. The crop goes to the barn.
type HarvestResult struct {
	Crop    string `json:"crop"`
	Count   int    `json:"count"`
	XP      int    `json:"xp"`
	LevelUp bool   `json:"levelUp"`
}

// Harvest collects a ripe crop.
func (f *Farm) Harvest(cfg *Config, x, y int, now time.Time) (HarvestResult, error) {
	t, err := f.tile(x, y)
	if err != nil {
		return HarvestResult{}, err
	}
	if t.Crop == "" || t.PlantedAt == nil {
		return HarvestResult{}, ErrEmpty
	}
	crop, ok := cfg.Crop(t.Crop)
	if !ok {
		return HarvestResult{}, ErrUnknownCrop
	}
	if Progress(crop, *t.PlantedAt, now) < 1 {
		return HarvestResult{}, ErrNotReady
	}
	before := f.Level()
	f.addCrops(crop.ID, 1)
	f.XP += crop.XP
	t.Crop = ""
	t.PlantedAt = nil
	return HarvestResult{
		Crop:    crop.ID,
		Count:   1,
		XP:      crop.XP,
		LevelUp: f.Level() > before,
	}, nil
}

func (f *Farm) addCrops(id string, n int) {
	if f.Barn == nil {
		f.Barn = map[string]int{}
	}
	f.Barn[id] += n
	if f.Barn[id] <= 0 {
		delete(f.Barn, id)
	}
}

// Sell turns crops from the barn into coins.
func (f *Farm) Sell(cfg *Config, cropID string, count int) (int, error) {
	crop, ok := cfg.Crop(cropID)
	if !ok {
		return 0, ErrUnknownCrop
	}
	if count <= 0 || f.Barn[cropID] < count {
		return 0, ErrNoCrops
	}
	f.addCrops(cropID, -count)
	coins := crop.SellPrice * count
	f.Coins += coins
	return coins, nil
}

// Progress is how far a crop has grown, from 0 to 1.
func Progress(crop Crop, plantedAt, now time.Time) float64 {
	elapsed := now.Sub(plantedAt).Seconds()
	if elapsed <= 0 {
		return 0
	}
	p := elapsed / float64(crop.GrowSeconds)
	if p > 1 {
		return 1
	}
	return p
}
