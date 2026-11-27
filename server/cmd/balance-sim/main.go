// Command balance-sim plays the Farm Defense economy for several player
// profiles and prints how far each gets by day.
package main

import (
	"flag"
	"fmt"
	"os"

	"github.com/BaturinIgor/dustbloom/server/internal/defense"
)

func main() {
	days := flag.Int("days", 240, "days to simulate")
	hp := flag.Float64("hp", 0, "override hpGrowth")
	target := flag.Int("calibrate", 0, "find hpGrowth so f2p finishes on this day")
	fit := flag.Bool("fit", false, "fit landHP to landTargetDays for the free profile")
	cfg := flag.String("config", "", "balance JSON to use instead of the embedded one")
	flag.Parse()
	b := defense.Default()
	if *cfg != "" {
		data, err := os.ReadFile(*cfg)
		if err != nil {
			panic(err)
		}
		if b, err = defense.Parse(data); err != nil {
			panic(err)
		}
	}
	if *hp > 0 {
		b.HPGrowth = *hp
	}
	if *target > 0 {
		lo, hi := 1.0, 1.2
		for i := 0; i < 40; i++ {
			b.HPGrowth = (lo + hi) / 2
			d := defense.FinishDay(defense.Simulate(b, defense.Profiles()[0], *days), b.TotalWaves())
			if d == 0 || d > *target {
				hi = b.HPGrowth
			} else {
				lo = b.HPGrowth
			}
		}
		fmt.Printf("hpGrowth=%.6f\n", b.HPGrowth)
	}
	if *fit {
		b = defense.Fit(b, defense.Profiles()[0], *days)
		fmt.Printf("landHP: [")
		for i, x := range b.LandHP {
			if i > 0 {
				fmt.Print(", ")
			}
			fmt.Printf("%.4g", x)
		}
		fmt.Println("]")
	}
	marks := []int{1, 2, 3, 7, 14, 30, 60, 90, 120, 150, 180, 210, 240}
	fmt.Printf("%-10s", "day")
	for _, m := range marks {
		if m <= *days {
			fmt.Printf("%9d", m)
		}
	}
	fmt.Printf("%9s\n", "finish")
	for _, p := range defense.Profiles() {
		logs := defense.Simulate(b, p, *days)
		fmt.Printf("%-10s", p.Name)
		for _, m := range marks {
			if m <= *days {
				l := logs[m-1]
				fmt.Printf("%9s", fmt.Sprintf("%d:%d", l.Land, l.Wave))
			}
		}
		fmt.Printf("%9d   harvests=%d lands=%v\n", defense.FinishDay(logs, b.TotalWaves()), logs[len(logs)-1].Harvests, defense.LandDays(b, logs))
	}
}
