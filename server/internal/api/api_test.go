package api

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/BaturinIgor/dustbloom/server/internal/game"
	"github.com/BaturinIgor/dustbloom/server/internal/store"
)

type testEnv struct {
	t     *testing.T
	srv   *httptest.Server
	now   time.Time
	token string
}

func newEnv(t *testing.T) *testEnv {
	t.Helper()
	cfg, err := game.DefaultConfig()
	if err != nil {
		t.Fatal(err)
	}
	st, err := store.NewMemory("")
	if err != nil {
		t.Fatal(err)
	}
	e := &testEnv{t: t, now: time.Date(2026, 11, 26, 9, 0, 0, 0, time.UTC)}
	s := &Server{Config: cfg, Store: st, Now: func() time.Time { return e.now }}
	e.srv = httptest.NewServer(s.Handler())
	t.Cleanup(e.srv.Close)
	return e
}

func (e *testEnv) do(method, path string, body any, out any) int {
	e.t.Helper()
	var buf bytes.Buffer
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req, _ := http.NewRequest(method, e.srv.URL+path, &buf)
	if e.token != "" {
		req.Header.Set("Authorization", "Bearer "+e.token)
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		e.t.Fatal(err)
	}
	defer resp.Body.Close()
	if out != nil {
		_ = json.NewDecoder(resp.Body).Decode(out)
	}
	return resp.StatusCode
}

func (e *testEnv) login(device string) {
	e.t.Helper()
	var r struct{ Token, PlayerID string }
	if code := e.do("POST", "/v1/auth/guest", map[string]string{"deviceId": device}, &r); code != 200 {
		e.t.Fatalf("login status %d", code)
	}
	e.token = r.Token
}

func TestHealthAndConfig(t *testing.T) {
	e := newEnv(t)
	if code := e.do("GET", "/health", nil, nil); code != 200 {
		t.Fatalf("health = %d", code)
	}
	var cfg game.Config
	if code := e.do("GET", "/v1/config", nil, &cfg); code != 200 || len(cfg.Crops) == 0 {
		t.Fatalf("config = %d, crops %d", code, len(cfg.Crops))
	}
}

func TestFarmFlow(t *testing.T) {
	e := newEnv(t)
	if code := e.do("GET", "/v1/farm", nil, nil); code != 401 {
		t.Fatalf("unauthenticated farm = %d, want 401", code)
	}
	e.login("device-abc-123")

	var fr farmResponse
	if code := e.do("GET", "/v1/farm", nil, &fr); code != 200 || fr.Farm.Coins != 100 {
		t.Fatalf("farm = %d, coins %v", code, fr.Farm)
	}
	if code := e.do("POST", "/v1/farm/plant", tileReq{X: 6, Y: 6, Crop: "dustwheat"}, &fr); code != 200 {
		t.Fatalf("plant = %d", code)
	}
	var er errorResponse
	if code := e.do("POST", "/v1/farm/harvest", tileReq{X: 6, Y: 6}, &er); code != 409 || er.Error != "not_ready" {
		t.Fatalf("early harvest = %d %q", code, er.Error)
	}
	e.now = e.now.Add(31 * time.Second)
	fr = farmResponse{}
	if code := e.do("POST", "/v1/farm/harvest", tileReq{X: 6, Y: 6}, &fr); code != 200 || fr.Harvest == nil || fr.Harvest.Count != 1 {
		t.Fatalf("harvest = %d %+v", code, fr.Harvest)
	}
	if code := e.do("POST", "/v1/farm/sell", map[string]any{"crop": "dustwheat", "count": 1}, &fr); code != 200 || fr.Sold != 5 {
		t.Fatalf("sell = %d, sold %d", code, fr.Sold)
	}
	if fr.Farm.Coins != 103 {
		t.Fatalf("coins = %d, want 103", fr.Farm.Coins)
	}
	if code := e.do("POST", "/v1/farm/till", tileReq{X: 4, Y: 0}, &fr); code != 200 || !fr.Farm.Tiles[4].Tilled {
		t.Fatalf("till = %d", code)
	}
}

func TestArmyAndRaidFlow(t *testing.T) {
	e := newEnv(t)
	e.login("device-army-1")
	var er errorResponse
	if code := e.do("POST", "/v1/raid", map[string]string{"raid": "dust_rats"}, &er); code != 409 || er.Error != "no_army" {
		t.Fatalf("raid without army = %d %q", code, er.Error)
	}
	// grow and harvest 5 wheat on the starting beds, then build a guard
	for x := 6; x < 10; x++ {
		for _, y := range []int{6, 7} {
			e.do("POST", "/v1/farm/plant", tileReq{X: x, Y: y, Crop: "dustwheat"}, nil)
		}
	}
	e.now = e.now.Add(31 * time.Second)
	for x := 6; x < 10; x++ {
		for _, y := range []int{6, 7} {
			e.do("POST", "/v1/farm/harvest", tileReq{X: x, Y: y}, nil)
		}
	}
	var fr farmResponse
	if code := e.do("POST", "/v1/army/build", map[string]string{"scarecrow": "straw_guard"}, &fr); code != 200 || len(fr.Farm.Queue) != 1 {
		t.Fatalf("build = %d queue %v", code, fr.Farm.Queue)
	}
	e.now = e.now.Add(21 * time.Second)
	fr = farmResponse{}
	if code := e.do("GET", "/v1/farm", nil, &fr); code != 200 || len(fr.Farm.Army) != 1 || fr.ArmySlots != 3 {
		t.Fatalf("army after build time = %d %+v slots %d", code, fr.Farm.Army, fr.ArmySlots)
	}
	fr = farmResponse{}
	if code := e.do("POST", "/v1/raid", map[string]string{"raid": "dust_rats"}, &fr); code != 200 || fr.Raid == nil || len(fr.Raid.Hits) == 0 {
		t.Fatalf("raid = %d %+v", code, fr.Raid)
	}
}

func TestOrdersEndpoints(t *testing.T) {
	e := newEnv(t)
	e.login("device-orders-1")
	var fr farmResponse
	if code := e.do("GET", "/v1/farm", nil, &fr); code != 200 || len(fr.Farm.Orders) != 3 {
		t.Fatalf("farm = %d, orders %d", code, len(fr.Farm.Orders))
	}
	var er errorResponse
	if code := e.do("POST", "/v1/orders/deliver", orderReq{Index: 0}, &er); code != 409 || er.Error != "not_enough_crops" {
		t.Fatalf("deliver = %d %q", code, er.Error)
	}
	fr = farmResponse{}
	if code := e.do("POST", "/v1/orders/skip", orderReq{Index: 0}, &fr); code != 200 || fr.Farm.Orders[0].ReadyAt == nil {
		t.Fatalf("skip = %d", code)
	}
}

func TestGuestLoginIsStablePerDevice(t *testing.T) {
	e := newEnv(t)
	e.login("device-same-1")
	first := e.token
	e.token = ""
	e.login("device-same-1")
	if e.token != first {
		t.Fatal("same device got a different token")
	}
}

func TestBadRequests(t *testing.T) {
	e := newEnv(t)
	if code := e.do("POST", "/v1/auth/guest", map[string]string{"deviceId": "x"}, nil); code != 400 {
		t.Fatalf("short device id = %d", code)
	}
	e.token = "nope"
	if code := e.do("GET", "/v1/farm", nil, nil); code != 401 {
		t.Fatalf("bad token = %d", code)
	}
}

func TestStorageEndpoints(t *testing.T) {
	e := newEnv(t)
	e.login("device-items-1")
	var fr farmResponse
	if code := e.do("POST", "/v1/farm/plant", tileReq{X: 6, Y: 6, Crop: "dustwheat"}, &fr); code != 200 {
		t.Fatalf("plant = %d", code)
	}
	fr = farmResponse{}
	grow := map[string]any{"target": game.SpeedTarget{Kind: game.TargetGrow, X: 6, Y: 6}}
	if code := e.do("POST", "/v1/items/smart", grow, &fr); code != 200 || fr.Saved == 0 || len(fr.Used) == 0 {
		t.Fatalf("smart = %d saved %d used %v", code, fr.Saved, fr.Used)
	}
	if code := e.do("POST", "/v1/farm/harvest", tileReq{X: 6, Y: 6}, &fr); code != 200 {
		t.Fatalf("harvest after speedup = %d", code)
	}
	var er errorResponse
	if code := e.do("POST", "/v1/items/speedup", map[string]any{
		"target": game.SpeedTarget{Kind: game.TargetRecruit}, "items": map[string]int{"speed_any_5m": 1},
	}, &er); code != 409 || er.Error != "nothing_to_speed_up" {
		t.Fatalf("speedup empty queue = %d %q", code, er.Error)
	}
	fr = farmResponse{}
	if code := e.do("POST", "/v1/items/open", map[string]any{"item": "chest_wood", "count": 1}, &fr); code != 200 || len(fr.Loot) == 0 {
		t.Fatalf("open = %d loot %v", code, fr.Loot)
	}
	if fr.Farm.Items["chest_wood"] != 0 {
		t.Fatalf("chest left: %v", fr.Farm.Items)
	}
}

func TestManorEndpoint(t *testing.T) {
	e := newEnv(t)
	e.login("device-manor-1")
	var fr farmResponse
	if code := e.do("POST", "/v1/manor/upgrade", nil, &fr); code != 200 || fr.Farm.ManorReadyAt == nil {
		t.Fatalf("upgrade = %d", code)
	}
	var er errorResponse
	if code := e.do("POST", "/v1/manor/upgrade", nil, &er); code != 409 || er.Error != "busy" {
		t.Fatalf("busy = %d %q", code, er.Error)
	}
	e.now = e.now.Add(time.Hour)
	fr = farmResponse{}
	if code := e.do("GET", "/v1/farm", nil, &fr); code != 200 || fr.Farm.ManorLevel() != 2 {
		t.Fatalf("after an hour manor = %d", fr.Farm.ManorLevel())
	}
}
