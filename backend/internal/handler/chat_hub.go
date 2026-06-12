package handler

import (
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

const (
	wsWriteWait  = 10 * time.Second
	wsPongWait   = 60 * time.Second
	wsPingPeriod = 54 * time.Second
	wsSendBuffer = 32
)

// Hub tracks active chat WebSocket connections per user and fans events out to
// the right recipients. It is safe for concurrent use.
type Hub struct {
	mu      sync.RWMutex
	clients map[int64]map[*wsConn]struct{}
	// onPresence is invoked (outside the lock) when a user's first connection
	// opens (online=true) or last connection closes (online=false).
	onPresence func(userID int64, online bool)
}

// NewHub creates an empty hub.
func NewHub() *Hub {
	return &Hub{clients: make(map[int64]map[*wsConn]struct{})}
}

// SetPresenceHandler registers a callback for online/offline transitions.
func (h *Hub) SetPresenceHandler(fn func(userID int64, online bool)) {
	h.onPresence = fn
}

// SendToUsers delivers payload to every live connection of the given users.
// Slow consumers are skipped rather than blocking the sender.
func (h *Hub) SendToUsers(userIDs []int64, payload []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, uid := range userIDs {
		for c := range h.clients[uid] {
			select {
			case c.send <- payload:
			default:
			}
		}
	}
}

// broadcastAll delivers payload to every connected client.
func (h *Hub) broadcastAll(payload []byte) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	for _, set := range h.clients {
		for c := range set {
			select {
			case c.send <- payload:
			default:
			}
		}
	}
}

// OnlineUserIDs lists the users with at least one active connection.
func (h *Hub) OnlineUserIDs() []int64 {
	h.mu.RLock()
	defer h.mu.RUnlock()
	ids := make([]int64, 0, len(h.clients))
	for uid, set := range h.clients {
		if len(set) > 0 {
			ids = append(ids, uid)
		}
	}
	return ids
}

func (h *Hub) register(c *wsConn) {
	h.mu.Lock()
	set := h.clients[c.userID]
	wasEmpty := len(set) == 0
	if set == nil {
		set = make(map[*wsConn]struct{})
		h.clients[c.userID] = set
	}
	set[c] = struct{}{}
	h.mu.Unlock()
	if wasEmpty && h.onPresence != nil {
		h.onPresence(c.userID, true)
	}
}

func (h *Hub) unregister(c *wsConn) {
	h.mu.Lock()
	nowEmpty := false
	if set := h.clients[c.userID]; set != nil {
		if _, ok := set[c]; ok {
			delete(set, c)
			close(c.send)
		}
		if len(set) == 0 {
			delete(h.clients, c.userID)
			nowEmpty = true
		}
	}
	h.mu.Unlock()
	if nowEmpty && h.onPresence != nil {
		h.onPresence(c.userID, false)
	}
}

// wsConn is a single authenticated browser connection.
type wsConn struct {
	hub    *Hub
	conn   *websocket.Conn
	userID int64
	send   chan []byte
	// onText handles inbound text frames (e.g. typing signals).
	onText func(userID int64, data []byte)
}

// writePump pushes queued events to the socket and keeps it alive with pings.
func (c *wsConn) writePump() {
	ticker := time.NewTicker(wsPingPeriod)
	defer func() {
		ticker.Stop()
		_ = c.conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.send:
			_ = c.conn.SetWriteDeadline(time.Now().Add(wsWriteWait))
			if !ok {
				_ = c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			_ = c.conn.SetWriteDeadline(time.Now().Add(wsWriteWait))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}

// readPump dispatches inbound frames (typing signals) and unregisters the
// connection when it closes.
func (c *wsConn) readPump() {
	defer func() {
		c.hub.unregister(c)
		_ = c.conn.Close()
	}()
	c.conn.SetReadLimit(2048)
	_ = c.conn.SetReadDeadline(time.Now().Add(wsPongWait))
	c.conn.SetPongHandler(func(string) error {
		return c.conn.SetReadDeadline(time.Now().Add(wsPongWait))
	})
	for {
		mt, data, err := c.conn.ReadMessage()
		if err != nil {
			return
		}
		if mt == websocket.TextMessage && c.onText != nil {
			c.onText(c.userID, data)
		}
	}
}
