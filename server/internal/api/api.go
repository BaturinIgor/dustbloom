// Package api is the HTTP JSON API used by the iPhone client.
//
// Endpoints (all JSON):
//
//	GET  /health
//	GET  /v1/config                 game balance file
//	POST /v1/auth/guest             {"deviceId"} -> {"token","playerId"}
//	GET  /v1/farm                   farm state + serverTime
//	POST /v1/farm/till              {"x","y"}
//	POST /v1/farm/plant             {"x","y","crop"}
//	POST /v1/farm/harvest           {"x","y"} -> farm + harvest result (crop goes to the barn)
//	POST /v1/farm/sell              {"crop","count"} -> farm + sold coins
//	POST /v1/farm/plot              {"x","y"} plot grid coords -> farm
//	POST /v1/orders/deliver         {"index"} -> farm + order reward
//	POST /v1/orders/skip            {"index"} -> farm (slot refills later)
//	POST /v1/army/build             {"scarecrow"} -> farm with the workshop queue
//	POST /v1/raid                   {"raid"} -> farm + raid result with every hit
//	POST /v1/items/speedup          {"target":{"kind","x","y"},"items":{id:n}} -> farm + seconds saved
//	POST /v1/items/smart            {"target":{"kind","x","y"}} -> farm + plan used + seconds saved
//	POST /v1/items/open             {"item","count"} -> farm + loot
//	POST /v1/manor/upgrade          {} -> farm with manorReadyAt
//
// Authenticated calls send "Authorization: Bearer <token>".
package api

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
	"time"

	"github.com/BaturinIgor/dustbloom/server/internal/game"
	"github.com/BaturinIgor/dustbloom/server/internal/store"
)

// Server wires the game rules to HTTP.
type Server struct {
	Config *game.Config
	Store  store.Store
	Now    func() time.Time
}

// Handler returns the API router.
func (s *Server) Handler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /v1/config", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write(game.RawDefaultConfig())
	})
	mux.HandleFunc("POST /v1/auth/guest", s.guest)
	mux.HandleFunc("GET /v1/farm", s.auth(s.getFarm))
	mux.HandleFunc("POST /v1/farm/till", s.auth(s.till))
	mux.HandleFunc("POST /v1/farm/plant", s.auth(s.plant))
	mux.HandleFunc("POST /v1/farm/harvest", s.auth(s.harvest))
	mux.HandleFunc("POST /v1/farm/sell", s.auth(s.sell))
	mux.HandleFunc("POST /v1/farm/plot", s.auth(s.buyPlot))
	mux.HandleFunc("POST /v1/army/build", s.auth(s.build))
	mux.HandleFunc("POST /v1/orders/deliver", s.auth(s.deliverOrder))
	mux.HandleFunc("POST /v1/orders/skip", s.auth(s.skipOrder))
	mux.HandleFunc("POST /v1/raid", s.auth(s.raid))
	mux.HandleFunc("POST /v1/items/speedup", s.auth(s.speedup))
	mux.HandleFunc("POST /v1/items/smart", s.auth(s.smartSpeedup))
	mux.HandleFunc("POST /v1/items/open", s.auth(s.openChest))
	mux.HandleFunc("POST /v1/manor/upgrade", s.auth(s.upgradeManor))
	return mux
}

type farmResponse struct {
	Farm       *game.Farm          `json:"farm"`
	Level      int                 `json:"level"`
	ArmySlots  int                 `json:"armySlots"`
	ServerTime time.Time           `json:"serverTime"`
	Harvest    *game.HarvestResult `json:"harvest,omitempty"`
	Sold       int                 `json:"sold,omitempty"`
	Raid       *game.RaidResult    `json:"raid,omitempty"`
	Order      *game.OrderResult   `json:"order,omitempty"`
	Saved      int                 `json:"saved,omitempty"` // speedup seconds used
	Used       map[string]int      `json:"used,omitempty"`  // speedups spent
	Loot       map[string]int      `json:"loot,omitempty"`  // chest contents
}

type errorResponse struct {
	Error string `json:"error"`
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(v)
}

func writeErr(w http.ResponseWriter, status int, code string) {
	writeJSON(w, status, errorResponse{Error: code})
}

// gameErrStatus maps rule violations to 409 with a stable code.
func gameErrStatus(w http.ResponseWriter, err error) {
	if errors.Is(err, store.ErrNoPlayer) {
		writeErr(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	for _, known := range []error{
		game.ErrOutOfBounds, game.ErrNotTilled, game.ErrAlreadyTilled,
		game.ErrOccupied, game.ErrEmpty, game.ErrNotReady,
		game.ErrUnknownCrop, game.ErrNotEnough, game.ErrLocked, game.ErrNoCrops,
		game.ErrUnknownScarecrow, game.ErrQueueFull, game.ErrUnknownRaid,
		game.ErrRaidCooldown, game.ErrNoArmy, game.ErrNotOwned, game.ErrOwned, game.ErrNotAdjacent,
		game.ErrNoOrder, game.ErrOrderNotReady,
		game.ErrUnknownItem, game.ErrNoItems, game.ErrWrongTarget, game.ErrNothingToSpeed,
		game.ErrUnknownTarget, game.ErrNotAChest, game.ErrNotASpeedup,
		game.ErrBusy, game.ErrMaxLevel,
	} {
		if errors.Is(err, known) {
			writeErr(w, http.StatusConflict, known.Error())
			return
		}
	}
	writeErr(w, http.StatusInternalServerError, "internal")
}

type ctxHandler func(w http.ResponseWriter, r *http.Request, token string)

func (s *Server) auth(h ctxHandler) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		token, ok := strings.CutPrefix(r.Header.Get("Authorization"), "Bearer ")
		if !ok || token == "" {
			writeErr(w, http.StatusUnauthorized, "unauthorized")
			return
		}
		h(w, r, token)
	}
}

func decode(w http.ResponseWriter, r *http.Request, v any) bool {
	r.Body = http.MaxBytesReader(w, r.Body, 4096)
	if err := json.NewDecoder(r.Body).Decode(v); err != nil {
		writeErr(w, http.StatusBadRequest, "bad_request")
		return false
	}
	return true
}

func (s *Server) guest(w http.ResponseWriter, r *http.Request) {
	var req struct {
		DeviceID string `json:"deviceId"`
	}
	if !decode(w, r, &req) {
		return
	}
	if len(req.DeviceID) < 8 || len(req.DeviceID) > 128 {
		writeErr(w, http.StatusBadRequest, "bad_device_id")
		return
	}
	p, err := s.Store.GuestLogin(req.DeviceID, func() *game.Farm { return game.NewFarm(s.Config) })
	if err != nil {
		writeErr(w, http.StatusInternalServerError, "internal")
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"token": p.Token, "playerId": p.ID})
}

// mutate runs a farm action and answers with the new farm state. The action
// fills in its own result fields (harvest, sold, raid) on resp.
func (s *Server) mutate(w http.ResponseWriter, token string, fn func(f *game.Farm, now time.Time, resp *farmResponse) error) {
	now := s.Now()
	var resp farmResponse
	err := s.Store.WithFarm(token, func(f *game.Farm) error {
		f.EnsurePlots(s.Config)
		f.Settle(s.Config, now)
		f.FillOrders(s.Config, now, uint64(now.UnixNano()))
		if err := fn(f, now, &resp); err != nil {
			return err
		}
		resp.Farm, resp.Level, resp.ArmySlots, resp.ServerTime = f, f.Level(), f.ArmySlots(s.Config), now.UTC()
		return nil
	})
	if err != nil {
		gameErrStatus(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) getFarm(w http.ResponseWriter, r *http.Request, token string) {
	s.mutate(w, token, func(*game.Farm, time.Time, *farmResponse) error { return nil })
}

type tileReq struct {
	X    int    `json:"x"`
	Y    int    `json:"y"`
	Crop string `json:"crop"`
}

func (s *Server) till(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.Till(s.Config, req.X, req.Y)
	})
}

func (s *Server) plant(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.Plant(s.Config, req.X, req.Y, req.Crop, now)
	})
}

func (s *Server) harvest(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		res, err := f.Harvest(s.Config, req.X, req.Y, now)
		resp.Harvest = &res
		return err
	})
}

func (s *Server) sell(w http.ResponseWriter, r *http.Request, token string) {
	var req struct {
		Crop  string `json:"crop"`
		Count int    `json:"count"`
	}
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		coins, err := f.Sell(s.Config, req.Crop, req.Count)
		resp.Sold = coins
		return err
	})
}

func (s *Server) build(w http.ResponseWriter, r *http.Request, token string) {
	var req struct {
		Scarecrow string `json:"scarecrow"`
	}
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.BuildScarecrow(s.Config, req.Scarecrow, now)
	})
}

func (s *Server) raid(w http.ResponseWriter, r *http.Request, token string) {
	var req struct {
		Raid string `json:"raid"`
	}
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		res, err := f.Raid(s.Config, req.Raid, now, uint64(now.UnixNano()))
		resp.Raid = &res
		return err
	})
}

func (s *Server) buyPlot(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.BuyPlot(s.Config, req.X, req.Y)
	})
}

type orderReq struct {
	Index int `json:"index"`
}

func (s *Server) deliverOrder(w http.ResponseWriter, r *http.Request, token string) {
	var req orderReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		res, err := f.DeliverOrder(s.Config, req.Index, now, uint64(now.UnixNano())+1)
		resp.Order = &res
		return err
	})
}

func (s *Server) skipOrder(w http.ResponseWriter, r *http.Request, token string) {
	var req orderReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.SkipOrder(s.Config, req.Index, now)
	})
}

type speedReq struct {
	Target game.SpeedTarget `json:"target"`
	Items  map[string]int   `json:"items"`
}

func (s *Server) speedup(w http.ResponseWriter, r *http.Request, token string) {
	var req speedReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		saved, err := f.UseSpeedups(s.Config, req.Target, req.Items, now)
		resp.Saved, resp.Used = saved, req.Items
		return err
	})
}

// smartSpeedup picks the speedups itself (the "smart speedup" button).
func (s *Server) smartSpeedup(w http.ResponseWriter, r *http.Request, token string) {
	var req speedReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		plan, err := f.PlanSpeedups(s.Config, req.Target, now)
		if err != nil {
			return err
		}
		saved, err := f.UseSpeedups(s.Config, req.Target, plan, now)
		resp.Saved, resp.Used = saved, plan
		return err
	})
}

func (s *Server) openChest(w http.ResponseWriter, r *http.Request, token string) {
	var req struct {
		Item  string `json:"item"`
		Count int    `json:"count"`
	}
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time, resp *farmResponse) error {
		loot, err := f.OpenChest(s.Config, req.Item, req.Count, uint64(now.UnixNano()))
		resp.Loot = loot
		return err
	})
}

func (s *Server) upgradeManor(w http.ResponseWriter, r *http.Request, token string) {
	s.mutate(w, token, func(f *game.Farm, now time.Time, _ *farmResponse) error {
		return f.UpgradeManor(s.Config, now)
	})
}
