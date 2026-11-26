package game

import (
	"errors"
	"math"
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
	ErrNotOwned      = errors.New("not_owned")
	ErrOwned         = errors.New("already_owned")
	ErrNotAdjacent   = errors.New("not_adjacent")
)

// Tile is one cell of the farm.
type Tile struct {
	Tilled    bool       `json:"tilled"`
	Crop      string     `json:"crop,omitempty"`
	PlantedAt *time.Time `json:"plantedAt,omitempty"`
	// Grow is the growth time fixed at planting (with the well bonus);
	// 0 in old saves means the crop's own time.
	Grow int `json:"grow,omitempty"`
}

// GrowSeconds is how long the crop on this tile takes in total.
func (t *Tile) GrowSeconds(crop Crop) int {
	if t.Grow > 0 {
		return t.Grow
	}
	return crop.GrowSeconds
}

// Farm is a player's farm state.
type Farm struct {
	Width  int    `json:"width"`
	Height int    `json:"height"`
	Coins  int    `json:"coins"`
	XP     int    `json:"xp"`
	Tiles  []Tile `json:"tiles"` // row-major, index = y*Width + x
	// Plots marks owned land plots, row-major over the plot grid.
	Plots []bool `json:"plots,omitempty"`

	// Barn holds harvested crops: they are sold for coins or built into scarecrows.
	Barn map[string]int `json:"barn,omitempty"`
	// Army is the scarecrows ready to fight; Queue is the workshop.
	Army  []Unit  `json:"army,omitempty"`
	Queue []Build `json:"queue,omitempty"`
	// Orders is the order board.
	Orders []Order `json:"orders,omitempty"`
	// RaidReadyAt holds each raid's cooldown end.
	RaidReadyAt map[string]time.Time `json:"raidReadyAt,omitempty"`
	// Items is the storage (Склад): speedups and chests by item id.
	Items map[string]int `json:"items,omitempty"`
	// Manor is the main building level (0 in old saves means 1) and the
	// end of its running upgrade, if any.
	Manor        int        `json:"manor,omitempty"`
	ManorReadyAt *time.Time `json:"manorReadyAt,omitempty"`
	// Buildings holds working building levels; Work is the one under
	// construction (the manor and buildings share one builder).
	Buildings map[string]int `json:"buildings,omitempty"`
	Work      *Work          `json:"work,omitempty"`
	// Cleared lists tile indices whose rock or dead tree was removed.
	Cleared []int `json:"cleared,omitempty"`
	// Stats counts lifetime actions ("harvest", "harvest:<crop>", ...) for
	// quests; QuestsDone lists claimed quest ids.
	Stats      map[string]int `json:"stats,omitempty"`
	QuestsDone []string       `json:"questsDone,omitempty"`
}

// NewFarm creates a starting farm from the config.
func NewFarm(cfg *Config) *Farm {
	f := &Farm{
		Width:  cfg.Farm.Width,
		Height: cfg.Farm.Height,
		Coins:  cfg.Farm.StartCoins,
		Tiles:  make([]Tile, cfg.Farm.Width*cfg.Farm.Height),
		Manor:  1,
	}
	for y := 0; y < f.Height; y++ {
		for x := 0; x < f.Width; x++ {
			if cfg.Farm.StartTilled.Contains(x, y) {
				f.Tiles[y*f.Width+x].Tilled = true
			}
		}
	}
	f.EnsurePlots(cfg)
	f.Grant(cfg.Items.StartItems)
	return f
}

// EnsurePlots gives farms saved before land plots existed their start plots.
func (f *Farm) EnsurePlots(cfg *Config) {
	n := cfg.Farm.PlotsX() * cfg.Farm.PlotsY()
	if len(f.Plots) == n {
		return
	}
	f.Plots = make([]bool, n)
	for _, p := range cfg.Farm.StartPlots {
		f.Plots[p[1]*cfg.Farm.PlotsX()+p[0]] = true
	}
}

// Owns reports whether the tile (x, y) lies on an owned plot.
func (f *Farm) Owns(cfg *Config, x, y int) bool {
	if x < 0 || y < 0 || x >= f.Width || y >= f.Height {
		return false
	}
	ps := cfg.Farm.PlotSize
	i := (y/ps)*cfg.Farm.PlotsX() + x/ps
	return i < len(f.Plots) && f.Plots[i]
}

// PlotsBought counts plots bought beyond the start ones.
func (f *Farm) PlotsBought(cfg *Config) int {
	n := 0
	for _, o := range f.Plots {
		if o {
			n++
		}
	}
	return n - len(cfg.Farm.StartPlots)
}

// PlotPrice is the coin cost and level needed for the next plot.
func (f *Farm) PlotPrice(cfg *Config) (coins, level int) {
	b := f.PlotsBought(cfg)
	coins = int(math.Round(float64(cfg.Farm.PlotBaseCost) * math.Pow(cfg.Farm.PlotCostGrowth, float64(b))))
	return coins, 1 + (b+1)/cfg.Farm.PlotLevelStep
}

// CanBuyPlot reports whether plot (px, py) is for sale: not owned and next to owned land.
func (f *Farm) CanBuyPlot(cfg *Config, px, py int) error {
	w, h := cfg.Farm.PlotsX(), cfg.Farm.PlotsY()
	if px < 0 || py < 0 || px >= w || py >= h {
		return ErrOutOfBounds
	}
	if f.Plots[py*w+px] {
		return ErrOwned
	}
	for _, d := range [][2]int{{1, 0}, {-1, 0}, {0, 1}, {0, -1}} {
		nx, ny := px+d[0], py+d[1]
		if nx >= 0 && ny >= 0 && nx < w && ny < h && f.Plots[ny*w+nx] {
			return nil
		}
	}
	return ErrNotAdjacent
}

// BuyPlot buys a land plot next to owned land.
func (f *Farm) BuyPlot(cfg *Config, px, py int) error {
	f.EnsurePlots(cfg)
	if err := f.CanBuyPlot(cfg, px, py); err != nil {
		return err
	}
	coins, level := f.PlotPrice(cfg)
	if f.Level() < level {
		return ErrLocked
	}
	if f.Coins < coins {
		return ErrNotEnough
	}
	f.Coins -= coins
	f.Plots[py*cfg.Farm.PlotsX()+px] = true
	f.count("plot", 1)
	return nil
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
	f.EnsurePlots(cfg)
	if !f.Owns(cfg, x, y) {
		return ErrNotOwned
	}
	if f.ObstacleAt(cfg, x, y) != "" {
		return ErrObstacle
	}
	if f.Coins < cfg.Farm.TillCost {
		return ErrNotEnough
	}
	f.Coins -= cfg.Farm.TillCost
	t.Tilled = true
	f.count("till", 1)
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
	t.Grow = 0
	if g := f.faster(cfg, EffectGrow, crop.GrowSeconds); g != crop.GrowSeconds {
		t.Grow = g
	}
	f.count("plant", 1)
	return nil
}

// HarvestResult tells the client what to celebrate. The crop goes to the barn.
type HarvestResult struct {
	Crop    string `json:"crop"`
	Count   int    `json:"count"`
	XP      int    `json:"xp"`
	LevelUp bool   `json:"levelUp"`
	// Items are level-up rewards put into the storage.
	Items map[string]int `json:"items,omitempty"`
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
	if Progress(t.GrowSeconds(crop), *t.PlantedAt, now) < 1 {
		return HarvestResult{}, ErrNotReady
	}
	f.addCrops(crop.ID, 1)
	f.count("harvest", 1)
	f.count("harvest:"+crop.ID, 1)
	up, items := f.gainXP(cfg, crop.XP)
	t.Crop = ""
	t.PlantedAt = nil
	t.Grow = 0
	return HarvestResult{
		Crop:    crop.ID,
		Count:   1,
		XP:      crop.XP,
		LevelUp: up,
		Items:   items,
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
	coins := f.more(cfg, EffectSell, crop.SellPrice*count)
	f.Coins += coins
	f.count("sell", count)
	return coins, nil
}

// Progress is how far a crop has grown, from 0 to 1.
func Progress(growSeconds int, plantedAt, now time.Time) float64 {
	elapsed := now.Sub(plantedAt).Seconds()
	if elapsed <= 0 {
		return 0
	}
	p := elapsed / float64(max(1, growSeconds))
	if p > 1 {
		return 1
	}
	return p
}
