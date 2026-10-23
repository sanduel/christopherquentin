# Noridoc: jobs

Path: @/app/jobs

### Overview
- Background jobs that keep the Resend newsletter segment in sync with subscriber confirmations and admin deletions. The overall newsletter flow is described in [@/app/mailers/docs.md](../mailers/docs.md).

### How it fits into the larger codebase
- `ResendNewsletterSyncJob` is enqueued by `NewsletterSubscriber#confirm!` in [@/app/models/newsletter_subscriber.rb](../models/newsletter_subscriber.rb). `ResendNewsletterRemoveJob` is enqueued by `Admin::NewsletterSubscribersController#destroy` in [@/app/controllers/admin](../controllers/admin), only for confirmed subscribers, with the email string (the record is already destroyed).
- The segment id comes from `ENV.fetch("RESEND_NEWSLETTER_SEGMENT_ID")`, so a missing variable raises inside the job rather than silently skipping. The API key is set in [@/config/initializers/resend.rb](../../config/initializers/resend.rb).
- Production uses the `:async` Active Job adapter ([@/config/environments/production.rb](../../config/environments/production.rb)), which runs jobs in-process; jobs in flight during a deploy or restart are lost. Deliveries via `deliver_later` run on the same adapter.

### Core Implementation
- `ResendNewsletterSyncJob` GETs the contact by email. If it exists, it PATCHes `unsubscribed: false` and adds it to the segment; if Resend raises `Resend::Error::NotFoundError`, it creates the contact with `unsubscribed: false` and `segments: [{ id: segment_id }]`. Re-confirming therefore resubscribes a contact that had previously unsubscribed in Resend.
- `ResendNewsletterRemoveJob` removes the email from the segment; it does not delete the Resend contact.
- Both jobs `retry_on Resend::Error::RateLimitExceededError` with polynomial backoff.

### Things to Know
- The `resend` gem decides whether a response is an error from the `statusCode` field in the JSON body, not the HTTP status. Test stubs for error responses must include it, e.g. `{"statusCode":404,"message":"Contact not found","name":"not_found"}` (the shape the real API returns), or the gem treats the response as success.

Created and maintained by Nori.
