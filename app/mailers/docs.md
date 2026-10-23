# Noridoc: mailers

Path: @/app/mailers

### Overview
- All outbound email (app mailers and Devise) is delivered through Resend's HTTP API via the `resend` gem, and inherits sender defaults from [@/app/mailers/application_mailer.rb](application_mailer.rb).
- `NewsletterMailer` sends the double opt-in confirmation link for the newsletter. The newsletters themselves are not sent by the app; they are Resend Broadcasts written and sent from the Resend dashboard.

### How it fits into the larger codebase
- Production config in [@/config/environments/production.rb](../../config/environments/production.rb): `delivery_method = :resend`, `raise_delivery_errors = true`, and `default_url_options` of `christopherquentin.com` over https. The previous `example.com` host produced broken Devise password reset links. `Resend.api_key` is set from `ENV["RESEND_API_KEY"]` in [@/config/initializers/resend.rb](../../config/initializers/resend.rb).
- `ApplicationMailer` defaults `from` to `Christopher Quentin <hello@send.christopherquentin.com>` (the `send.` subdomain is the domain verified in Resend) and `reply_to` to a real Gmail inbox, because the send subdomain has no mailbox.
- Devise mail picks up the same defaults because [@/config/initializers/devise.rb](../../config/initializers/devise.rb) sets `parent_mailer = "ApplicationMailer"`; Devise's `headers_for` defers to the parent mailer's defaults. `mailer_sender` is also set to the same address.
- The newsletter flow spans [@/app/controllers](../controllers) (signup and confirmation endpoints, see [@/app/controllers/docs.md](../controllers/docs.md)), [@/app/models/newsletter_subscriber.rb](../models/newsletter_subscriber.rb), this folder, and the Resend sync jobs in [@/app/jobs](../jobs).

### Core Implementation

```
signup form ──> NewsletterSubscribersController#create
                  └─ subscriber.send_confirmation ──> NewsletterMailer.confirmation (token link)
email link  ──> GET  /newsletter/confirm/:token  (button page, no state change)
button      ──> POST /newsletter/confirm/:token
                  └─ subscriber.confirm! ──> ResendNewsletterSyncJob ──> Resend contact + segment
Resend dashboard: Broadcast to segment; unsubscribes handled by Resend
admin delete (confirmed only) ──> ResendNewsletterRemoveJob ──> remove from segment
```

- `NewsletterSubscriber` normalizes `email` (strip, downcase), tracks `confirmed_at` and `confirmation_sent_at`, and declares `generates_token_for :confirmation, expires_in: 14.days` with `confirmed_at` embedded in the token. The token therefore stops resolving once the subscriber is confirmed (single use) or after 14 days.
- `send_confirmation(deliver:)` sends the mail (default `deliver_later`) and stamps `confirmation_sent_at`. `confirm!` stamps `confirmed_at` and enqueues `ResendNewsletterSyncJob`.
- `NewsletterMailer#confirmation` builds `newsletter_confirmation_url(token)`; the absolute URL relies on `default_url_options`.
- [@/lib/tasks/newsletter.rake](../../lib/tasks/newsletter.rake) `newsletter:send_confirmations` is a one-time backfill for subscribers who existed before double opt-in: it emails every unconfirmed subscriber with no `confirmation_sent_at`, delivering synchronously and sleeping 0.25s between sends to stay under Resend's rate limit. Because it stamps `confirmation_sent_at`, rerunning it is idempotent. It is run in production with `railway ssh -- ./bin/rails newsletter:send_confirmations`.

### Things to Know
- Resend, not the app database, is the source of truth for who receives newsletters. Unsubscribes happen in Resend and are not mirrored back; a local subscriber row can remain `confirmed` after the person unsubscribed in Resend.
- Unconfirmed subscribers never reach Resend. Sending broadcasts to unconfirmed addresses risks spam complaints against the sending domain.
- The admin subscriber list shows a Confirmed/Pending badge per row.
- Tests: `webmock` blocks real network calls and stubs `api.resend.com`. [@/test/test_helper.rb](../../test/test_helper.rb) sets `Resend.api_key` and `RESEND_NEWSLETTER_SEGMENT_ID` directly after the app boots, because `bin/rails test` loads the app before `test_helper`, so ENV set there is too late for initializers. `NewsletterHelper` extracts the confirmation link from the delivered email's text part so tests follow the same link a user would.

Created and maintained by Nori.
