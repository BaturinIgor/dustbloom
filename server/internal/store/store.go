// Package store keeps players and their farms. Stage 0 ships an in-memory
// store with an optional JSON snapshot file; PostgreSQL replaces it once
// hosting exists, behind the same interface.
package store

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"os"
	"sync"

	"github.com/BaturinIgor/dustbloom/server/internal/game"
)

// ErrNoPlayer means the token or player id is unknown.
var ErrNoPlayer = errors.New("no_player")

// Player is an account and its farm.
type Player struct {
	ID       string     `json:"id"`
	DeviceID string     `json:"deviceId"`
	Token    string     `json:"token"`
	Farm     *game.Farm `json:"farm"`
}

// Store is what the API needs from persistence.
type Store interface {
	// GuestLogin returns the player bound to deviceID, creating one if needed.
	GuestLogin(deviceID string, newFarm func() *game.Farm) (*Player, error)
	// WithFarm runs fn on the player's farm under a lock and saves the result
	// if fn returns nil.
	WithFarm(token string, fn func(*game.Farm) error) error
	// PlayerID returns the player id behind a token (for analytics).
	PlayerID(token string) (string, error)
}

// Memory is a thread-safe in-memory store.
type Memory struct {
	mu       sync.Mutex
	byToken  map[string]*Player
	byDevice map[string]*Player
	path     string // optional snapshot file
}

// NewMemory creates an empty store. If path is non-empty, state is loaded
// from and saved to that JSON file.
func NewMemory(path string) (*Memory, error) {
	m := &Memory{
		byToken:  map[string]*Player{},
		byDevice: map[string]*Player{},
		path:     path,
	}
	if path == "" {
		return m, nil
	}
	data, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		return m, nil
	}
	if err != nil {
		return nil, err
	}
	var players []*Player
	if err := json.Unmarshal(data, &players); err != nil {
		return nil, err
	}
	for _, p := range players {
		m.byToken[p.Token] = p
		m.byDevice[p.DeviceID] = p
	}
	return m, nil
}

func randomID(n int) (string, error) {
	b := make([]byte, n)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// GuestLogin implements Store.
func (m *Memory) GuestLogin(deviceID string, newFarm func() *game.Farm) (*Player, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	if p, ok := m.byDevice[deviceID]; ok {
		return p, nil
	}
	id, err := randomID(8)
	if err != nil {
		return nil, err
	}
	token, err := randomID(24)
	if err != nil {
		return nil, err
	}
	p := &Player{ID: id, DeviceID: deviceID, Token: token, Farm: newFarm()}
	m.byToken[token] = p
	m.byDevice[deviceID] = p
	return p, m.saveLocked()
}

// WithFarm implements Store.
func (m *Memory) WithFarm(token string, fn func(*game.Farm) error) error {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.byToken[token]
	if !ok {
		return ErrNoPlayer
	}
	if err := fn(p.Farm); err != nil {
		return err
	}
	return m.saveLocked()
}

func (m *Memory) saveLocked() error {
	if m.path == "" {
		return nil
	}
	players := make([]*Player, 0, len(m.byToken))
	for _, p := range m.byToken {
		players = append(players, p)
	}
	data, err := json.Marshal(players)
	if err != nil {
		return err
	}
	tmp := m.path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, m.path)
}

// PlayerID implements Store.
func (m *Memory) PlayerID(token string) (string, error) {
	m.mu.Lock()
	defer m.mu.Unlock()
	p, ok := m.byToken[token]
	if !ok {
		return "", ErrNoPlayer
	}
	return p.ID, nil
}
