# Noridoc: jobs

Path: @/app/jobs

### Overview
- Background jobs that keep the Resend newsletter segment in sync with subscriber confirmations and admin deletions. The overall newsletter flow is described in [@/app/mailers/docs.md](../mailers/docs.md).

### How it fits into the larger codebase
- `ResendNewsletterSyncJob` is enqueued with the email string (not the record) by `NewsletterSubscriber#confirm!` in [@/app/models/newsletter_subscriber.rb](../models/newsletter_subscriber.rb) and by the `newsletter:resync` rake task in [@/lib/tasks/newsletter.rake](../../lib/tasks/newsletter.rake). The `newsletter:import_existing` rake task in the same file does not enqueue it; it calls `ResendNewsletterSyncJob.new.perform(email)` inline, because the rake process exits before `:async` jobs or their retries would run, and it sets `confirmed_at` only after that call succeeds. The job's `retry_on` does not apply to an inline `perform`, so the task does its own 429 retry. `ResendNewsletterRemoveJob` is enqueued by `Admin::NewsletterSubscribersController#destroy` in [@/app/controllers/admin](../controllers/admin), only for confirmed subscribers, with the email string (the record is already destroyed).
- The segment id comes from `ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID")`, so a missing variable raises inside the job rather than silently skipping. The API key is set in [@/config/initializers/resend.rb](../../config/initializers/resend.rb).
- Production uses the `:async` Active Job adapter ([@/config/environments/production.rb](../../config/environments/production.rb)), which runs jobs in-process; jobs in flight during a deploy or restart are lost, including pending retries. Deliveries via `deliver_later` (newsletter confirmations and Devise mail) run on the same adapter. `bin/rails newsletter:resync` re-enqueues the sync job for every confirmed subscriber to recover lost syncs.

### Core Implementation
- `ResendNewsletterSyncJob` GETs the contact by email. If it exists, it PATCHes `unsubscribed: false` and adds it to the segment; if Resend raises `Resend::Error::NotFoundError`, it creates the contact with `unsubscribed: false` and `segments: [{ id: segment_id }]`. Re-confirming therefore resubscribes a contact that had previously unsubscribed in Resend.
- The sync job converges to the same end state however many times it runs, which is what makes `newsletter:resync` and repeated confirmations safe.
- `ResendNewsletterRemoveJob` removes the email from the segment; it does not delete the Resend contact. It `discard_on Resend::Error::NotFoundError`, since a contact or membership that is already gone needs no removal.
- Both jobs `retry_on` (polynomial backoff, 10 attempts) only transient failures:

| Retried | Why |
|---|---|
| `Resend::Error::RateLimitExceededError` | 429 |
| `Resend::Error::InternalServerError` | 500s, and non-JSON responses such as a proxy's 502 HTML page |
| `Net::OpenTimeout`, `Net::ReadTimeout`, `SocketError`, `Errno::ECONNREFUSED`, `Errno::ECONNRESET` | Network failures |

- Other `Resend::Error::ServerError` subclasses are intentionally not retried: the gem classifies permanent 4xx responses (401, 404, 422) under `ServerError`, so retrying the parent class would retry errors that can never succeed.

### Things to Know
- The `resend` gem decides whether a response is an error from the `statusCode` field in the JSON body, not the HTTP status. Test stubs for error responses must include it, e.g. `{"statusCode":404,"message":"Contact not found","name":"not_found"}` (the shape the real API returns), or the gem treats the response as success.

Created and maintained by Nori.
