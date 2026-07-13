// Package reminder runs a periodic background sweep that delivers in-app
// "due soon" / "overdue" notifications to the assignees of open tasks. It does
// not send email — delivery is in-app only.
package reminder

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/jackc/pgx/v5/pgtype"

	"github.com/revah-tech/revahms/backend/internal/db"
	"github.com/revah-tech/revahms/backend/internal/nepdate"
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
	rollRepeatingEvents(ctx, q, now)
	runCalendarReminders(ctx, q, now)
}

// rollRepeatingEvents moves a birthday or anniversary on to its next
// occurrence once the last one has gone by, and clears the reminder flag so it
// can be announced again.
//
// This runs *before* the reminder sweep, so an event that rolled today is
// still eligible to be reminded about today.
func rollRepeatingEvents(ctx context.Context, q *db.Queries, now time.Time) {
	rows, err := q.StaleRepeatingEvents(ctx)
	if err != nil {
		log.Printf("rolling repeating events failed: %v", err)
		return
	}
	for _, e := range rows {
		if !e.EventDate.Valid {
			continue
		}
		when, err := nepdate.NextOccurrence(
			e.RepeatIn, e.EventDate.Time, now)
		if err != nil {
			// A BS date outside the conversion table, most likely. Leave the
			// row alone rather than write a wrong date over it.
			log.Printf("event %d: cannot find next occurrence: %v", e.ID, err)
			continue
		}
		_ = q.RollCalendarEvent(ctx, db.RollCalendarEventParams{
			ID:         e.ID,
			NextOccurs: pgtype.Date{Time: when, Valid: true},
		})
	}
}

// runCalendarReminders tells people about their own events.
func runCalendarReminders(ctx context.Context, q *db.Queries, now time.Time) {
	rows, err := q.DueCalendarReminders(ctx)
	if err != nil {
		log.Printf("calendar reminder sweep failed: %v", err)
		return
	}
	today := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC)
	for _, e := range rows {
		if !e.NextOccurs.Valid {
			continue
		}
		uid := e.UserID
		days := int(e.NextOccurs.Time.Sub(today).Hours() / 24)
		_, _ = q.CreateNotification(ctx, db.CreateNotificationParams{
			UserID: &uid,
			Type:   "reminder",
			Title:  reminderTitle(e.Kind, e.Title, days),
			Body:   e.Note,
			Link:   "/patro",
		})
		_ = q.MarkCalendarEventReminded(ctx, e.ID)
	}
}

// reminderTitle words the notification for the kind of day it is. "Ramesh's
// birthday is tomorrow" beats "Reminder: Ramesh".
func reminderTitle(kind, title string, days int) string {
	var when string
	switch {
	case days <= 0:
		when = "today"
	case days == 1:
		when = "tomorrow"
	default:
		when = fmt.Sprintf("in %d days", days)
	}
	switch kind {
	case "birthday":
		return fmt.Sprintf("%s — birthday %s", title, when)
	case "anniversary":
		return fmt.Sprintf("%s — anniversary %s", title, when)
	case "meeting":
		return fmt.Sprintf("%s — meeting %s", title, when)
	default:
		return fmt.Sprintf("%s — %s", title, when)
	}
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
