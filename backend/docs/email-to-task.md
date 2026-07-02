# Email-to-task

Turn forwarded emails into tasks. The backend exposes a public, secret-guarded
webhook; a small Google Apps Script running on the workspace Gmail account
(`revah.tech.official@gmail.com`) forwards incoming mail to it. No SendGrid /
Mailgun needed — everything stays in Gmail.

## 1. Configure the backend

Set a strong shared secret (local `.env` and on Render):

```
INBOUND_EMAIL_SECRET=<a-long-random-string>
```

When this is empty the webhook returns `503` (disabled).

Webhook: `POST /api/v1/inbound/email`

- Auth: `?secret=<INBOUND_EMAIL_SECRET>` (query) or `X-Inbound-Secret` header.
- Body: JSON `{ "to", "from", "subject", "text" }`, or form fields
  (`to`/`recipient`, `from`/`sender`, `subject`, `text`/`body-plain`) so
  SendGrid/Mailgun-style posts also work if you switch later.

## 2. Routing to a project (optional)

A task is filed into a project when the id appears in either:

- the recipient, e.g. `revah.tech.official+p42@gmail.com` (Gmail delivers
  plus-addresses to the base inbox), or
- the subject, e.g. `[p42] Fix the login bug` (also `[42]` / `[#42]`).

With no id, the task is created unfiled. Title = subject (or first line of the
body); the body becomes the description with a `— via email from <sender>`
footer.

## 3. Gmail Apps Script bridge

1. In Gmail, make a filter that labels task emails, e.g. matches
   `to:revah.tech.official+p*@gmail.com` (or a subject rule) → apply label
   **`to-tasks`**.
2. Go to https://script.google.com (signed in as the workspace account),
   create a new project, paste the script below, and set `WEBHOOK` + `SECRET`.
3. Add a time-driven trigger: Triggers → Add Trigger → `processInbox`, every
   5 minutes.

```javascript
const WEBHOOK = 'https://revahms-backend.onrender.com/api/v1/inbound/email';
const SECRET  = 'PASTE_INBOUND_EMAIL_SECRET_HERE';
const LABEL   = 'to-tasks';

function processInbox() {
  const label = GmailApp.getUserLabelByName(LABEL);
  if (!label) return;
  const doneLabel =
    GmailApp.getUserLabelByName('tasks-done') ||
    GmailApp.createLabel('tasks-done');

  label.getThreads(0, 20).forEach(function (thread) {
    thread.getMessages().forEach(function (msg) {
      const payload = {
        to: msg.getTo(),
        from: msg.getFrom(),
        subject: msg.getSubject(),
        text: msg.getPlainBody(),
      };
      const res = UrlFetchApp.fetch(WEBHOOK + '?secret=' + encodeURIComponent(SECRET), {
        method: 'post',
        contentType: 'application/json',
        payload: JSON.stringify(payload),
        muteHttpExceptions: true,
      });
      if (res.getResponseCode() !== 200) {
        Logger.log('inbound failed: ' + res.getResponseCode() + ' ' + res.getContentText());
        return; // leave labelled so it retries next run
      }
    });
    thread.removeLabel(label).addLabel(doneLabel).markRead();
  });
}
```

The script only POSTs to your own backend over HTTPS with the secret; it marks
processed threads `tasks-done` so they are never re-imported. Failed posts stay
labelled and retry on the next run.

## 4. Switching to SendGrid / Mailgun later

Point their Inbound Parse / Route at the same webhook. Add the secret to the
webhook URL (SendGrid) or add HMAC signature verification in `inbound.go`
(Mailgun) — the form-field parsing already handles both providers' field names.
