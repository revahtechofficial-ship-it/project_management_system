// Package schedule computes dependency-aware task rescheduling: when a linked
// task shifts, its successors are pushed forward (durations preserved) until
// every dependency constraint holds. It is pure and side-effect free so it can
// be unit-tested in isolation.
package schedule

import "time"

// Task is the scheduling view of a task. It participates only when it has both
// a start and a due date (HasDates).
type Task struct {
	ID       int64
	Start    time.Time
	Due      time.Time
	HasDates bool
}

// Dep is a precedence edge: predecessor Pred relates to successor Succ per Type
// (one of finish_to_start, start_to_start, finish_to_finish, start_to_finish).
type Dep struct {
	Pred int64
	Succ int64
	Type string
}

// Change is a task's new schedule.
type Change struct {
	Start time.Time
	Due   time.Time
}

// Normalize pushes successors forward (preserving each task's duration) until
// every dependency constraint is satisfied. It never pulls a task earlier, so
// results are stable. Returns only the tasks whose dates changed; tasks lacking
// both dates are ignored, and any cycle is skipped (the API prevents cycles).
func Normalize(tasks []Task, deps []Dep) map[int64]Change {
	cur := make(map[int64]Task, len(tasks))
	orig := make(map[int64]Task, len(tasks))
	for _, t := range tasks {
		cur[t.ID] = t
		orig[t.ID] = t
	}

	succs := make(map[int64][]int64)
	incoming := make(map[int64][]Dep)
	indeg := make(map[int64]int)
	for _, t := range tasks {
		indeg[t.ID] = 0
	}
	for _, d := range deps {
		if _, ok := cur[d.Pred]; !ok {
			continue
		}
		if _, ok := cur[d.Succ]; !ok {
			continue
		}
		succs[d.Pred] = append(succs[d.Pred], d.Succ)
		incoming[d.Succ] = append(incoming[d.Succ], d)
		indeg[d.Succ]++
	}

	// Kahn topological order.
	queue := make([]int64, 0)
	for id, n := range indeg {
		if n == 0 {
			queue = append(queue, id)
		}
	}
	order := make([]int64, 0, len(tasks))
	for len(queue) > 0 {
		id := queue[0]
		queue = queue[1:]
		order = append(order, id)
		for _, s := range succs[id] {
			indeg[s]--
			if indeg[s] == 0 {
				queue = append(queue, s)
			}
		}
	}

	for _, id := range order {
		t := cur[id]
		if !t.HasDates {
			continue
		}
		var shift time.Duration
		for _, d := range incoming[id] {
			p, ok := cur[d.Pred]
			if !ok || !p.HasDates {
				continue
			}
			var need time.Duration
			switch d.Type {
			case "start_to_start":
				if t.Start.Before(p.Start) {
					need = p.Start.Sub(t.Start)
				}
			case "finish_to_finish":
				if t.Due.Before(p.Due) {
					need = p.Due.Sub(t.Due)
				}
			case "start_to_finish":
				if t.Due.Before(p.Start) {
					need = p.Start.Sub(t.Due)
				}
			default: // finish_to_start
				if t.Start.Before(p.Due) {
					need = p.Due.Sub(t.Start)
				}
			}
			if need > shift {
				shift = need
			}
		}
		if shift > 0 {
			t.Start = t.Start.Add(shift)
			t.Due = t.Due.Add(shift)
			cur[id] = t
		}
	}

	changes := make(map[int64]Change)
	for id, t := range cur {
		o := orig[id]
		if t.HasDates && (!t.Start.Equal(o.Start) || !t.Due.Equal(o.Due)) {
			changes[id] = Change{Start: t.Start, Due: t.Due}
		}
	}
	return changes
}

// Reaches reports whether `target` is reachable from `from` along the dep
// edges (predecessor -> successor). Used to reject cycle-forming dependencies.
func Reaches(deps []Dep, from, target int64) bool {
	adj := make(map[int64][]int64)
	for _, d := range deps {
		adj[d.Pred] = append(adj[d.Pred], d.Succ)
	}
	seen := make(map[int64]bool)
	stack := []int64{from}
	for len(stack) > 0 {
		n := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		if n == target {
			return true
		}
		if seen[n] {
			continue
		}
		seen[n] = true
		stack = append(stack, adj[n]...)
	}
	return false
}
