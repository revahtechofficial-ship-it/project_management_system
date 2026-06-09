package vikunja

import "sync"

// SessionStore caches per-user Vikunja JWTs, keyed by the user's Keycloak
// subject. In-memory (dev): tokens are lost on restart, which simply forces the
// client to re-establish its Vikunja session.
type SessionStore struct {
	mu     sync.RWMutex
	tokens map[string]string
}

// NewSessionStore returns an empty store.
func NewSessionStore() *SessionStore {
	return &SessionStore{tokens: make(map[string]string)}
}

// Get returns the cached Vikunja token for the given subject.
func (s *SessionStore) Get(subject string) (string, bool) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	token, ok := s.tokens[subject]
	return token, ok
}

// Set caches a Vikunja token for the subject.
func (s *SessionStore) Set(subject, token string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.tokens[subject] = token
}

// Delete removes a subject's cached token.
func (s *SessionStore) Delete(subject string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	delete(s.tokens, subject)
}
