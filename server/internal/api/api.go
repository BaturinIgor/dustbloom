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
//	POST /v1/farm/harvest           {"x","y"} -> farm + harvest result
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
	return mux
}

type farmResponse struct {
	Farm       *game.Farm          `json:"farm"`
	Level      int                 `json:"level"`
	ServerTime time.Time           `json:"serverTime"`
	Harvest    *game.HarvestResult `json:"harvest,omitempty"`
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
		game.ErrUnknownCrop, game.ErrNotEnough, game.ErrLocked,
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

// mutate runs a farm action and answers with the new farm state.
func (s *Server) mutate(w http.ResponseWriter, token string, fn func(f *game.Farm, now time.Time) (*game.HarvestResult, error)) {
	now := s.Now()
	var resp farmResponse
	err := s.Store.WithFarm(token, func(f *game.Farm) error {
		h, err := fn(f, now)
		if err != nil {
			return err
		}
		resp = farmResponse{Farm: f, Level: f.Level(), ServerTime: now.UTC(), Harvest: h}
		return nil
	})
	if err != nil {
		gameErrStatus(w, err)
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (s *Server) getFarm(w http.ResponseWriter, r *http.Request, token string) {
	s.mutate(w, token, func(f *game.Farm, now time.Time) (*game.HarvestResult, error) { return nil, nil })
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
	s.mutate(w, token, func(f *game.Farm, now time.Time) (*game.HarvestResult, error) {
		return nil, f.Till(s.Config, req.X, req.Y)
	})
}

func (s *Server) plant(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time) (*game.HarvestResult, error) {
		return nil, f.Plant(s.Config, req.X, req.Y, req.Crop, now)
	})
}

func (s *Server) harvest(w http.ResponseWriter, r *http.Request, token string) {
	var req tileReq
	if !decode(w, r, &req) {
		return
	}
	s.mutate(w, token, func(f *game.Farm, now time.Time) (*game.HarvestResult, error) {
		res, err := f.Harvest(s.Config, req.X, req.Y, now)
		if err != nil {
			return nil, err
		}
		return &res, nil
	})
}
