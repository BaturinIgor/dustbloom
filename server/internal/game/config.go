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
}

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

// Config is the full game balance file shared with the client.
type Config struct {
	Version int        `json:"version"`
	Farm    FarmConfig `json:"farm"`
	Crops   []Crop     `json:"crops"`

	cropsByID map[string]Crop
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
	return &c, nil
}

// Crop looks up a crop by id.
func (c *Config) Crop(id string) (Crop, bool) {
	cr, ok := c.cropsByID[id]
	return cr, ok
}
