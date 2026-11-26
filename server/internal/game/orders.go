package game

import (
	"errors"
	"math/rand/v2"
	"sort"
	"time"
)

// Errors returned by the order board.
var (
	ErrNoOrder       = errors.New("no_order")
	ErrOrderNotReady = errors.New("order_not_ready")
)

// OrderConfig shapes the order board: how many slots, how generous, how long
// a skipped order takes to come back.
type OrderConfig struct {
	Slots         int     `json:"slots"`
	RewardFactor  float64 `json:"rewardFactor"` // coins = sell value * factor
	XPPerCoin     float64 `json:"xpPerCoin"`
	SkipSeconds   int     `json:"skipSeconds"`
	MaxItemTypes  int     `json:"maxItemTypes"`
	BaseCount     int     `json:"baseCount"`     // items for a 30 s crop at level 1
	CountPerLevel float64 `json:"countPerLevel"` // extra share per level
}

// Order is one request on the board: deliver crops, get coins and XP.
type Order struct {
	Items   map[string]int `json:"items"`
	Coins   int            `json:"coins"`
	XP      int            `json:"xp"`
	ReadyAt *time.Time     `json:"readyAt,omitempty"` // set while a skipped slot refills
}

// OrderResult is what delivering an order paid.
type OrderResult struct {
	Coins   int            `json:"coins"`
	XP      int            `json:"xp"`
	LevelUp bool           `json:"levelUp"`
	Items   map[string]int `json:"items,omitempty"`
}

// FillOrders tops the board up to its slot count and refreshes skipped slots
// whose wait is over. Seed makes the server and tests reproducible.
func (f *Farm) FillOrders(cfg *Config, now time.Time, seed uint64) {
	rng := rand.New(rand.NewPCG(seed, uint64(len(f.Orders))+uint64(f.XP)))
	for len(f.Orders) < cfg.Orders.Slots {
		f.Orders = append(f.Orders, f.newOrder(cfg, rng))
	}
	for i := range f.Orders {
		if r := f.Orders[i].ReadyAt; r != nil && !now.Before(*r) {
			f.Orders[i] = f.newOrder(cfg, rng)
		}
	}
}

func (f *Farm) newOrder(cfg *Config, rng *rand.Rand) Order {
	var pool []Crop
	for _, c := range cfg.Crops {
		if c.UnlockLevel <= f.Level() {
			pool = append(pool, c)
		}
	}
	rng.Shuffle(len(pool), func(i, j int) { pool[i], pool[j] = pool[j], pool[i] })
	types := 1 + rng.IntN(max(1, min(cfg.Orders.MaxItemTypes, len(pool))))
	o := Order{Items: map[string]int{}}
	value := 0
	for _, c := range pool[:types] {
		// slow crops are asked for in smaller numbers
		base := float64(cfg.Orders.BaseCount) * 30 / float64(c.GrowSeconds)
		n := max(1, int(base*(1+cfg.Orders.CountPerLevel*float64(f.Level()-1))*(0.7+0.6*rng.Float64())+0.5))
		o.Items[c.ID] = n
		value += n * c.SellPrice
	}
	o.Coins = f.more(cfg, EffectOrderReward, int(float64(value)*cfg.Orders.RewardFactor+0.5))
	o.XP = max(1, int(float64(o.Coins)*cfg.Orders.XPPerCoin+0.5))
	return o
}

// DeliverOrder hands over the crops of order i for its reward; a new order
// takes its place at once.
func (f *Farm) DeliverOrder(cfg *Config, i int, now time.Time, seed uint64) (OrderResult, error) {
	if i < 0 || i >= len(f.Orders) {
		return OrderResult{}, ErrNoOrder
	}
	o := f.Orders[i]
	if o.ReadyAt != nil {
		return OrderResult{}, ErrOrderNotReady
	}
	keys := make([]string, 0, len(o.Items))
	for k := range o.Items {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if f.Barn[k] < o.Items[k] {
			return OrderResult{}, ErrNoCrops
		}
	}
	for _, k := range keys {
		f.addCrops(k, -o.Items[k])
	}
	f.Coins += o.Coins
	f.count("order", 1)
	up, items := f.gainXP(cfg, o.XP)
	f.Orders = append(f.Orders[:i], f.Orders[i+1:]...)
	f.FillOrders(cfg, now, seed)
	// keep the new order in the slot the old one left
	last := f.Orders[len(f.Orders)-1]
	copy(f.Orders[i+1:], f.Orders[i:len(f.Orders)-1])
	f.Orders[i] = last
	return OrderResult{Coins: o.Coins, XP: o.XP, LevelUp: up, Items: items}, nil
}

// SkipOrder throws order i away; the slot refills after SkipSeconds.
func (f *Farm) SkipOrder(cfg *Config, i int, now time.Time) error {
	if i < 0 || i >= len(f.Orders) {
		return ErrNoOrder
	}
	if f.Orders[i].ReadyAt != nil {
		return ErrOrderNotReady
	}
	t := now.UTC().Add(time.Duration(cfg.Orders.SkipSeconds) * time.Second)
	f.Orders[i] = Order{Items: map[string]int{}, ReadyAt: &t}
	return nil
}
