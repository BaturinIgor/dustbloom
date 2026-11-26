// Package game holds the authoritative farm rules. The client mirrors these
// rules for instant feedback, but the server's answer always wins.
package game

import (
	_ "embed"
	"encoding/json"
	"fmt"
)

//go:embed data/crops.json
var defaultConfigJSON []byte

// Rect is an axis-aligned area of tiles.
type Rect struct {
	X      int `json:"x"`
	Y      int `json:"y"`
	Width  int `json:"width"`
	Height int `json:"height"`
}

// Contains reports whether the tile (x, y) lies inside the rect.
func (r Rect) Contains(x, y int) bool {
	return x >= r.X && y >= r.Y && x < r.X+r.Width && y < r.Y+r.Height
}

// FarmConfig describes a new player's farm.
type FarmConfig struct {
	Width       int  `json:"width"`
	Height      int  `json:"height"`
	StartCoins  int  `json:"startCoins"`
	StartTilled Rect `json:"startTilled"`
	TillCost    int  `json:"tillCost"`

	// Land is sold in square plots. The player starts with StartPlots and
	// buys neighbours; each plot costs PlotBaseCost * PlotCostGrowth^bought
	// and needs level 1 + bought/PlotLevelStep.
	PlotSize       int      `json:"plotSize"`
	StartPlots     [][2]int `json:"startPlots"`
	PlotBaseCost   int      `json:"plotBaseCost"`
	PlotCostGrowth float64  `json:"plotCostGrowth"`
	PlotLevelStep  int      `json:"plotLevelStep"`
}

// PlotsX and PlotsY are the plot grid size.
func (f FarmConfig) PlotsX() int { return f.Width / f.PlotSize }
func (f FarmConfig) PlotsY() int { return f.Height / f.PlotSize }

// Crop is one plantable crop type.
type Crop struct {
	ID          string            `json:"id"`
	Name        map[string]string `json:"name"`
	GrowSeconds int               `json:"growSeconds"`
	SeedCost    int               `json:"seedCost"`
	SellPrice   int               `json:"sellPrice"`
	XP          int               `json:"xp"`
	UnlockLevel int               `json:"unlockLevel"`
}

// ArmyConfig limits how many scarecrows a player can field and queue.
type ArmyConfig struct {
	BaseSlots     int `json:"baseSlots"`
	SlotsPerLevel int `json:"slotsPerLevel"`
	MaxSlots      int `json:"maxSlots"`
	QueueSize     int `json:"queueSize"`
}

// Scarecrow is a buildable combat unit made from crops.
type Scarecrow struct {
	ID           string            `json:"id"`
	Name         map[string]string `json:"name"`
	Cost         map[string]int    `json:"cost"` // crop id -> count from the barn
	Coins        int               `json:"coins"`
	BuildSeconds int               `json:"buildSeconds"`
	HP           int               `json:"hp"`
	Attack       int               `json:"attack"`
	UnlockLevel  int               `json:"unlockLevel"`
}

// Enemy is one fighter in a raid target.
type Enemy struct {
	HP     int `json:"hp"`
	Attack int `json:"attack"`
}

// Raid is a PvE camp in the wasteland the army can attack.
type Raid struct {
	ID              string            `json:"id"`
	Name            map[string]string `json:"name"`
	Enemies         []Enemy           `json:"enemies"`
	RewardCoins     int               `json:"rewardCoins"`
	RewardXP        int               `json:"rewardXp"`
	CooldownSeconds int               `json:"cooldownSeconds"`
	UnlockLevel     int               `json:"unlockLevel"`
	// Drops are storage items granted on a win.
	Drops map[string]int `json:"drops,omitempty"`
}

// Config is the full game balance file shared with the client.
type Config struct {
	Version    int                 `json:"version"`
	Farm       FarmConfig          `json:"farm"`
	Crops      []Crop              `json:"crops"`
	Army       ArmyConfig          `json:"army"`
	Scarecrows []Scarecrow         `json:"scarecrows"`
	Raids      []Raid              `json:"raids"`
	Orders     OrderConfig         `json:"orders"`
	Items      ItemsConfig         `json:"items"`
	Manor      ManorConfig         `json:"manor"`
	Buildings  BuildingsConfig     `json:"buildings"`
	Obstacles  map[string]Obstacle `json:"obstacles"`

	cropsByID     map[string]Crop
	scByID        map[string]Scarecrow
	raidsByID     map[string]Raid
	speedups      map[string]Speedup
	chestsByID    map[string]Chest
	buildingsByID map[string]BuildingType
}

// DefaultConfig parses the embedded balance file.
func DefaultConfig() (*Config, error) {
	return ParseConfig(defaultConfigJSON)
}

// RawDefaultConfig returns the embedded balance file as-is, for /v1/config.
func RawDefaultConfig() []byte {
	return defaultConfigJSON
}

// ParseConfig parses and validates a balance file.
func ParseConfig(data []byte) (*Config, error) {
	var c Config
	if err := json.Unmarshal(data, &c); err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	if c.Farm.Width <= 0 || c.Farm.Height <= 0 {
		return nil, fmt.Errorf("config: farm size must be positive")
	}
	if c.Farm.PlotSize <= 0 || c.Farm.Width%c.Farm.PlotSize != 0 || c.Farm.Height%c.Farm.PlotSize != 0 {
		return nil, fmt.Errorf("config: farm size must be a multiple of plotSize")
	}
	if c.Farm.PlotLevelStep <= 0 {
		c.Farm.PlotLevelStep = 1
	}
	c.cropsByID = make(map[string]Crop, len(c.Crops))
	for _, cr := range c.Crops {
		if cr.ID == "" {
			return nil, fmt.Errorf("config: crop without id")
		}
		if cr.GrowSeconds <= 0 {
			return nil, fmt.Errorf("config: crop %q needs growSeconds > 0", cr.ID)
		}
		if _, dup := c.cropsByID[cr.ID]; dup {
			return nil, fmt.Errorf("config: duplicate crop %q", cr.ID)
		}
		c.cropsByID[cr.ID] = cr
	}
	c.scByID = make(map[string]Scarecrow, len(c.Scarecrows))
	for _, sc := range c.Scarecrows {
		if sc.ID == "" || sc.HP <= 0 || sc.Attack <= 0 || sc.BuildSeconds <= 0 {
			return nil, fmt.Errorf("config: scarecrow %q needs id, hp, attack and buildSeconds", sc.ID)
		}
		for crop, n := range sc.Cost {
			if _, ok := c.cropsByID[crop]; !ok || n <= 0 {
				return nil, fmt.Errorf("config: scarecrow %q has bad cost %q", sc.ID, crop)
			}
		}
		if _, dup := c.scByID[sc.ID]; dup {
			return nil, fmt.Errorf("config: duplicate scarecrow %q", sc.ID)
		}
		c.scByID[sc.ID] = sc
	}
	c.raidsByID = make(map[string]Raid, len(c.Raids))
	for _, r := range c.Raids {
		if r.ID == "" || len(r.Enemies) == 0 {
			return nil, fmt.Errorf("config: raid %q needs id and enemies", r.ID)
		}
		if _, dup := c.raidsByID[r.ID]; dup {
			return nil, fmt.Errorf("config: duplicate raid %q", r.ID)
		}
		c.raidsByID[r.ID] = r
	}
	if err := c.indexItems(); err != nil {
		return nil, err
	}
	if err := c.validateManor(); err != nil {
		return nil, err
	}
	if err := c.indexBuildings(); err != nil {
		return nil, err
	}
	return &c, nil
}

// Crop looks up a crop by id.
func (c *Config) Crop(id string) (Crop, bool) {
	cr, ok := c.cropsByID[id]
	return cr, ok
}

// Scarecrow looks up a scarecrow type by id.
func (c *Config) Scarecrow(id string) (Scarecrow, bool) {
	sc, ok := c.scByID[id]
	return sc, ok
}

// Raid looks up a raid target by id.
func (c *Config) Raid(id string) (Raid, bool) {
	r, ok := c.raidsByID[id]
	return r, ok
}
