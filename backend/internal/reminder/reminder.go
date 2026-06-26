// Package reminder runs a periodic background sweep that delivers in-app
// "due soon" / "overdue" notifications to the assignees of open tasks. It does
// not send email — delivery is in-app only.
package reminder

import (
	"context"
	"log"
	"time"

	"github.com/revah-tech/revahms/backend/internal/db"
)

// Run performs a single sweep: every not-done task with an assignee whose due
// date falls within the next 24 hours (or has already passed) and that has not
// yet been reminded gets one notification, then is flagged so it is not
// reminded again until rescheduled or reopened.
func Run(ctx context.Context, q *db.Queries, now time.Time) {
	rows, err := q.DueReminders(ctx)
	if err != nil {
		log.Printf("reminder sweep failed: %v", err)
		return
	}
	for _, t := range rows {
		if t.AssigneeID == nil || !t.DueDate.Valid {
			continue
		}
		title := "Due soon: " + t.Title
		if t.DueDate.Time.Before(now) {
			title = "Overdue: " + t.Title
		}
		uid := *t.AssigneeID
		_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
			UserID: &uid,
			Type:   "reminder",
			Title:  title,
		})
		_ = q.MarkReminded(ctx, t.ID)
	}
	runUserReminders(ctx, q)
}

// runUserReminders delivers any user-set reminders whose time has arrived.
func runUserReminders(ctx context.Context, q *db.Queries) {
	rows, err := q.DueUserReminders(ctx)
	if err != nil {
		log.Printf("user reminder sweep failed: %v", err)
		return
	}
	for _, r := range rows {
		uid := r.UserID
		title := "Reminder"
		if r.Note != "" {
			title = r.Note
		} else if r.TaskTitle != "" {
			title = "Reminder: " + r.TaskTitle
		}
		link := "/"
		if r.TaskID != nil {
			link = "/tasks"
		}
		_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
			UserID: &uid,
			Type:   "reminder",
			Title:  title,
			Body:   r.TaskTitle,
			Link:   link,
		})
		_ = q.MarkReminderSent(ctx, r.ID)
	}
}

// Start launches the sweep in a goroutine: once immediately, then on every
// tick of interval, until ctx is cancelled.
func Start(ctx context.Context, q *db.Queries, interval time.Duration) {
	go func() {
		Run(ctx, q, time.Now())
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case t := <-ticker.C:
				Run(ctx, q, t)
			}
		}
	}()
}
