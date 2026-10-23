# Noridoc: mailers

Path: @/app/mailers

### Overview
- All outbound email (app mailers and Devise) is delivered through Resend's HTTP API via the `resend` gem, and inherits sender defaults from [@/app/mailers/application_mailer.rb](application_mailer.rb).
- `NewsletterMailer` sends the double opt-in confirmation link for the newsletter. The newsletters themselves are not sent by the app; they are Resend Broadcasts written and sent from the Resend dashboard.

### How it fits into the larger codebase
- Production config in [@/config/environments/production.rb](../../config/environments/production.rb): `delivery_method = :resend`, `raise_delivery_errors = true`, and `default_url_options` of `christopherquentin.com` over https. The previous `example.com` host produced broken Devise password reset links. `Resend.api_key` is set from `ENV["RESEND_API_KEY"]` in [@/config/initializers/resend.rb](../../config/initializers/resend.rb).
- `ApplicationMailer` defaults `from` to `Christopher Quentin <hello@send.christopherquentin.com>` (the `send.` subdomain is the domain verified in Resend) and `reply_to` to a real Gmail inbox, because the send subdomain has no mailbox.
- Devise mail picks up the same defaults because [@/config/initializers/devise.rb](../../config/initializers/devise.rb) sets `parent_mailer = "ApplicationMailer"`; Devise's `headers_for` defers to the parent mailer's defaults. `mailer_sender` is also set to the same address.
- Devise mail is queued, not sent inline: `User#send_devise_notification` in [@/app/models/user.rb](../models/user.rb) calls `deliver_later`. The `resend` gem's HTTParty calls have no timeout, so inline delivery let a slow or failing Resend hang or 500 requests such as password resets.
- The newsletter flow spans [@/app/controllers](../controllers) (signup and confirmation endpoints, see [@/app/controllers/docs.md](../controllers/docs.md)), [@/app/models/newsletter_subscriber.rb](../models/newsletter_subscriber.rb), this folder, and the Resend sync jobs in [@/app/jobs](../jobs).

### Core Implementation

```
signup form ──> NewsletterSubscribersController#create
                  └─ subscriber.send_confirmation ──> NewsletterMailer.confirmation (token link)
                     (any address, confirmed or not; skipped if one was sent in the last hour)
email link  ──> GET  /newsletter/confirm/:token  (button page, no state change)
button      ──> POST /newsletter/confirm/:token
                  └─ subscriber.confirm! ──> ResendNewsletterSyncJob ──> Resend contact + segment
Resend dashboard: Broadcast to segment; unsubscribes handled by Resend
admin delete (confirmed only) ──> ResendNewsletterRemoveJob ──> remove from segment
rake newsletter:resync ──> ResendNewsletterSyncJob for every confirmed subscriber
```

- `NewsletterSubscriber` normalizes `email` (strip, downcase), tracks `confirmed_at` and `confirmation_sent_at`, and declares `generates_token_for :confirmation, expires_in: 14.days` with `confirmed_at` embedded in the token. The token therefore stops resolving once the subscriber is confirmed (single use) or after 14 days.
- Besides the standard email format, `email` must not contain `/ ? # % \`. The address is interpolated as a URL path segment in Resend API calls and the gem does not escape it.
- `send_confirmation(deliver:)` sends the mail (default `deliver_later`) and stamps `confirmation_sent_at`; `confirmation_recently_sent?` is true when that stamp is within the last hour, which the signup controller uses as a per-address send cap. `confirm!` stamps `confirmed_at` and enqueues `ResendNewsletterSyncJob` with the email string. Because a confirmed subscriber can request a new link, `confirm!` can run again for an already-confirmed row (the token embeds `confirmed_at`, so each link is still single use), and each run re-syncs to Resend.
- `NewsletterMailer#confirmation` builds `newsletter_confirmation_url(token)`; the absolute URL relies on `default_url_options`.
- Rake tasks in [@/lib/tasks/newsletter.rake](../../lib/tasks/newsletter.rake), run in production with `railway ssh -- ./bin/rails <task>`:

| Task | Behavior |
|---|---|
| `newsletter:send_confirmations` | One-time backfill for subscribers who existed before double opt-in. Emails every unconfirmed subscriber with no `confirmation_sent_at`, delivering synchronously with 0.25s between sends. A `Resend::Error::RateLimitExceededError` sleeps `retry_after` (or 1s) and retries, up to 3 attempts; any other `Resend::Error` is logged to stderr and the loop continues. Prints `Sent N confirmation emails, M failed.` Because only successful sends stamp `confirmation_sent_at`, rerunning it retries just the failures. |
| `newsletter:resync` | Enqueues `ResendNewsletterSyncJob` for every confirmed subscriber. This is the recovery path for sync jobs lost by the `:async` adapter on deploy/restart (see [@/app/jobs/docs.md](../jobs/docs.md)); the sync job is safe to repeat. |

### Things to Know
- Resend, not the app database, is the source of truth for who receives newsletters. Unsubscribes happen in Resend and are not mirrored back; a local subscriber row can remain `confirmed` after the person unsubscribed in Resend. To re-subscribe, the person signs up again and clicks the new confirmation link; signup alone never re-syncs a confirmed address, so a third party cannot undo someone's Resend unsubscribe.
- Unconfirmed subscribers never reach Resend. Sending broadcasts to unconfirmed addresses risks spam complaints against the sending domain.
- The admin subscriber list shows a Confirmed/Pending badge per row.
- Tests: `webmock` blocks real network calls and stubs `api.resend.com`. [@/test/test_helper.rb](../../test/test_helper.rb) sets `Resend.api_key` and `RESEND_NEWSLETTER_SEGMENT_ID` directly after the app boots, because `bin/rails test` loads the app before `test_helper`, so ENV set there is too late for initializers. `NewsletterHelper` extracts the confirmation link from the delivered email's text part so tests follow the same link a user would. The rake task tests switch `ActionMailer::Base.delivery_method` to the real `:resend` method and stub `POST https://api.resend.com/emails`, so the error and 429 handling are exercised against the gem's actual exceptions. Devise mail tests assert enqueued emails and then `perform_enqueued_jobs`.

Created and maintained by Nori.
