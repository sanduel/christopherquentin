# Phase 3 — Garden redesign: Timeline + Share-a-Memory

**Status:** Draft, awaiting user review
**Author:** Claude (Opus 4.7)
**Date:** 2026-06-17
**Branch:** `worktree-feature+garden-redesign`
**Source brief:** `/tmp/chris-inspo/design_handoff_chris_memorial/directions/garden.jsx` + handoff README
**Builds on:** Phase 1 (foundation), Phase 2 (homepage)

## Scope

Phase 3 ships three coupled things:

1. **Memory schema migration** — adds the fields the handoff data shape requires (`name`, `relationship`, `email`, `kind` enum, audio attachment + label + length) and a new `Reply` table.
2. **Timeline page** — full chronological view at `/timeline` with year-spine, alternating left/right cards, year-filter chip row, and audio playback for audio-type memories.
3. **Share-a-Memory modal** — two-step submission flow that opens via JS on any "Share a memory" button, supports anonymous submissions (queued for moderation) and signed-in submissions (published immediately), with photo and audio attachments.

Replies (visitor responses nested under a memory) are part of the Memory data model but render only minimally in this phase — a simple inline reply form per memory card. The full reply UX (rich replies, threading) is out of scope.

## Out of scope

- Phase 4 inner pages (Biography, Tributes, Trees, News, Recipes).
- Email notifications to anonymous submitters when their memory is approved/rejected (would need Action Mailer setup — separate task).
- Admin UI for reply moderation (admin/memories already exists; replies inherit the same model-level moderation but won't get an admin index view in Phase 3).
- Real-time updates (a published memory doesn't show on connected users' timelines until they refresh).
- Audio waveform pre-extraction (we lean on wavesurfer.js to decode at playback time).

## Locked-in decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Schema scope | Full handoff shape — `name`, `relationship`, `email`, `kind` enum, audio fields, replies table |
| Audio library | wavesurfer.js 7.x pinned via importmap |
| Modal pattern | Stimulus controller + native `<dialog>` element; `/timeline/new` direct URL also works (opens modal pre-loaded) |
| JS stack | Stimulus + Hotwire only (carry-over from Phase 1 decision) |
| Email collection | Required for anonymous; optional for signed-in (User already has one) |
| Reply moderation | Same as memories — anonymous → pending, signed-in → published |
| Year/age derivation | Derived from `date` and a hardcoded `Memory::CHRIS_BIRTH_YEAR = 1984` constant. No column. |

## Schema migration

One migration: `db/migrate/<timestamp>_phase_3_memory_and_replies.rb`.

```ruby
class Phase3MemoryAndReplies < ActiveRecord::Migration[8.1]
  def change
    # Memory: add submitter contact fields + kind enum + audio metadata
    add_column :memories, :name,            :string
    add_column :memories, :relationship,    :string
    add_column :memories, :email,           :string
    add_column :memories, :kind,            :integer, default: 0, null: false
    add_column :memories, :audio_label,     :string
    add_column :memories, :audio_length,    :string

    add_index :memories, :kind

    # Memory `title` becomes optional — handoff doesn't use titles.
    change_column_null :memories, :title, true

    # Replies table
    create_table :replies do |t|
      t.references :memory,           null: false, foreign_key: true, index: true
      t.references :user,             foreign_key: true, index: true  # nullable for anonymous
      t.string  :name,                null: false
      t.string  :relationship
      t.string  :email
      t.text    :body,                null: false
      t.integer :status,              default: 0, null: false  # pending/published/rejected
      t.index   [:status, :created_at]
      t.timestamps
    end
  end
end
```

**Backfill (post-migrate):** existing memories get `name` set to `user.name || "Anonymous"`, `kind` defaulted to `text` (0) unless `photos.attached?` in which case `photo` (1). Done in a separate `db/migrate/<timestamp+1>_backfill_memory_name_and_kind.rb` migration so the schema change is a separate, reversible step from the data change.

```ruby
class BackfillMemoryNameAndKind < ActiveRecord::Migration[8.1]
  def up
    Memory.find_each do |m|
      m.update_columns(
        name: m.user&.name || "Anonymous",
        kind: m.photos.attached? ? 1 : 0
      )
    end
  end

  def down
    # no-op — name/kind columns were nullable defaults before
  end
end
```

## Memory model changes

```ruby
class Memory < ApplicationRecord
  CHRIS_BIRTH_YEAR = 1984

  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :kind,   { text: 0, photo: 1, audio: 2 }, prefix: :kind  # `m.kind_audio?` etc.

  belongs_to :user, optional: true
  has_many   :replies, -> { published.order(:created_at) }, dependent: :destroy
  has_many_attached :photos
  has_one_attached  :audio_clip

  geocoded_by :location
  after_validation :geocode, if: ->(m) { m.location_changed? && m.location.present? && m.latitude.blank? }

  validates :date,    presence: true
  validates :content, presence: true, unless: -> { kind_photo? || kind_audio? }
  validates :name,    presence: true, if: -> { user_id.blank? }
  validates :email,   presence: true, format: URI::MailTo::EMAIL_REGEXP, if: -> { user_id.blank? }
  validate  :audio_clip_required_if_kind_audio
  validate  :photos_required_if_kind_photo

  # Derived
  def year = date.year
  def age  = year - CHRIS_BIRTH_YEAR
  def display_name = name.presence || user&.name || "Anonymous"
  def display_relationship = relationship.presence

  def self.default_pin_color = "#3a5240"      # moss (was amber-600)
  def self.default_pin_icon  = "star"
  def self.map_category      = :memory

  private

  def audio_clip_required_if_kind_audio
    return unless kind_audio?
    errors.add(:audio_clip, "is required for audio memories") unless audio_clip.attached?
  end

  def photos_required_if_kind_photo
    return unless kind_photo?
    errors.add(:photos, "is required for photo memories") unless photos.attached?
  end
end
```

Notable: `prefix: :kind` on the enum gives `m.kind_text?`, `m.kind_photo?`, `m.kind_audio?` to disambiguate from the existing `published?` / `pending?` predicates. The default-pin-color also moves from amber to moss to match the redesign.

## Reply model

```ruby
class Reply < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :memory
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :body, presence: true
  validates :email, presence: true, format: URI::MailTo::EMAIL_REGEXP, if: -> { user_id.blank? }

  scope :published, -> { where(status: :published) }
end
```

## Controllers

### MemoriesController

```ruby
class MemoriesController < ApplicationController
  # Drop the before_action :authenticate_user! — anonymous submissions allowed
  # with moderation.

  def index
    scope = Memory.published.includes(:user, :replies).order(date: :desc)
    @years = Memory.published.pluck(:date).map(&:year).uniq.sort.reverse
    @active_year = params[:year]&.to_i
    @memories = @active_year ? scope.where("strftime('%Y', date) = ?", @active_year.to_s) : scope
    @memories_count = @memories.count
    @contributors_count = User.joins(:memories).distinct.count + Memory.where(user_id: nil).select(:email).distinct.count
  end

  def show
    @memory = Memory.published.find(params[:id])
  end

  def new
    @memory = Memory.new(kind: :text)
    # Renders the modal pre-opened via a hidden body attribute. (Detail in view layer.)
  end

  def create
    @memory = Memory.new(memory_params)
    @memory.user = current_user if user_signed_in?
    @memory.status = user_signed_in? ? :published : :pending
    @memory.name = current_user.name if user_signed_in? && @memory.name.blank?

    if @memory.save
      msg = user_signed_in? ?
        "Memory shared — it's live on the timeline now." :
        "Thank you. Your memory is queued for review and will appear on the timeline once approved."
      redirect_to memories_path, notice: msg
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def memory_params
    params.require(:memory).permit(
      :date, :title, :content, :location,
      :name, :relationship, :email,
      :kind, :audio_label, :audio_length,
      :audio_clip,
      photos: []
    )
  end
end
```

The year-filter query uses `strftime` (SQLite-compatible). If production switches to Postgres, swap to `EXTRACT(year FROM date) = ?`. The plan phase will confirm `config/database.yml` and adapt.

### RepliesController (new)

```ruby
class RepliesController < ApplicationController
  before_action :set_memory

  def create
    @reply = @memory.replies.build(reply_params)
    @reply.user = current_user if user_signed_in?
    @reply.status = user_signed_in? ? :published : :pending
    @reply.name = current_user.name if user_signed_in? && @reply.name.blank?

    if @reply.save
      redirect_to memory_path(@memory),
        notice: user_signed_in? ? "Reply posted." : "Thanks. Your reply will appear after review."
    else
      redirect_to memory_path(@memory), alert: @reply.errors.full_messages.join(", "), status: :unprocessable_entity
    end
  end

  private

  def set_memory
    @memory = Memory.published.find(params[:memory_id])
  end

  def reply_params
    params.require(:reply).permit(:name, :relationship, :email, :body)
  end
end
```

### Routes (additions)

```ruby
resources :memories, only: [:index, :new, :create, :show], path: "timeline" do
  resources :replies, only: [:create]
end
```

(The existing `resources :memories` block expands to nest replies under it. URL becomes `POST /timeline/:memory_id/replies`.)

## Timeline page — `/timeline`

The redesign of `app/views/memories/index.html.erb`.

### Layout (desktop)

- **Header** (cream background, page padding):
  - Mono eyebrow: `Op. III · The Timeline`
  - Cormorant h1: `A life, kept by many hands.` (matches MVT II homepage h2 — intentional echo)
  - Subtitle: `<count> memories · <contributors> contributors`
  - Primary CTA: `Share a memory` (moss pill, opens modal)

- **Year filter chip row** (sticky just below the nav, cream/blur):
  - Renders one chip per year present in `@years`, sorted descending (most recent first).
  - One `All` chip at the start.
  - Active chip: `bg-moss text-cream`. Inactive: `border border-ink/20 text-ink hover:border-moss`.
  - Clicking a chip submits a GET with `?year=2014` (Turbo navigation, full page replacement — simple).

- **Year markers + spine**:
  - Vertical 2px gradient `from-cream via-sage/40 to-cream` line center, full page height.
  - Year markers rendered as h2 anchored to the spine: each unique year in the current filter gets its own marker (`<h2 class="font-serif text-[64px]">2014<br><span class="text-eyebrow mt-2 block">he was 30</span></h2>`).
  - Between year markers, the memory cards.

- **Memory cards** (alternating left/right of spine):
  - 480px wide.
  - Each card has a small 12px leaf-node circle on the spine, with a dashed connector to the card.
  - Three variants:
    - **Text** — Cormorant body in quotation marks, meta footer.
    - **Photo** — top photo slot (real image via `image_tag memory.photos.first` if attached; placeholder gradient otherwise) with caption, then body, then meta footer.
    - **Audio** — moss-colored header strip with play button, italic title, waveform bars (rendered by wavesurfer.js into a `<div data-controller="audio-player">`), duration label. Body and meta in the card body below.
  - All cards have: date+location eyebrow, body, footer with `display_name` (medium DM Sans), `display_relationship` (small sage), and `↩ Reply` outline pill.
  - Reply chains render as smaller linen-background blocks below the footer. Inline reply composer appears when `↩ Reply` is clicked (Stimulus toggle).

- **Empty state** (filter has no memories):
  - "No memories for <year>" line in italic Cormorant
  - `Clear filter →` link

### Layout (mobile)

- Year filter chip row becomes horizontally scrollable.
- Spine + alternating cards collapse to a single left-aligned column. Cards stay 100% width.
- Year markers stack inline above the year's first card.
- Reply composer takes the full card width.

### Partials

```
app/views/memories/
├── index.html.erb               (rewritten — header + year filter + spine + cards)
├── show.html.erb                (rewritten — single memory + replies)
├── new.html.erb                 (rewritten — opens modal)
├── _memory_card.html.erb        (delegates to kind-specific partial)
├── _text_card.html.erb
├── _photo_card.html.erb
├── _audio_card.html.erb
├── _reply.html.erb              (renders one published reply)
├── _reply_composer.html.erb     (inline form, hidden until Reply button clicked)
├── _year_marker.html.erb
└── _year_filter.html.erb
```

The existing `_memory_card.html.erb` (probably stubbed) gets rebuilt as a dispatcher.

## Share-a-Memory modal

### Markup

The modal is a `<dialog>` element rendered once in `application.html.erb` (right before `</body>`), kept hidden by default:

```erb
<%= render "shared/share_modal" %>
```

The modal partial structure:

```erb
<dialog id="share-modal"
        data-controller="share-modal"
        data-share-modal-current-step-value="1"
        class="rounded-lg bg-cream max-w-[640px] w-[92vw] p-0 backdrop:bg-ink/40">
  <%= form_with model: Memory.new, url: memories_path, multipart: true, data: { share_modal_target: "form" } do |f| %>
    <header class="px-8 pt-7 pb-4 border-b border-ink/8">
      <div class="text-eyebrow text-sage" data-share-modal-target="stepLabel">Step 1 of 2 · The memory</div>
      <div class="h-1 bg-ink/8 mt-2 rounded-full overflow-hidden">
        <div class="h-full bg-moss transition-all duration-300" style="width: 50%" data-share-modal-target="progress"></div>
      </div>
    </header>

    <div data-share-modal-target="step1" class="p-8 space-y-6">
      <h2 class="font-serif text-4xl text-ink">Tell us about a <em class="text-moss">moment</em>.</h2>

      <div>
        <label class="text-eyebrow text-sage block mb-1">Your memory</label>
        <%= f.text_area :content, rows: 6, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none", placeholder: "A photo, a story, a recording — something specific you want to keep." %>
      </div>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="text-eyebrow text-sage block mb-1">When did it happen?</label>
          <%= f.date_field :date, required: true, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none" %>
        </div>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Where?</label>
          <%= f.text_field :location, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none", placeholder: "Stavanger, Norway" %>
        </div>
      </div>

      <div>
        <div class="text-eyebrow text-sage mb-2">Attach (optional)</div>
        <div class="flex gap-3 flex-wrap">
          <label class="cursor-pointer border border-dashed border-ink/30 rounded-full px-4 py-2 text-sm hover:border-moss">
            Photo
            <%= f.file_field :photos, multiple: true, accept: "image/*", class: "hidden", data: { share_modal_target: "photoInput" } %>
          </label>
          <label class="cursor-pointer border border-dashed border-ink/30 rounded-full px-4 py-2 text-sm hover:border-moss">
            Audio clip
            <%= f.file_field :audio_clip, accept: "audio/*", class: "hidden", data: { share_modal_target: "audioInput" } %>
          </label>
        </div>
        <div data-share-modal-target="attachments" class="mt-3 text-sm text-sage"></div>
      </div>

      <%= f.hidden_field :kind, value: :text, data: { share_modal_target: "kindInput" } %>
    </div>

    <div data-share-modal-target="step2" hidden class="p-8 space-y-6">
      <h2 class="font-serif text-4xl text-ink">Who's <em class="text-moss">remembering</em>?</h2>

      <div class="grid grid-cols-2 gap-4">
        <div>
          <label class="text-eyebrow text-sage block mb-1">Your name</label>
          <%= f.text_field :name, value: current_user&.name, required: true, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none" %>
        </div>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Relationship to Chris</label>
          <%= f.text_field :relationship, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none", placeholder: "Friend · Colleague · Family · …" %>
        </div>
      </div>

      <% unless user_signed_in? %>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Email (kept private)</label>
          <%= f.email_field :email, required: true, class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none" %>
        </div>

        <div class="bg-moss/8 border border-moss/20 rounded-md p-4 text-sm text-ink">
          Signed-in users have their memories posted immediately. Anonymous submissions go to a moderation queue and appear after review.
        </div>
      <% end %>
    </div>

    <footer class="px-8 py-5 border-t border-ink/8 flex justify-between items-center">
      <button type="button" data-action="share-modal#close" class="text-sm text-ink/60 hover:text-moss">Cancel</button>

      <div class="flex gap-3">
        <button type="button" data-action="share-modal#back" data-share-modal-target="backButton" hidden class="text-sm text-ink/60 hover:text-moss px-4 py-2">← Back</button>
        <button type="button" data-action="share-modal#next" data-share-modal-target="nextButton" class="bg-moss text-cream rounded-full px-5 py-2.5 text-sm font-medium">Continue →</button>
        <button type="submit" data-share-modal-target="submitButton" hidden class="bg-moss text-cream rounded-full px-5 py-2.5 text-sm font-medium">Plant memory</button>
      </div>
    </footer>
  <% end %>
</dialog>
```

### Stimulus controller — `share_modal_controller.js`

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "step1", "step2", "stepLabel", "progress",
                    "backButton", "nextButton", "submitButton",
                    "photoInput", "audioInput", "kindInput", "attachments"]
  static values  = { currentStep: Number }

  connect() {
    this.photoInputTarget.addEventListener("change", () => this.handlePhotoSelect())
    this.audioInputTarget.addEventListener("change", () => this.handleAudioSelect())
  }

  open()  { this.element.showModal(); this.currentStepValue = 1 }
  close() {
    if (this.isDirty() && !confirm("Discard this memory?")) return
    this.element.close()
    this.formTarget.reset()
    this.attachmentsTarget.textContent = ""
    this.currentStepValue = 1
  }

  next() {
    if (!this.validateStep1()) return
    this.currentStepValue = 2
  }

  back() { this.currentStepValue = 1 }

  handlePhotoSelect() {
    const files = Array.from(this.photoInputTarget.files)
    if (files.length > 0) this.kindInputTarget.value = "photo"
    this.renderAttachments()
  }

  handleAudioSelect() {
    if (this.audioInputTarget.files.length > 0) this.kindInputTarget.value = "audio"
    this.renderAttachments()
  }

  renderAttachments() {
    const photoNames = Array.from(this.photoInputTarget.files).map(f => f.name)
    const audioName  = this.audioInputTarget.files[0]?.name
    const parts = []
    if (photoNames.length) parts.push(`Photos: ${photoNames.join(", ")}`)
    if (audioName)         parts.push(`Audio: ${audioName}`)
    this.attachmentsTarget.textContent = parts.join(" · ")
  }

  validateStep1() {
    const content = this.formTarget.querySelector("textarea[name='memory[content]']")
    const date    = this.formTarget.querySelector("input[name='memory[date]']")
    const hasAttachment = this.photoInputTarget.files.length > 0 || this.audioInputTarget.files.length > 0
    if (!hasAttachment && !content.value.trim()) {
      content.focus()
      return false
    }
    if (!date.value) { date.focus(); return false }
    return true
  }

  isDirty() {
    const fd = new FormData(this.formTarget)
    for (const [, v] of fd) if (v && v.toString().trim()) return true
    return false
  }

  currentStepValueChanged() {
    const step = this.currentStepValue
    this.step1Target.hidden = step !== 1
    this.step2Target.hidden = step !== 2
    this.stepLabelTarget.textContent = `Step ${step} of 2 · ${step === 1 ? "The memory" : "About you"}`
    this.progressTarget.style.width = `${step * 50}%`
    this.backButtonTarget.hidden    = step !== 2
    this.nextButtonTarget.hidden    = step === 2
    this.submitButtonTarget.hidden  = step !== 2
  }
}
```

### Opening the modal from a button anywhere

A small global `share-modal-trigger` Stimulus controller (or just `data-action` directly when a button is near the dialog) dispatches a custom event. The modal listens for the event and opens itself. Keeps coupling clean.

### Direct URL `/timeline/new`

When someone hits `/timeline/new` directly, the memories `new.html.erb` view renders the standard timeline page and includes a small auto-open Stimulus controller that fires on connect to call `showModal()` on the dialog.

## Audio playback — Stimulus controller

`audio_player_controller.js`:

```js
import WaveSurfer from "wavesurfer.js"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["waveform", "playButton", "duration"]
  static values  = { url: String }

  connect() {
    this.ws = WaveSurfer.create({
      container: this.waveformTarget,
      waveColor: "rgba(250,246,238,0.4)",       // cream at 40% opacity
      progressColor: "rgba(250,246,238,1)",     // cream
      cursorColor: "transparent",
      barWidth: 2,
      barGap: 2,
      barRadius: 0,
      height: 16,
      url: this.urlValue,
    })
    this.ws.on("finish", () => this.playButtonTarget.textContent = "▶")
  }

  toggle() {
    if (this.ws.isPlaying()) {
      this.ws.pause()
      this.playButtonTarget.textContent = "▶"
    } else {
      this.ws.play()
      this.playButtonTarget.textContent = "⏸"
    }
  }

  disconnect() {
    this.ws?.destroy()
  }
}
```

Importmap pin (in `config/importmap.rb`):

```ruby
pin "wavesurfer.js", to: "https://ga.jspm.io/npm:wavesurfer.js@7.10.0/dist/wavesurfer.esm.js"
```

## Homepage MVT II update

The Phase 2 `_preview_card.html.erb` infers kind from `memory.photos.attached?`. Update it to use the new `memory.kind` enum:

```erb
<% if memory.kind_photo? %> … photo slot … <% end %>
<% if memory.kind_audio? %> … audio slot stub (just an icon, no real player on homepage previews) … <% end %>
```

Audio cards on the homepage preview render a static "audio" badge — full playback is in the timeline card.

## Tests

- **Model tests:** Memory enum-kind dispatch, kind_audio/photo/text validations, derived `year`/`age`/`display_name`. Reply name + email validations. ~10 new tests.
- **Controller tests:** Memories#create with anonymous → pending status, signed-in → published status; #index with year filter. Replies#create with both auth states. ~6 new tests.
- **Integration tests:** Timeline page renders year filter chips; clicking a year filters; alternating cards render in correct kind variants; audio card has the audio-player controller; modal opens via "Share a memory" button on homepage; modal step 2 submission posts and redirects. ~10 new tests.

Total target: ~26 new tests on top of Phase 2's 121.

## Definition of done

- Migration runs cleanly forward and backward (`db:migrate` and `db:rollback`).
- Existing 121 tests still pass; ~26 new tests added.
- `/timeline` renders the redesigned page with year filter, spine, and varied card kinds (uses seeds to render at least one of each kind — seeds need to be expanded to include an audio memory if possible, or the audio card is exercised by tests only).
- `/timeline/new` redirects/loads with the modal open.
- "Share a memory" button on homepage opens the modal.
- Submitting the modal as anonymous queues the memory for moderation (status: pending, not visible on timeline).
- Submitting as signed-in publishes immediately.
- Reply composer on a memory card creates a reply (anonymous → pending, signed-in → published).
- Audio playback works in the browser (wavesurfer.js loads, plays, shows progress).
- No regressions on the homepage MVT II preview.
- Visual check at 1440 / 1024 / 768 / 375 px.

## Open questions

1. **Database**: the spec uses `strftime('%Y', date)` for the year-filter query, which is SQLite-only. The plan phase will check `config/database.yml`. If Postgres is used (now or later), the query swaps to `EXTRACT(year FROM date)`.
2. **Audio seed data**: should `db/seeds.rb` get an audio memory with a real audio file? Most pragmatic: skip — audio testing happens via attached files in tests. Real audio comes via the content pass.
3. **Anonymous email rate limiting / spam protection**: out of scope for Phase 3. The moderation queue is the last line of defense. If spam becomes a problem post-launch, a Rack::Attack rule on `POST /timeline` is a quick add.
4. **Reply notifications**: out of scope for Phase 3 (no Action Mailer setup). Admin notification of pending replies happens via the admin dashboard (already exists for memories — replies need to be added).
