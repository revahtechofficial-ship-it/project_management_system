// Package email sends transactional mail (OTP codes) over SMTP as a branded
// multipart (HTML + plain-text) message. When SMTP is not configured it logs
// the code instead, so the flow is testable in dev.
package email

import (
	"fmt"
	"log"
	"net/smtp"
	"strings"
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
	var subjectAction, headingText, intro string
	switch purpose {
	case "reset":
		subjectAction = "password reset"
		headingText = "Reset your password"
		intro = "Use the code below to reset your " + s.appName + " password. " +
			"It keeps your account secure — never share it with anyone."
	default:
		subjectAction = "verification"
		headingText = "Verify your email"
		intro = "Welcome! Use the code below to verify your email and finish " +
			"setting up your " + s.appName + " account."
	}
	subject := fmt.Sprintf("%s — your %s code", s.appName, subjectAction)

	plain := fmt.Sprintf(
		"%s\n\nYour code is: %s\n\nThis code expires in 10 minutes. "+
			"If you didn't request this, you can ignore this email.\n\n— %s",
		headingText, code, s.appName,
	)
	html := s.htmlBody(headingText, intro, code)

	if !s.configured() {
		log.Printf("[email DEV] no SMTP configured — OTP for %s (%s): %s", to, purpose, code)
		return nil
	}

	msg := s.mimeMessage(to, subject, plain, html)
	auth := smtp.PlainAuth("", s.user, s.pass, s.host)
	if err := smtp.SendMail(s.host+":"+s.port, auth, s.from, []string{to}, msg); err != nil {
		log.Printf("[email] SMTP send to %s failed: %v", to, err)
		return err
	}
	log.Printf("[email] sent %s code to %s", purpose, to)
	return nil
}

func (s *Sender) mimeMessage(to, subject, plain, html string) []byte {
	const boundary = "rms-mime-boundary-7f3a9c1e"
	var b strings.Builder
	fmt.Fprintf(&b, "From: %s <%s>\r\n", s.appName, s.from)
	fmt.Fprintf(&b, "To: %s\r\n", to)
	fmt.Fprintf(&b, "Subject: %s\r\n", subject)
	b.WriteString("MIME-Version: 1.0\r\n")
	fmt.Fprintf(&b, "Content-Type: multipart/alternative; boundary=\"%s\"\r\n\r\n", boundary)

	fmt.Fprintf(&b, "--%s\r\n", boundary)
	b.WriteString("Content-Type: text/plain; charset=UTF-8\r\n\r\n")
	b.WriteString(plain)
	b.WriteString("\r\n\r\n")

	fmt.Fprintf(&b, "--%s\r\n", boundary)
	b.WriteString("Content-Type: text/html; charset=UTF-8\r\n\r\n")
	b.WriteString(html)
	b.WriteString("\r\n\r\n")

	fmt.Fprintf(&b, "--%s--\r\n", boundary)
	return []byte(b.String())
}

// htmlBody builds a branded, email-client-safe (table + inline styles) message.
func (s *Sender) htmlBody(heading, intro, code string) string {
	return `<!DOCTYPE html>
<html><body style="margin:0;padding:0;background:#eef0f5;font-family:-apple-system,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#eef0f5;padding:32px 12px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;background:#ffffff;border-radius:18px;overflow:hidden;box-shadow:0 6px 24px rgba(17,24,39,0.08);">
        <tr><td style="background:#4f46e5;background:linear-gradient(135deg,#4f46e5,#7c3aed);padding:30px 32px;text-align:center;">
          <div style="display:inline-block;width:44px;height:44px;line-height:44px;border-radius:12px;background:rgba(255,255,255,0.18);color:#ffffff;font-size:22px;font-weight:700;">R</div>
          <div style="margin-top:12px;font-size:19px;font-weight:700;color:#ffffff;letter-spacing:0.2px;">` + s.appName + `</div>
        </td></tr>
        <tr><td style="padding:32px 32px 8px;">
          <h1 style="margin:0 0 10px;font-size:21px;font-weight:700;color:#111827;">` + heading + `</h1>
          <p style="margin:0 0 24px;font-size:14px;line-height:1.65;color:#6b7280;">` + intro + `</p>
          <div style="background:#f5f6fa;border:1px dashed #c7cad6;border-radius:14px;padding:22px;text-align:center;margin:0 0 22px;">
            <div style="font-size:13px;color:#9ca3af;margin-bottom:6px;letter-spacing:1px;text-transform:uppercase;">Your code</div>
            <div style="font-size:36px;font-weight:800;letter-spacing:12px;color:#4f46e5;">` + code + `</div>
          </div>
          <p style="margin:0 0 6px;font-size:13px;color:#6b7280;">This code expires in <strong style="color:#374151;">10 minutes</strong>.</p>
          <p style="margin:0 0 4px;font-size:13px;color:#9ca3af;">If you didn't request this, you can safely ignore this email — your account stays secure.</p>
        </td></tr>
        <tr><td style="padding:20px 32px 26px;text-align:center;">
          <div style="border-top:1px solid #eef0f5;padding-top:18px;font-size:12px;color:#9ca3af;">© Revah Tech · ` + s.appName + `</div>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body></html>`
}
