package schedule

import (
	"testing"
	"time"
)

var base = time.Date(2026, 1, 1, 0, 0, 0, 0, time.UTC)

func day(n int) time.Time { return base.AddDate(0, 0, n) }

func task(id int64, start, due int) Task {
	return Task{ID: id, Start: day(start), Due: day(due), HasDates: true}
}

func TestFinishToStartPushesSuccessor(t *testing.T) {
	tasks := []Task{task(1, 0, 2), task(2, 0, 1)}
	deps := []Dep{{Pred: 1, Succ: 2, Type: "finish_to_start"}}
	changes := Normalize(tasks, deps)
	c, ok := changes[2]
	if !ok {
		t.Fatalf("expected task 2 to be rescheduled")
	}
	if !c.Start.Equal(day(2)) || !c.Due.Equal(day(3)) {
		t.Fatalf("task 2 = [%v,%v], want [day2,day3]", c.Start, c.Due)
	}
	if _, moved := changes[1]; moved {
		t.Fatalf("predecessor should not move")
	}
}

func TestChainCascades(t *testing.T) {
	// A[0..1] -> B[0..1] -> C[0..1], all finish-to-start.
	tasks := []Task{task(1, 0, 1), task(2, 0, 1), task(3, 0, 1)}
	deps := []Dep{
		{Pred: 1, Succ: 2, Type: "finish_to_start"},
		{Pred: 2, Succ: 3, Type: "finish_to_start"},
	}
	changes := Normalize(tasks, deps)
	if !changes[2].Start.Equal(day(1)) {
		t.Fatalf("B start = %v, want day1", changes[2].Start)
	}
	if !changes[3].Start.Equal(day(2)) {
		t.Fatalf("C start = %v, want day2 (cascaded)", changes[3].Start)
	}
}

func TestAlreadyValidNoChange(t *testing.T) {
	tasks := []Task{task(1, 0, 1), task(2, 2, 3)}
	deps := []Dep{{Pred: 1, Succ: 2, Type: "finish_to_start"}}
	if len(Normalize(tasks, deps)) != 0 {
		t.Fatalf("valid schedule should produce no changes")
	}
}

func TestStartToStart(t *testing.T) {
	tasks := []Task{task(1, 3, 5), task(2, 0, 2)}
	deps := []Dep{{Pred: 1, Succ: 2, Type: "start_to_start"}}
	c := Normalize(tasks, deps)[2]
	if !c.Start.Equal(day(3)) || !c.Due.Equal(day(5)) {
		t.Fatalf("SS shift wrong: [%v,%v]", c.Start, c.Due)
	}
}

func TestReachesDetectsPath(t *testing.T) {
	deps := []Dep{{Pred: 1, Succ: 2}, {Pred: 2, Succ: 3}}
	if !Reaches(deps, 1, 3) {
		t.Fatal("1 should reach 3")
	}
	if Reaches(deps, 3, 1) {
		t.Fatal("3 should not reach 1")
	}
}
