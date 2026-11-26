package game

import (
	"errors"
	"slices"
)

var (
	ErrObstacle   = errors.New("obstacle")
	ErrNoObstacle = errors.New("no_obstacle")
)

// Obstacle is what clearing one rock or dead tree costs and gives.
type Obstacle struct {
	Coins int `json:"coins"`
	XP    int `json:"xp"`
}

// ObstacleAt is the rock or dead tree standing on (x, y), or "" if there is
// none or it was cleared. The layout is fixed by a hash of the position and
// keeps 5 tiles around the starting beds free; the client draws the same
// ones (FarmScene+Wasteland.swift wildProp).
func (f *Farm) ObstacleAt(cfg *Config, x, y int) string {
	if x < 0 || y < 0 || x >= f.Width || y >= f.Height || slices.Contains(f.Cleared, y*f.Width+x) {
		return ""
	}
	return obstacleKind(cfg, x, y)
}

func obstacleKind(cfg *Config, x, y int) string {
	s := cfg.Farm.StartTilled
	dx := max(s.X-x, 0, x-(s.X+s.Width-1))
	dy := max(s.Y-y, 0, y-(s.Y+s.Height-1))
	if max(dx, dy) < 5 {
		return ""
	}
	switch h := x*31 + y*17; (max(h, -h)) % 23 {
	case 0:
		return "dead_tree"
	case 7, 15:
		return "rock"
	}
	return ""
}

// ClearResult is what clearing gave.
type ClearResult struct {
	Kind    string         `json:"kind"`
	XP      int            `json:"xp"`
	LevelUp bool           `json:"levelUp"`
	Items   map[string]int `json:"items,omitempty"`
}

// Clear removes the rock or dead tree on an owned tile for coins and XP.
func (f *Farm) Clear(cfg *Config, x, y int) (ClearResult, error) {
	if _, err := f.tile(x, y); err != nil {
		return ClearResult{}, err
	}
	kind := f.ObstacleAt(cfg, x, y)
	if kind == "" {
		return ClearResult{}, ErrNoObstacle
	}
	f.EnsurePlots(cfg)
	if !f.Owns(cfg, x, y) {
		return ClearResult{}, ErrNotOwned
	}
	o := cfg.Obstacles[kind]
	if f.Coins < o.Coins {
		return ClearResult{}, ErrNotEnough
	}
	f.Coins -= o.Coins
	f.Cleared = append(f.Cleared, y*f.Width+x)
	f.count("clear", 1)
	res := ClearResult{Kind: kind, XP: o.XP}
	res.LevelUp, res.Items = f.gainXP(cfg, o.XP)
	return res, nil
}
