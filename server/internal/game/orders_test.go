package game

import (
	"errors"
	"testing"
	"time"
)

func TestOrderBoard(t *testing.T) {
	cfg := mustConfig(t)
	f := NewFarm(cfg)
	now := time.Date(2026, 11, 26, 12, 0, 0, 0, time.UTC)
	f.FillOrders(cfg, now, 1)
	if len(f.Orders) != cfg.Orders.Slots {
		t.Fatalf("orders = %d", len(f.Orders))
	}
	o := f.Orders[1]
	if len(o.Items) == 0 || o.Coins <= 0 || o.XP <= 0 {
		t.Fatalf("empty order %+v", o)
	}
	if _, err := f.DeliverOrder(cfg, 1, now, 2); !errors.Is(err, ErrNoCrops) {
		t.Fatalf("deliver without crops err = %v", err)
	}
	f.Barn = map[string]int{}
	value := 0
	for k, n := range o.Items {
		f.Barn[k] = n
		c, _ := cfg.Crop(k)
		value += c.SellPrice * n
	}
	if o.Coins <= value {
		t.Fatalf("order pays %d, selling pays %d: orders must be better", o.Coins, value)
	}
	coins := f.Coins
	res, err := f.DeliverOrder(cfg, 1, now, 2)
	if err != nil || res.Coins != o.Coins || f.Coins != coins+o.Coins {
		t.Fatalf("deliver = %+v, %v", res, err)
	}
	if len(f.Orders) != cfg.Orders.Slots || len(f.Barn) != 0 {
		t.Fatalf("board not refilled or barn not emptied: %d %v", len(f.Orders), f.Barn)
	}
	if err := f.SkipOrder(cfg, 0, now); err != nil {
		t.Fatal(err)
	}
	if _, err := f.DeliverOrder(cfg, 0, now, 3); !errors.Is(err, ErrOrderNotReady) {
		t.Fatalf("deliver skipped err = %v", err)
	}
	f.FillOrders(cfg, now.Add(time.Duration(cfg.Orders.SkipSeconds)*time.Second), 4)
	if f.Orders[0].ReadyAt != nil || len(f.Orders[0].Items) == 0 {
		t.Fatalf("skipped slot did not refill: %+v", f.Orders[0])
	}
}
