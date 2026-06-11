// Package email sends transactional mail (OTP codes) over SMTP. When SMTP is
// not configured, it logs the code instead so the flow is testable in dev.
package email

import (
	"fmt"
	"log"
	"net/smtp"
)

// Sender sends OTP emails via SMTP.
type Sender struct {
	host, port, user, pass, from, appName string
}

// NewSender builds a Sender. If host/from are empty, it runs in dev mode
// (logs codes instead of sending).
func NewSender(host, port, user, pass, from, appName string) *Sender {
	if port == "" {
		port = "587"
	}
	if appName == "" {
		appName = "Revah Management System"
	}
	return &Sender{host: host, port: port, user: user, pass: pass, from: from, appName: appName}
}

func (s *Sender) configured() bool { return s.host != "" && s.from != "" }

// SendOTP delivers a 6-digit code for the given purpose ("signup" | "reset").
func (s *Sender) SendOTP(to, code, purpose string) error {
	action := "verification"
	if purpose == "reset" {
		action = "password reset"
	}
	subject := fmt.Sprintf("%s %s code", s.appName, action)
	body := fmt.Sprintf(
		"Your %s %s code is:\n\n    %s\n\nIt expires in 10 minutes. "+
			"If you didn't request this, you can ignore this email.",
		s.appName, action, code,
	)

	if !s.configured() {
		log.Printf("[email DEV] no SMTP configured — OTP for %s (%s): %s", to, purpose, code)
		return nil
	}

	msg := []byte(fmt.Sprintf(
		"From: %s\r\nTo: %s\r\nSubject: %s\r\n"+
			"MIME-Version: 1.0\r\nContent-Type: text/plain; charset=UTF-8\r\n\r\n%s\r\n",
		s.from, to, subject, body,
	))
	auth := smtp.PlainAuth("", s.user, s.pass, s.host)
	if err := smtp.SendMail(s.host+":"+s.port, auth, s.from, []string{to}, msg); err != nil {
		log.Printf("[email] SMTP send to %s failed: %v", to, err)
		return err
	}
	log.Printf("[email] sent %s code to %s", purpose, to)
	return nil
}
