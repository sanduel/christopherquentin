# Noridoc: controllers

Path: @/app/controllers

### Overview
- Public-facing controllers for the memorial site (tributes, timeline memories and replies, tree/bee hive/recipe/photo submissions, newsletter sign-up), plus an `admin` namespace for moderation and a `users` namespace for Devise overrides.
- [@/app/controllers/application_controller.rb](application_controller.rb) holds cross-cutting behavior: Devise permitted params (`:name` on sign-up and account update) and the `protect_from_spam` anti-spam class macro.

### How it fits into the larger codebase
- Anonymous submissions are created with status `pending` and surface in the admin moderation queue under [@/app/controllers/admin](admin); public views only read `published` records (e.g. `Memory.published` in [@/app/controllers/memories_controller.rb](memories_controller.rb)).
- Devise is routed through a custom registrations controller: `devise_for :users, controllers: { registrations: "users/registrations" }` in [@/config/routes.rb](../../config/routes.rb). [@/app/controllers/users/registrations_controller.rb](users/registrations_controller.rb) subclasses `Devise::RegistrationsController` only to apply `protect_from_spam`; the sign-up view is still the app's [@/app/views/devise/registrations/new.html.erb](../views/devise/registrations/new.html.erb).
- Rate-limit counters live in `Rails.cache` (Solid Cache in production per [@/config/environments/production.rb](../../config/environments/production.rb)), so limits are shared across Puma workers and survive restarts. The production cache database shares the primary database, so `db:prepare` never loads `db/cache_schema.rb`; the `solid_cache_entries` table is created by a regular primary migration instead. Without it every `Rails.cache` call raises.
- Honeypot names are fixed in the initializer. The gem's default is random per process, which would let forms rendered before a deploy or restart through unchecked.
- Rate limiting keys on `request.remote_ip`, which depends on the `trusted_proxies` setting in [@/config/application.rb](../../config/application.rb) (see Things to Know).
- The honeypot comes from the `invisible_captcha` gem, configured in [@/config/initializers/invisible_captcha.rb](../../config/initializers/invisible_captcha.rb).

### Core Implementation

**Anti-spam macro.** `ApplicationController.protect_from_spam(limit:, within:)` installs two `:create`-only guards:

| Guard | Mechanism | Rejection |
|---|---|---|
| Rate limit | Rails 8 `rate_limit to: limit, within: within`, keyed by `request.remote_ip` (the Rails default) | `reject_rate_limited` |
| Honeypot | `invisible_captcha only: :create` (with `on_spam` and `on_timestamp_spam` pointed at the same handler) | `reject_spam` |

Both handlers `redirect_back` (fallback `root_path`) with status `303 See Other` and a flash `alert`. A redirect is required because forms submit via Turbo; the gem's default response (`head 200`) would leave Turbo with nothing to render.

**Where it is applied.** Every public `create` endpoint calls the macro at class level:

| Endpoint group | Limit |
|---|---|
| Tributes, memories, replies, trees, recipes, gallery (`POST /submit-photos`), bee hives | 10 per 10 minutes |
| Newsletter subscribers | 5 per 10 minutes |
| Devise sign-up (`Users::RegistrationsController`) | 3 per hour |

The `admin` namespace is not covered; `Admin::BaseController` inherits from `ApplicationController` but never calls the macro.

**View side.** Each public form renders `<%= invisible_captcha %>` inside the form element. This includes forms that appear on many pages (the newsletter form in the site footer partial and the share modal), the reply composer on the timeline, the tree form partial embedded on the projects page, each `new` submission page, and the Devise registration page. The honeypot check only works when the helper is rendered in the form that posts to a protected action.

**Newsletter double opt-in.** Signing up does not subscribe anyone; it only sends a confirmation email. The full lifecycle (model, mailer, Resend sync) is described in [@/app/mailers/docs.md](../mailers/docs.md); the controller side is:

| Step | Controller | Behavior |
|---|---|---|
| `POST /newsletter_subscribers` | [@/app/controllers/newsletter_subscribers_controller.rb](newsletter_subscribers_controller.rb) | `find_or_initialize_by(email:)` and save. Every address, new, pending, or already confirmed, is sent a confirmation link via `send_confirmation`, unless `confirmation_recently_sent?` (a link went out within the last hour, per `confirmation_sent_at`). All success paths, including a rescued `ActiveRecord::RecordNotUnique` from a concurrent double submit, redirect with the same "check your email" notice. |
| `GET /newsletter/confirm/:token` | [@/app/controllers/newsletter_confirmations_controller.rb](newsletter_confirmations_controller.rb) `#show` | Renders a page with a "Confirm subscription" button. Does not change state. |
| `POST /newsletter/confirm/:token` | same, `#create` | Calls `confirm!` and renders `confirmed`. |
| Invalid/expired/used token (either verb) | `set_subscriber` `before_action` | Renders `expired` with status 404. |
| Admin delete | [@/app/controllers/admin/newsletter_subscribers_controller.rb](admin/newsletter_subscribers_controller.rb) `#destroy` | Destroys the row and, only if it was confirmed, enqueues `ResendNewsletterRemoveJob` to drop the address from the Resend segment. Each row in the admin list carries a `dom_id(subscriber)` id, which tests use to target a specific row. |

### Things to Know
- The identical signup response for new, pending, and confirmed addresses exists so the form cannot be used to discover who is on the list. Bots submitting real people's addresses was the motivation for double opt-in.
- The one-email-per-hour-per-address cap on signup stops the form from being used to mail-bomb a victim; the per-IP rate limit alone would still allow repeated emails to one address. It applies to confirmed addresses too.
- Confirmed addresses are emailed (rather than skipped) so someone who unsubscribed in Resend, or whose Resend sync was lost, can re-subscribe: clicking the link runs `confirm!` again, which re-enqueues the Resend sync. Signup deliberately never re-syncs a confirmed address without that click, since doing so would let anyone undo another person's Resend unsubscribe.
- Confirmation is split into GET (show button) and POST (confirm) because email link scanners such as Outlook Safe Links prefetch every link in incoming mail; a confirming GET would let them confirm addresses that bots signed up. `NewsletterConfirmationsController` does not call `protect_from_spam`; the signed, expiring token is the only gate.
- Adding a new public form requires both halves: `protect_from_spam` in the controller and `invisible_captcha` in the form. The integration tests in [@/test/integration/anti_spam_test.rb](../../test/integration/anti_spam_test.rb) and [@/test/integration/rate_limit_test.rb](../../test/integration/rate_limit_test.rb) are table-driven; a new endpoint is covered by adding an entry to their tables.
- invisible_captcha's timestamp and spinner checks are intentionally disabled. Both store per-session state that is rewritten each time any protected form renders. Because the footer newsletter form and the share modal render on every page, and Turbo 8 prefetches pages on link hover, hovering a link or opening another tab overwrote that state and caused real visitors' submissions to be rejected. The design is honeypot-only plus per-IP rate limits.
- `request.remote_ip` is only correct because `100.64.0.0/10` (Railway's edge proxy, carrier-grade NAT shared address space) is added to `ActionDispatch::RemoteIp::TRUSTED_PROXIES`. The production path is Railway edge -> Thruster (with `FORWARD_HEADERS` on, since TLS terminates at the edge; it appends the edge hop to `X-Forwarded-For`) -> Puma on localhost. Without trusting that range, `remote_ip` resolved to a `100.64.0.x` proxy address and every visitor shared a single rate-limit bucket. The setting affects `remote_ip` everywhere in the app, not just rate limiting.
- Signed-in users bypass moderation: `MemoriesController#create` and `RepliesController#create` set `status` to `published` when `user_signed_in?`. Sign-up is intentionally left open, so an account that gets past the sign-up honeypot and rate limit can publish memories and replies directly without entering the moderation queue.
- In `RepliesController`, the `set_memory` `before_action` is declared before `protect_from_spam`, so the parent memory lookup runs before the rate-limit and honeypot callbacks.
- Rate limiting is a no-op on `:null_store`, so the test environment uses `:solid_cache_store`, the same store as production, so a missing cache table fails tests ([@/config/environments/test.rb](../../config/environments/test.rb)) and `ActiveSupport::TestCase` clears `Rails.cache` in `setup` so counters do not leak between tests. `AntiSpamHelper` in [@/test/test_helper.rb](../../test/test_helper.rb) extracts a form's honeypot field names and its hidden fields so tests can submit exactly what the rendered form would. Rate-limit tests simulate separate visitors behind the same proxy with `X-Forwarded-For: "<client>, 100.64.0.5"`.

Created and maintained by Nori.
