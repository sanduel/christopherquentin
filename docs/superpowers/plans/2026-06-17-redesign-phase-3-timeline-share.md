# Phase 3: Timeline + Share-a-Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the chronological timeline page + the two-step Share-a-Memory modal + the Memory schema migration that supports them, including a Replies sub-feature.

**Architecture:** One schema migration + backfill expand the `memories` table and create a new `replies` table. The `Memory` model gains a `kind` enum (text/photo/audio), per-memory submitter fields (name/relationship/email), audio attachment, and `replies` association. Existing `MemoriesController` opens up to anonymous submissions (queued for moderation). A new `RepliesController` handles reply creation. The timeline page is rebuilt as a year-filtered chronological view with alternating cards rendered through kind-specific partials. A Stimulus-controlled `<dialog>` modal handles the multi-step share flow on any page. Audio playback uses wavesurfer.js pinned via importmap.

**Tech Stack:** Rails 8.1.2, SQLite (`strftime` for year extraction), Stimulus + Hotwire, native `<dialog>`, wavesurfer.js 7.x via importmap, Minitest.

**Spec:** `docs/superpowers/specs/2026-06-17-redesign-phase-3-timeline-share-design.md`

---

## Files touched in this phase

**Created:**
- `db/migrate/<ts1>_phase_3_memory_and_replies.rb`
- `db/migrate/<ts2>_backfill_memory_name_and_kind.rb`
- `app/models/reply.rb`
- `app/controllers/replies_controller.rb`
- `app/views/memories/_memory_card.html.erb`
- `app/views/memories/_text_card.html.erb`
- `app/views/memories/_photo_card.html.erb`
- `app/views/memories/_audio_card.html.erb`
- `app/views/memories/_reply.html.erb`
- `app/views/memories/_reply_composer.html.erb`
- `app/views/memories/_year_marker.html.erb`
- `app/views/memories/_year_filter.html.erb`
- `app/views/shared/_share_modal.html.erb`
- `app/javascript/controllers/share_modal_controller.js`
- `app/javascript/controllers/audio_player_controller.js`
- `app/javascript/controllers/auto_open_share_modal_controller.js`
- `test/models/reply_test.rb`
- `test/controllers/replies_controller_test.rb`
- `test/controllers/memories_controller_test.rb`
- `test/integration/timeline_test.rb`
- `test/integration/share_modal_test.rb`

**Modified:**
- `app/models/memory.rb` — enum, validations, associations, derived methods
- `app/controllers/memories_controller.rb` — drop authenticate_user!, branch on user_signed_in?, expand permitted params
- `app/views/memories/index.html.erb` — full rewrite (timeline page)
- `app/views/memories/show.html.erb` — light rewrite (use new fields)
- `app/views/memories/new.html.erb` — load timeline + auto-open modal
- `app/views/pages/home/_preview_card.html.erb` — use `kind` enum instead of `photos.attached?`
- `app/views/layouts/application.html.erb` — render share modal partial at bottom of body
- `config/routes.rb` — nest replies under memories
- `config/importmap.rb` — pin wavesurfer.js
- `db/seeds.rb` — backfill `name` and `kind` on the 3 seeded memories
- `test/models/memory_test.rb` — extend with new field tests

**Not touched:**
- Phase 1 chrome (`_home_nav`, `_site_footer`, `application.css`).
- Phase 4 inner pages (Biography, Tributes, Trees, News, Recipes).
- Admin namespace beyond what existing memory moderation already supports.

---

## Task 1: Schema migration + backfill

**Files:**
- Create: `db/migrate/<ts1>_phase_3_memory_and_replies.rb`
- Create: `db/migrate/<ts2>_backfill_memory_name_and_kind.rb`

This is the foundation. After this task the database has the new columns and table; existing Memory rows have sensible defaults backfilled.

- [ ] **Step 1: Generate the schema migration**

```bash
bin/rails generate migration phase_3_memory_and_replies
```

This creates `db/migrate/<timestamp>_phase_3_memory_and_replies.rb`. Replace its contents with:

```ruby
class Phase3MemoryAndReplies < ActiveRecord::Migration[8.1]
  def change
    # Memory: submitter contact fields + kind enum + audio metadata
    add_column :memories, :name,         :string
    add_column :memories, :relationship, :string
    add_column :memories, :email,        :string
    add_column :memories, :kind,         :integer, default: 0, null: false
    add_column :memories, :audio_label,  :string
    add_column :memories, :audio_length, :string

    add_index :memories, :kind

    # title becomes optional (handoff doesn't use it)
    change_column_null :memories, :title, true

    # Replies table — anonymous-friendly, moderated like memories
    create_table :replies do |t|
      t.references :memory, null: false, foreign_key: true, index: true
      t.references :user, foreign_key: true, index: true
      t.string  :name,         null: false
      t.string  :relationship
      t.string  :email
      t.text    :body,         null: false
      t.integer :status,       default: 0, null: false
      t.index   [:status, :created_at]
      t.timestamps
    end
  end
end
```

- [ ] **Step 2: Run the migration**

```bash
bin/rails db:migrate
```

Expected output: includes `add_column(:memories, :name, :string)`, `add_column(:memories, :kind, :integer, ...)`, `create_table(:replies, ...)`. No errors.

- [ ] **Step 3: Verify schema**

```bash
grep -A 20 'create_table "replies"' db/schema.rb && echo "---memories---" && grep -A 25 'create_table "memories"' db/schema.rb
```

Expected:
- `replies` table present with `memory_id`, `user_id`, `name`, `relationship`, `email`, `body`, `status`, `created_at`, `updated_at`.
- `memories` table now has `kind` (default 0, null: false), `name`, `relationship`, `email`, `audio_label`, `audio_length`.

- [ ] **Step 4: Generate the backfill migration**

```bash
bin/rails generate migration backfill_memory_name_and_kind
```

Replace its contents with:

```ruby
class BackfillMemoryNameAndKind < ActiveRecord::Migration[8.1]
  def up
    # Use SQL rather than Memory.find_each — keeps the migration tolerant of
    # future model changes (e.g. if a validation we add later would reject
    # existing rows).
    execute <<~SQL
      UPDATE memories
      SET name = COALESCE(name,
        (SELECT users.name FROM users WHERE users.id = memories.user_id),
        'Anonymous')
      WHERE name IS NULL;
    SQL

    execute <<~SQL
      UPDATE memories
      SET kind = 1
      WHERE id IN (
        SELECT DISTINCT record_id
        FROM active_storage_attachments
        WHERE record_type = 'Memory' AND name = 'photos'
      ) AND kind = 0;
    SQL
  end

  def down
    # Backfill is forward-only; column-level defaults restore at down time.
  end
end
```

- [ ] **Step 5: Run the backfill migration**

```bash
bin/rails db:migrate
```

Expected: no errors, statement completes.

- [ ] **Step 6: Verify the backfill**

```bash
bin/rails runner 'Memory.all.each { |m| puts "#{m.id}: name=#{m.name.inspect} kind=#{m.kind}" }'
```

Expected: every memory has a `name` (not nil), and `kind` is `0` (no photos) or `1` (has photos).

- [ ] **Step 7: Run the full test suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 121 runs, ALL pass (no Memory tests should break yet — the model file is unchanged so no behavior changed).

- [ ] **Step 8: Commit**

```bash
git add db/migrate/ db/schema.rb
git commit -m "Phase 3: schema — memory fields + kind enum + replies table"
```

---

## Task 2: Memory model — enum, validations, associations, derived methods

**Files:**
- Modify: `app/models/memory.rb`
- Modify: `test/models/memory_test.rb`

Use TDD: write tests, watch them fail, implement, watch them pass.

- [ ] **Step 1: Replace `test/models/memory_test.rb` with the expanded test suite**

```ruby
require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "valid text memory with date and content" do
    memory = Memory.new(date: Date.today, content: "A great day.", name: "Alex", email: "alex@example.com")
    assert memory.valid?, memory.errors.full_messages.inspect
    assert_equal "pending", memory.status
    assert_equal "text", memory.kind
  end

  test "invalid without date" do
    memory = Memory.new(content: "A great day.", name: "Alex", email: "alex@example.com")
    assert_not memory.valid?
    assert_includes memory.errors[:date], "can't be blank"
  end

  test "user is optional" do
    memory = Memory.new(date: Date.today, content: "A story.", name: "Anonymous", email: "x@y.com")
    assert memory.valid?
    assert_nil memory.user
  end

  test "anonymous memory requires name" do
    memory = Memory.new(date: Date.today, content: "x", email: "x@y.com")
    assert_not memory.valid?
    assert_includes memory.errors[:name], "can't be blank"
  end

  test "anonymous memory requires email" do
    memory = Memory.new(date: Date.today, content: "x", name: "Alex")
    assert_not memory.valid?
    assert_includes memory.errors[:email], "can't be blank"
  end

  test "anonymous memory rejects malformed email" do
    memory = Memory.new(date: Date.today, content: "x", name: "Alex", email: "not-an-email")
    assert_not memory.valid?
    assert_includes memory.errors[:email].join, "invalid"
  end

  test "signed-in memory doesn't require name or email" do
    user = User.create!(name: "Sam", email: "sam@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user)
    assert memory.valid?, memory.errors.full_messages.inspect
  end

  test "kind enum predicates" do
    m = Memory.new(date: Date.today, content: "x", name: "A", email: "a@b.com")
    assert m.kind_text?
    m.kind = :photo
    assert m.kind_photo?
    m.kind = :audio
    assert m.kind_audio?
  end

  test "photo kind requires attached photos" do
    memory = Memory.new(date: Date.today, kind: :photo, name: "Alex", email: "a@b.com")
    assert_not memory.valid?
    assert_includes memory.errors[:photos], "is required for photo memories"
  end

  test "audio kind requires attached audio_clip" do
    memory = Memory.new(date: Date.today, kind: :audio, name: "Alex", email: "a@b.com")
    assert_not memory.valid?
    assert_includes memory.errors[:audio_clip], "is required for audio memories"
  end

  test "year is derived from date" do
    memory = Memory.new(date: Date.new(2014, 6, 15), content: "x", name: "A", email: "a@b.com")
    assert_equal 2014, memory.year
  end

  test "age is year minus 1984" do
    memory = Memory.new(date: Date.new(2014, 6, 15), content: "x", name: "A", email: "a@b.com")
    assert_equal 30, memory.age
  end

  test "display_name prefers memory.name over user.name" do
    user = User.create!(name: "Account Name", email: "u@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user, name: "Submitted Name")
    assert_equal "Submitted Name", memory.display_name
  end

  test "display_name falls back to user.name when memory.name is blank" do
    user = User.create!(name: "Account Name", email: "u@test.com", password: "password123")
    memory = Memory.new(date: Date.today, content: "x", user: user)
    assert_equal "Account Name", memory.display_name
  end

  test "display_name falls back to Anonymous when neither set" do
    memory = Memory.new(date: Date.today, content: "x")
    assert_equal "Anonymous", memory.display_name
  end

  test "default pin color is moss" do
    assert_equal "#3a5240", Memory.default_pin_color
  end

  test "memory has many replies" do
    memory = Memory.create!(date: Date.today, content: "x", name: "A", email: "a@b.com", status: :published)
    reply = memory.replies.create!(name: "B", email: "b@c.com", body: "Yes!", status: :published)
    assert_equal [reply], memory.replies.to_a
  end
end
```

- [ ] **Step 2: Run tests and watch them fail**

```bash
bin/rails test test/models/memory_test.rb -v
```

Expected: multiple failures — model doesn't yet have the enum, validations, or methods.

- [ ] **Step 3: Replace `app/models/memory.rb`**

```ruby
class Memory < ApplicationRecord
  CHRIS_BIRTH_YEAR = 1984

  include Mappable

  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :kind,   { text: 0, photo: 1, audio: 2 }, prefix: :kind

  belongs_to :user, optional: true
  has_many   :replies, -> { published.order(:created_at) }, dependent: :destroy
  has_many_attached :photos
  has_one_attached  :audio_clip

  geocoded_by :location
  after_validation :geocode, if: ->(m) { m.location_changed? && m.location.present? && m.latitude.blank? }

  validates :date,    presence: true
  validates :content, presence: true, unless: -> { kind_photo? || kind_audio? }
  validates :name,    presence: true, if: -> { user_id.blank? }
  validates :email,   presence: true, if: -> { user_id.blank? }
  validates :email,   format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }, allow_blank: true
  validate  :audio_clip_required_if_kind_audio
  validate  :photos_required_if_kind_photo

  def year = date.year
  def age  = year - CHRIS_BIRTH_YEAR
  def display_name = name.presence || user&.name || "Anonymous"
  def display_relationship = relationship.presence

  def self.default_pin_color = "#3a5240"      # moss
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

- [ ] **Step 4: Run model tests and watch them pass**

```bash
bin/rails test test/models/memory_test.rb -v
```

Expected: 16 runs, all pass.

- [ ] **Step 5: Run the full suite — catch regressions**

```bash
bin/rails test 2>&1 | tail -10
```

Some failures are expected:

- `test/integration/homepage_test.rb` — the `_preview_card.html.erb` calls `memory.photos.attached?`. Will still work — that doesn't change. Likely still green.
- `test/integration/public_pages_test.rb` — also likely green; no Memory-specific assertions.
- `test/integration/admin_test.rb` — may rely on old MemoriesController auth behavior. Check.

Anything failing that isn't a known knock-on: investigate before continuing.

- [ ] **Step 6: Commit**

```bash
git add app/models/memory.rb test/models/memory_test.rb
git commit -m "Phase 3: expand Memory model — kind enum, submitter fields, derived methods"
```

---

## Task 3: Reply model + routes

**Files:**
- Create: `app/models/reply.rb`
- Create: `test/models/reply_test.rb`
- Modify: `config/routes.rb`

- [ ] **Step 1: Write failing model tests**

Create `test/models/reply_test.rb`:

```ruby
require "test_helper"

class ReplyTest < ActiveSupport::TestCase
  def setup
    @memory = Memory.create!(
      date: Date.today, content: "x",
      name: "Author", email: "author@test.com", status: :published
    )
  end

  test "valid reply with name + body + email (anonymous)" do
    reply = @memory.replies.build(name: "Alex", body: "Beautiful.", email: "alex@test.com")
    assert reply.valid?, reply.errors.full_messages.inspect
    assert_equal "pending", reply.status
  end

  test "invalid without name" do
    reply = @memory.replies.build(body: "x", email: "a@b.com")
    assert_not reply.valid?
    assert_includes reply.errors[:name], "can't be blank"
  end

  test "invalid without body" do
    reply = @memory.replies.build(name: "Alex", email: "a@b.com")
    assert_not reply.valid?
    assert_includes reply.errors[:body], "can't be blank"
  end

  test "anonymous reply requires email" do
    reply = @memory.replies.build(name: "Alex", body: "x")
    assert_not reply.valid?
    assert_includes reply.errors[:email], "can't be blank"
  end

  test "signed-in reply doesn't require email" do
    user = User.create!(name: "U", email: "u@test.com", password: "password123")
    reply = @memory.replies.build(name: "Alex", body: "x", user: user)
    assert reply.valid?
  end

  test "published scope filters status" do
    @memory.replies.create!(name: "A", email: "a@b.com", body: "x", status: :pending)
    @memory.replies.create!(name: "B", email: "b@c.com", body: "y", status: :published)
    assert_equal 1, Reply.published.count
  end
end
```

- [ ] **Step 2: Run tests, watch fail**

```bash
bin/rails test test/models/reply_test.rb -v
```

Expected: `NameError: uninitialized constant Reply`.

- [ ] **Step 3: Create the Reply model**

Create `app/models/reply.rb`:

```ruby
class Reply < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }

  belongs_to :memory
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :body, presence: true
  validates :email, presence: true, if: -> { user_id.blank? }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, message: "is invalid" }, allow_blank: true

  scope :published, -> { where(status: :published) }
end
```

- [ ] **Step 4: Run reply tests**

```bash
bin/rails test test/models/reply_test.rb -v
```

Expected: 6 runs, all pass.

- [ ] **Step 5: Update routes to nest replies under memories**

Edit `config/routes.rb`. Find:

```ruby
  resources :memories, only: [ :index, :new, :create, :show ], path: "timeline"
```

Replace with:

```ruby
  resources :memories, only: [ :index, :new, :create, :show ], path: "timeline" do
    resources :replies, only: [ :create ]
  end
```

- [ ] **Step 6: Verify the new route exists**

```bash
bin/rails routes | grep -E "memory_replies|memory_reply"
```

Expected: `POST   /timeline/:memory_id/replies(.:format)   replies#create`.

- [ ] **Step 7: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 127 runs (was 121, added 6 reply tests; the new Memory tests are 16 vs old 3, so net +13). The +6 reply tests pass, all others still pass.

- [ ] **Step 8: Commit**

```bash
git add app/models/reply.rb test/models/reply_test.rb config/routes.rb
git commit -m "Phase 3: add Reply model + nested route under memories"
```

---

## Task 4: MemoriesController updates

**Files:**
- Modify: `app/controllers/memories_controller.rb`
- Create: `test/controllers/memories_controller_test.rb` (or extend if exists)

- [ ] **Step 1: Check if memories controller test already exists**

```bash
ls test/controllers/memories_controller_test.rb 2>&1
```

If it doesn't exist, create it. If it does, extend it.

- [ ] **Step 2: Write failing controller tests**

Create or extend `test/controllers/memories_controller_test.rb`:

```ruby
require "test_helper"

class MemoriesControllerTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "GET /timeline works for anonymous users" do
    get memories_path
    assert_response :success
  end

  test "GET /timeline/new works for anonymous users" do
    get new_memory_path
    assert_response :success
  end

  test "anonymous POST /timeline creates a pending memory" do
    assert_difference "Memory.count", 1 do
      post memories_path, params: {
        memory: {
          date: Date.today.to_s,
          content: "An anonymous remembrance.",
          name: "Stranger",
          email: "stranger@example.com",
          kind: "text"
        }
      }
    end
    memory = Memory.last
    assert_equal "pending", memory.status
    assert_nil memory.user
  end

  test "signed-in POST /timeline creates a published memory" do
    user = sign_in_contributor

    assert_difference "Memory.count", 1 do
      post memories_path, params: {
        memory: {
          date: Date.today.to_s,
          content: "A signed-in memory.",
          kind: "text"
        }
      }
    end
    memory = Memory.last
    assert_equal "published", memory.status
    assert_equal user, memory.user
  end

  test "GET /timeline filters by year" do
    Memory.create!(date: Date.new(2010, 1, 1), content: "Old", name: "A", email: "a@b.com", status: :published)
    Memory.create!(date: Date.new(2020, 1, 1), content: "Recent", name: "B", email: "b@c.com", status: :published)

    get memories_path, params: { year: 2010 }

    assert_match "Old", response.body
    assert_no_match "Recent", response.body
  end

  test "year filter exposes available years" do
    Memory.delete_all
    Memory.create!(date: Date.new(2010, 1, 1), content: "x", name: "A", email: "a@b.com", status: :published)
    Memory.create!(date: Date.new(2020, 1, 1), content: "y", name: "B", email: "b@c.com", status: :published)

    get memories_path

    # Year chips present
    assert_match "2010", response.body
    assert_match "2020", response.body
  end
end
```

- [ ] **Step 3: Run, watch fail**

```bash
bin/rails test test/controllers/memories_controller_test.rb -v
```

Expected: failures — `GET /timeline/new` redirects to sign-in (existing auth requirement); anonymous POST is also blocked.

- [ ] **Step 4: Update `app/controllers/memories_controller.rb`**

Replace its contents with:

```ruby
class MemoriesController < ApplicationController
  def index
    scope = Memory.published.includes(:user, :replies).order(date: :desc)
    @years = Memory.published.pluck("strftime('%Y', date)").uniq.sort.reverse.map(&:to_i)
    @active_year = params[:year]&.to_i
    @memories = @active_year ? scope.where("strftime('%Y', date) = ?", @active_year.to_s) : scope
    @memories_count = @memories.count
    @contributors_count = User.joins(:memories).distinct.count +
                          Memory.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
  end

  def show
    @memory = Memory.published.find(params[:id])
  end

  def new
    @memory = Memory.new(kind: :text, date: Date.today)
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

- [ ] **Step 5: Run controller tests**

```bash
bin/rails test test/controllers/memories_controller_test.rb -v
```

Expected: 6 runs, all pass.

Note: the "GET /timeline/new" test may render the existing `new.html.erb` which still has the old form fields. That's a known transitional state — the view rewrite is Task 6+. The test only checks for `:success`, which should pass even with the old form rendering.

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 133 runs, all pass (was 127 + 6 controller tests).

If anything else broke, especially `test/integration/admin_test.rb`, investigate.

- [ ] **Step 7: Commit**

```bash
git add app/controllers/memories_controller.rb test/controllers/memories_controller_test.rb
git commit -m "Phase 3: open MemoriesController to anonymous + branch status by auth"
```

---

## Task 5: RepliesController + tests

**Files:**
- Create: `app/controllers/replies_controller.rb`
- Create: `test/controllers/replies_controller_test.rb`

- [ ] **Step 1: Write failing controller tests**

Create `test/controllers/replies_controller_test.rb`:

```ruby
require "test_helper"

class RepliesControllerTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def setup
    @memory = Memory.create!(
      date: Date.today, content: "x",
      name: "Author", email: "author@test.com", status: :published
    )
  end

  test "anonymous POST creates a pending reply" do
    assert_difference "Reply.count", 1 do
      post memory_replies_path(@memory), params: {
        reply: { name: "Visitor", body: "Beautiful.", email: "v@test.com" }
      }
    end
    reply = Reply.last
    assert_equal "pending", reply.status
    assert_nil reply.user
    assert_redirected_to memory_path(@memory)
  end

  test "signed-in POST creates a published reply" do
    user = sign_in_contributor

    assert_difference "Reply.count", 1 do
      post memory_replies_path(@memory), params: {
        reply: { name: "Visitor", body: "Yes." }
      }
    end
    reply = Reply.last
    assert_equal "published", reply.status
    assert_equal user, reply.user
  end

  test "invalid reply redirects with errors" do
    post memory_replies_path(@memory), params: {
      reply: { name: "Visitor" }  # missing body and email
    }
    assert_redirected_to memory_path(@memory)
    follow_redirect!
    assert_match /can't be blank/i, response.body
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/controllers/replies_controller_test.rb -v
```

Expected: `RoutingError` or `NameError` (no RepliesController yet).

- [ ] **Step 3: Create RepliesController**

Create `app/controllers/replies_controller.rb`:

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
      redirect_to memory_path(@memory), alert: @reply.errors.full_messages.join(", "), status: :see_other
    end
  end

  private

  def set_memory
    # Use unscoped find to allow replying even if the memory is unpublished
    # (though this controller only renders the form on the published timeline).
    @memory = Memory.published.find(params[:memory_id])
  end

  def reply_params
    params.require(:reply).permit(:name, :relationship, :email, :body)
  end
end
```

Note: `status: :see_other` (303) is required when redirecting from a POST/PATCH per the HTTP spec, and Rails 7+ tightens this.

- [ ] **Step 4: Run tests**

```bash
bin/rails test test/controllers/replies_controller_test.rb -v
```

Expected: 3 runs, all pass.

The "invalid reply" test asserts `response.body` after `follow_redirect!`. That follow lands on `memory_path(@memory)` which renders `show.html.erb`. The flash alert appears in the application layout via the `<% if alert %>` block from Phase 1. Verify that block exists (it should — it's from Phase 1's layout):

```bash
grep -A 3 "alert" app/views/layouts/application.html.erb | head -10
```

If the flash block is present, the `assert_match /can't be blank/i` succeeds against the flash text in the rendered HTML.

- [ ] **Step 5: Run full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 136 runs, all pass.

- [ ] **Step 6: Commit**

```bash
git add app/controllers/replies_controller.rb test/controllers/replies_controller_test.rb
git commit -m "Phase 3: add RepliesController (anonymous → pending, signed-in → published)"
```

---

## Task 6: Timeline page — year filter + spine + index rewrite

**Files:**
- Modify: `app/views/memories/index.html.erb` (full rewrite)
- Create: `app/views/memories/_year_filter.html.erb`
- Create: `app/views/memories/_year_marker.html.erb`
- Create: `app/views/memories/_memory_card.html.erb` (placeholder dispatcher — variants in Task 7)
- Create: `test/integration/timeline_test.rb`
- Update: `db/seeds.rb` to backfill `name` and `kind` on seeded memories (idempotent)

Up until now the index page still renders the old Stone/Blue markup. This task rewrites it. Card kind-variants are skeletal (just inline a generic card for now); Task 7 adds the variants.

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/timeline_test.rb`:

```ruby
require "test_helper"

class TimelineTest < ActionDispatch::IntegrationTest
  def setup
    Memory.delete_all
    Memory.create!(date: Date.new(2002, 9, 1), content: "Mass Row", location: "Hanover, NH",
                   name: "Friend", email: "f@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2014, 6, 15), content: "Munich concert", location: "Munich, Germany",
                   name: "Colleague", email: "c@a.com", kind: :text, status: :published)
    Memory.create!(date: Date.new(2019, 5, 12), content: "Stavanger rehearsal", location: "Stavanger, Norway",
                   name: "Student", email: "s@a.com", kind: :text, status: :published)
  end

  test "timeline renders the header with eyebrow + h1" do
    get memories_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. III · The Timeline/
    assert_select "h1.font-serif", text: /A life, kept by/
  end

  test "timeline renders the Share a memory CTA" do
    get memories_path
    # Any button or link with the text "Share a memory" referencing new_memory_path or triggering the modal
    assert_select "button, a", text: /Share a memory/i
  end

  test "timeline renders year filter chips for each unique year" do
    get memories_path
    assert_select "[data-year-filter]" do
      assert_select "a, button", text: "All"
      assert_select "a, button", text: "2002"
      assert_select "a, button", text: "2014"
      assert_select "a, button", text: "2019"
    end
  end

  test "All chip is active when no year filter" do
    get memories_path
    assert_select "[data-year-filter] .bg-moss.text-cream", text: "All"
  end

  test "Year chip is active when filtered" do
    get memories_path, params: { year: 2014 }
    assert_select "[data-year-filter] .bg-moss.text-cream", text: "2014"
  end

  test "filtering by year renders only that year's memories" do
    get memories_path, params: { year: 2014 }
    assert_match "Munich concert", response.body
    assert_no_match "Mass Row", response.body
    assert_no_match "Stavanger rehearsal", response.body
  end

  test "year markers render he-was-N subtext" do
    get memories_path
    # 2002: he was 18; 2014: he was 30; 2019: he was 35
    assert_match "he was 18", response.body
    assert_match "he was 30", response.body
    assert_match "he was 35", response.body
  end

  test "memory cards render content, name, location" do
    get memories_path
    assert_match "Mass Row", response.body
    assert_match "Hanover, NH", response.body
    assert_match "Friend", response.body
  end

  test "empty year filter shows Clear filter link" do
    get memories_path, params: { year: 2099 }
    assert_match /No memories for 2099/, response.body
    assert_select "a[href=?]", memories_path, text: /Clear filter/i
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/timeline_test.rb -v
```

Expected: 9 runs, all fail (old `index.html.erb` still has Stone/Blue markup with no year filter).

- [ ] **Step 3: Create the year filter partial**

Create `app/views/memories/_year_filter.html.erb`:

```erb
<%# Sticky year-filter chip row %>
<div data-year-filter
     class="sticky top-[68px] z-30 bg-cream/90 backdrop-blur-[10px] border-b border-ink/8 px-6 lg:px-14 py-3 flex gap-2 overflow-x-auto">
  <%= link_to "All", memories_path,
        class: chip_class(active: active_year.nil?) %>
  <% years.each do |y| %>
    <%= link_to y.to_s, memories_path(year: y),
          class: chip_class(active: active_year == y) %>
  <% end %>
</div>
```

The partial uses a helper `chip_class(active:)`. Add it to `app/helpers/musical_helper.rb` (existing module):

```ruby
  # Returns the Tailwind classes for a year-filter chip.
  def chip_class(active:)
    base = "rounded-full px-4 py-1.5 text-sm whitespace-nowrap no-underline border transition-colors"
    if active
      "#{base} bg-moss text-cream border-moss"
    else
      "#{base} bg-transparent text-ink border-ink/20 hover:border-moss hover:text-moss"
    end
  end
```

- [ ] **Step 4: Create the year marker partial**

Create `app/views/memories/_year_marker.html.erb`:

```erb
<%# Year marker anchored at center of the spine.
    Locals: year (integer), age (integer) %>
<div class="flex justify-center mb-12 mt-16">
  <div class="text-center">
    <h2 class="font-serif text-5xl md:text-[64px] font-normal text-ink m-0 leading-none"><%= year %></h2>
    <div class="text-eyebrow text-sage mt-2">he was <%= age %></div>
  </div>
</div>
```

- [ ] **Step 5: Create a placeholder _memory_card partial (dispatcher)**

Create `app/views/memories/_memory_card.html.erb`:

```erb
<%# Dispatches to the kind-specific card. Phase 3 Task 7 adds the three
    variant partials; until then this renders a generic card.
    Local: memory %>
<% partial_name = case memory.kind
                  when "text"  then "memories/text_card"
                  when "photo" then "memories/photo_card"
                  when "audio" then "memories/audio_card"
                  else              "memories/text_card"
                  end %>

<% if lookup_context.exists?(partial_name, [], true) %>
  <%= render partial_name, memory: memory %>
<% else %>
  <%# Fallback generic card until variants exist (Task 7) %>
  <article class="bg-white rounded-md border border-ink/8 shadow-card p-6 max-w-[480px] mx-auto mb-8">
    <div class="text-eyebrow text-sage">
      <%= l(memory.date, format: :memory) %> · <%= memory.location %>
    </div>
    <p class="font-serif text-[19px] leading-snug text-ink mt-3"><%= memory.content %></p>
    <footer class="mt-4 pt-3.5 border-t border-ink/8 flex justify-between items-baseline">
      <div>
        <div class="text-sm font-medium text-ink"><%= memory.display_name %></div>
        <% if memory.display_relationship %>
          <div class="text-eyebrow text-sage"><%= memory.display_relationship %></div>
        <% end %>
      </div>
    </footer>
  </article>
<% end %>
```

- [ ] **Step 6: Rewrite `app/views/memories/index.html.erb`**

```erb
<% content_for :title, "Timeline — Christopher Quentin McMullen-Laird" %>

<%# Header %>
<section class="px-6 lg:px-14 pt-12 pb-6">
  <%= musical_eyebrow("Op. III · The Timeline", with_rule: true) %>
  <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3">
    A life, kept by <em class="font-serif italic text-moss">many hands</em>.
  </h1>
  <div class="mt-3 flex flex-col md:flex-row md:items-center md:justify-between gap-4">
    <p class="text-[17px] text-ink/65">
      <%= pluralize(@memories_count, "memory", plural: "memories") %> · <%= pluralize(@contributors_count, "contributor") %>
    </p>
    <button type="button"
            data-controller="share-modal-trigger"
            data-action="share-modal-trigger#open"
            class="bg-moss text-cream rounded-full px-6 py-3 text-sm font-medium self-start md:self-auto hover:bg-ink transition-colors">
      Share a memory
    </button>
  </div>
</section>

<%= render "memories/year_filter", years: @years, active_year: @active_year %>

<%# Timeline body %>
<section class="relative px-6 lg:px-14 py-12 min-h-[400px]">
  <%# Vertical spine — desktop only %>
  <div class="hidden lg:block absolute left-1/2 top-0 bottom-0 w-px bg-gradient-to-b from-cream via-sage/30 to-cream"
       aria-hidden="true"></div>

  <% if @memories.any? %>
    <% @memories.group_by(&:year).each do |year, memories_in_year| %>
      <%= render "memories/year_marker", year: year, age: year - Memory::CHRIS_BIRTH_YEAR %>
      <% memories_in_year.each do |memory| %>
        <%= render "memories/memory_card", memory: memory %>
      <% end %>
    <% end %>
  <% else %>
    <div class="text-center py-20">
      <p class="font-serif italic text-2xl text-ink/70 mb-4">No memories for <%= @active_year %>.</p>
      <%= link_to "Clear filter →", memories_path, class: "text-moss text-sm font-medium hover:underline" %>
    </div>
  <% end %>
</section>
```

Note: this version uses `data-controller="share-modal-trigger"` and a corresponding action. The trigger controller doesn't exist yet — Task 9 creates the share modal Stimulus controller, which also includes the trigger. The button will render but clicking it won't open anything until Task 9 lands. Tests in this task only assert button presence + text, so they pass.

- [ ] **Step 7: Run timeline tests**

```bash
bin/rails test test/integration/timeline_test.rb -v
```

Expected: 9 runs, all pass.

- [ ] **Step 8: Update db/seeds.rb to set kind on seeded memories**

The Task 1 backfill migration already set `kind` correctly. But `db:reset` re-runs `seeds.rb` from scratch. Update `db/seeds.rb` so the seed `Memory.find_or_create_by!` blocks include `kind`:

In `db/seeds.rb`, find the `memories_data.each` block. Update each hash in `memories_data` to add `kind: "text"`:

```ruby
memories_data = [
  { date: Date.new(2002, 9, 1), title: "Mass Row, Dartmouth", kind: "text",
    content: "Sept 2002, Mass Row dorm. Two weeks into freshman year and Chris already had a chamber group meeting in his common room every Thursday. He'd score the parts by hand, then pass them out before dinner.",
    location: "Hanover, NH" },
  { date: Date.new(2014, 6, 15), title: "Munich concert", kind: "text",
    content: "I'll never forget the evening Christopher conducted Beethoven's 7th in Munich. The energy in the room was electric — and after the second movement he caught my eye in the balcony and grinned.",
    location: "Munich, Germany" },
  { date: Date.new(2019, 5, 12), title: "Stavanger rehearsal", kind: "text",
    content: "Watching Chris rehearse Mahler with the Jæren Symfoniorkester. He stopped after eight bars to make a joke about the violas. Everyone laughed. Then the next phrase was perfect.",
    location: "Stavanger, Norway" },
]
```

And update the find_or_create_by! block to set `m.kind = attrs[:kind]` and `m.name = "Samuel"` (admin's name, since seed memories belong to admin):

```ruby
memories_data.each do |attrs|
  Memory.find_or_create_by!(date: attrs[:date], title: attrs[:title]) do |m|
    m.content = attrs[:content]
    m.location = attrs[:location]
    m.user = admin
    m.name = admin.name
    m.kind = attrs[:kind]
    m.status = :published
  end
end
```

Re-run seeds to verify:

```bash
bin/rails db:reset 2>&1 | tail -5
```

Expected: `Sample data created (3 memories, 3 events, 4 tributes, 1 trees).`

- [ ] **Step 9: Run full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 145 runs, all pass (was 136, added 9 timeline tests).

- [ ] **Step 10: Commit**

```bash
git add app/views/memories/ app/helpers/musical_helper.rb test/integration/timeline_test.rb db/seeds.rb
git commit -m "Phase 3: timeline page with year filter, spine, year markers"
```

---

## Task 7: Memory card variants — text / photo / audio

**Files:**
- Create: `app/views/memories/_text_card.html.erb`
- Create: `app/views/memories/_photo_card.html.erb`
- Create: `app/views/memories/_audio_card.html.erb`
- Create: `app/javascript/controllers/audio_player_controller.js`
- Modify: `config/importmap.rb` (pin wavesurfer.js)
- Modify: `test/integration/timeline_test.rb` (append variant tests)

- [ ] **Step 1: Append variant tests to timeline_test.rb**

Append (inside the `class TimelineTest` block, before its closing `end`):

```ruby
  test "photo memory card renders the photo slot" do
    photo_memory = Memory.create!(
      date: Date.new(2014, 6, 15), content: "On stage.",
      name: "Photographer", email: "p@a.com", kind: :photo, status: :published
    )
    photo_memory.photos.attach(
      io: StringIO.new("fake image bytes"),
      filename: "test.jpg",
      content_type: "image/jpeg"
    )

    get memories_path

    assert_select "[data-memory-id='#{photo_memory.id}'][data-kind='photo']"
  end

  test "audio memory card renders the audio player controller" do
    audio_memory = Memory.create!(
      date: Date.new(2018, 7, 1), content: "A clip.",
      name: "Recorder", email: "r@a.com", kind: :audio, audio_label: "Cape Cod, summer 2018",
      audio_length: "1:42", status: :published
    )
    audio_memory.audio_clip.attach(
      io: StringIO.new("fake audio bytes"),
      filename: "test.mp3",
      content_type: "audio/mpeg"
    )

    get memories_path

    assert_select "[data-controller~='audio-player']"
    assert_select "[data-memory-id='#{audio_memory.id}'][data-kind='audio']"
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/timeline_test.rb -n /photo_memory|audio_memory/ -v
```

Expected: 2 failures (no variant partials, no audio-player controller).

- [ ] **Step 3: Create `_text_card.html.erb`**

```erb
<%# Text memory card — quoted serif body, meta footer.
    Local: memory %>
<article data-memory-id="<%= memory.id %>" data-kind="text"
         class="bg-white rounded-md border border-ink/8 shadow-card p-7 max-w-[480px] mx-auto mb-12 lg:mb-16 lg:<%= memory.id.odd? ? 'mr-auto lg:ml-0' : 'ml-auto lg:mr-0' %>">
  <div class="text-eyebrow text-sage">
    <%= l(memory.date, format: :memory) %><% if memory.location.present? %> · <%= memory.location %><% end %>
  </div>
  <blockquote class="font-serif text-[20px] leading-relaxed text-ink mt-4 mb-0">
    <%= simple_format("“#{memory.content}”") %>
  </blockquote>
  <%= render "memories/card_footer", memory: memory %>
</article>
```

The alternating left/right uses `memory.id.odd?` as a deterministic-but-arbitrary pivot. (Phase 4 may revisit if the visual rhythm is off — alternating by *index* in `@memories` is more controllable but requires passing the index in.)

- [ ] **Step 4: Create `_card_footer.html.erb` (shared by all three variants)**

Create `app/views/memories/_card_footer.html.erb`:

```erb
<%# Shared footer for memory cards: name, relationship, kind badge, reply button.
    Local: memory %>
<footer class="mt-5 pt-4 border-t border-ink/8 flex justify-between items-end">
  <div>
    <div class="text-sm font-medium text-ink"><%= memory.display_name %></div>
    <% if memory.display_relationship %>
      <div class="text-eyebrow text-sage mt-0.5"><%= memory.display_relationship %></div>
    <% end %>
  </div>
  <div class="flex items-center gap-3">
    <span class="text-eyebrow text-sage">
      <%= { "text" => "letter", "photo" => "photograph", "audio" => "recording" }[memory.kind] %>
    </span>
    <button type="button"
            class="border border-ink/20 text-ink/70 hover:border-moss hover:text-moss rounded-full px-3 py-1 text-xs">
      ↩ Reply
    </button>
  </div>
</footer>
```

The Reply button is a placeholder — Task 8 wires the composer Stimulus controller.

- [ ] **Step 5: Create `_photo_card.html.erb`**

```erb
<%# Photo memory card — top photo slot, then body, then footer.
    Local: memory %>
<article data-memory-id="<%= memory.id %>" data-kind="photo"
         class="bg-white rounded-md border border-ink/8 shadow-card overflow-hidden max-w-[480px] mx-auto mb-12 lg:mb-16 lg:<%= memory.id.odd? ? 'mr-auto lg:ml-0' : 'ml-auto lg:mr-0' %>">
  <% if memory.photos.attached? %>
    <%= image_tag memory.photos.first,
          class: "w-full h-[260px] object-cover",
          alt: memory.title.presence || "Memory photo" %>
  <% else %>
    <div class="w-full h-[260px] relative"
         style="background: linear-gradient(135deg, rgba(90,122,94,0.2), rgba(58,82,64,0.3)), repeating-linear-gradient(45deg, rgba(90,122,94,0.08) 0 12px, transparent 12px 24px);">
      <div class="absolute bottom-4 left-4 text-eyebrow text-cream mix-blend-difference">
        [ photo · <%= memory.location.presence || "untitled" %> ]
      </div>
    </div>
  <% end %>
  <div class="p-7">
    <div class="text-eyebrow text-sage">
      <%= l(memory.date, format: :memory) %><% if memory.location.present? %> · <%= memory.location %><% end %>
    </div>
    <% if memory.content.present? %>
      <p class="font-serif text-[19px] leading-snug text-ink mt-3"><%= memory.content %></p>
    <% end %>
    <%= render "memories/card_footer", memory: memory %>
  </div>
</article>
```

- [ ] **Step 6: Create `_audio_card.html.erb`**

```erb
<%# Audio memory card — moss header strip with play button + waveform, then body.
    Local: memory %>
<article data-memory-id="<%= memory.id %>" data-kind="audio"
         class="bg-white rounded-md border border-ink/8 shadow-card overflow-hidden max-w-[480px] mx-auto mb-12 lg:mb-16 lg:<%= memory.id.odd? ? 'mr-auto lg:ml-0' : 'ml-auto lg:mr-0' %>">
  <% if memory.audio_clip.attached? %>
    <div class="bg-moss text-cream p-4 flex items-center gap-3"
         data-controller="audio-player"
         data-audio-player-url-value="<%= url_for(memory.audio_clip) %>">
      <button type="button"
              data-action="audio-player#toggle"
              data-audio-player-target="playButton"
              class="w-10 h-10 rounded-full bg-cream text-moss font-bold text-lg flex items-center justify-center hover:bg-linen">
        ▶
      </button>
      <div class="flex-1 min-w-0">
        <% if memory.audio_label.present? %>
          <div class="font-serif italic text-base truncate"><%= memory.audio_label %></div>
        <% end %>
        <div data-audio-player-target="waveform" class="mt-1 h-4"></div>
      </div>
      <% if memory.audio_length.present? %>
        <div data-audio-player-target="duration" class="text-eyebrow text-cream/80 whitespace-nowrap">
          <%= memory.audio_length %>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="bg-moss text-cream/60 p-6 text-center text-eyebrow">[ audio not attached ]</div>
  <% end %>
  <div class="p-7">
    <div class="text-eyebrow text-sage">
      <%= l(memory.date, format: :memory) %><% if memory.location.present? %> · <%= memory.location %><% end %>
    </div>
    <% if memory.content.present? %>
      <p class="font-serif text-[19px] leading-snug text-ink mt-3"><%= memory.content %></p>
    <% end %>
    <%= render "memories/card_footer", memory: memory %>
  </div>
</article>
```

- [ ] **Step 7: Pin wavesurfer.js in importmap**

Edit `config/importmap.rb`. After the existing pins, add:

```ruby
pin "wavesurfer.js", to: "https://ga.jspm.io/npm:wavesurfer.js@7.10.0/dist/wavesurfer.esm.js"
```

Verify:

```bash
bin/rails runner 'puts Rails.application.config.importmap.packages.keys.grep(/wavesurfer/)'
```

Expected: `["wavesurfer.js"]`.

- [ ] **Step 8: Create the audio_player Stimulus controller**

Create `app/javascript/controllers/audio_player_controller.js`:

```js
import WaveSurfer from "wavesurfer.js"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["waveform", "playButton", "duration"]
  static values  = { url: String }

  connect() {
    this.ws = WaveSurfer.create({
      container: this.waveformTarget,
      waveColor: "rgba(250,246,238,0.4)",
      progressColor: "rgba(250,246,238,1)",
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
    if (!this.ws) return
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

- [ ] **Step 9: Run the variant tests**

```bash
bin/rails test test/integration/timeline_test.rb -n /photo_memory|audio_memory/ -v
```

Expected: 2 runs, both pass.

- [ ] **Step 10: Run full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 147 runs, all pass (was 145 + 2).

- [ ] **Step 11: Commit**

```bash
git add app/views/memories/ app/javascript/controllers/audio_player_controller.js config/importmap.rb test/integration/timeline_test.rb
git commit -m "Phase 3: memory card variants — text / photo / audio with wavesurfer.js"
```

---

## Task 8: Reply partials + inline composer

**Files:**
- Create: `app/views/memories/_reply.html.erb`
- Create: `app/views/memories/_reply_composer.html.erb`
- Create: `app/javascript/controllers/reply_toggle_controller.js`
- Modify: `app/views/memories/_card_footer.html.erb` — wire the Reply button
- Modify: `app/views/memories/_text_card.html.erb`, `_photo_card.html.erb`, `_audio_card.html.erb` — render replies + composer after footer
- Modify: `test/integration/timeline_test.rb` — append reply tests

- [ ] **Step 1: Append reply tests**

Append to `test/integration/timeline_test.rb`:

```ruby
  test "memory card with replies renders them" do
    memory = Memory.create!(
      date: Date.today, content: "A note.",
      name: "Author", email: "a@b.com", kind: :text, status: :published
    )
    memory.replies.create!(name: "Visitor", email: "v@b.com", body: "Beautiful.", status: :published)
    memory.replies.create!(name: "Other", email: "o@b.com", body: "Pending", status: :pending)

    get memories_path

    # Published reply visible
    assert_match "Beautiful.", response.body
    # Pending reply NOT visible
    assert_no_match "Pending", response.body
  end

  test "memory card has a hidden reply composer that toggles" do
    Memory.create!(date: Date.today, content: "x", name: "A", email: "a@b.com", kind: :text, status: :published)

    get memories_path

    # Composer markup present but hidden by default
    assert_select "[data-reply-toggle-target='composer'][hidden]"
    # Form for reply submission targets the nested route
    assert_select "form[action*='/replies']"
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/timeline_test.rb -n /memory_card_with_replies|reply_composer/ -v
```

Expected: 2 failures.

- [ ] **Step 3: Create _reply.html.erb**

```erb
<%# Single published reply — linen-bg block below the parent card footer.
    Local: reply %>
<div class="bg-linen rounded-md p-4 mt-3 ml-4 border-l-2 border-sage/30">
  <p class="font-serif text-[15px] leading-snug text-ink m-0"><%= reply.body %></p>
  <div class="mt-2 flex items-baseline gap-3">
    <span class="text-sm font-medium text-ink">— <%= reply.name %></span>
    <% if reply.relationship.present? %>
      <span class="text-eyebrow text-sage"><%= reply.relationship %></span>
    <% end %>
  </div>
</div>
```

- [ ] **Step 4: Create _reply_composer.html.erb**

```erb
<%# Inline reply form. Hidden until ↩ Reply button is clicked.
    Local: memory %>
<div data-reply-toggle-target="composer" hidden class="mt-4 p-4 bg-linen rounded-md">
  <%= form_with model: [memory, Reply.new], local: true, class: "space-y-3" do |f| %>
    <%= f.text_area :body, required: true, rows: 3,
          class: "w-full border border-ink/15 rounded-md p-3 text-sm focus:border-moss outline-none bg-white",
          placeholder: "Write a reply..." %>
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
      <%= f.text_field :name, required: true,
            value: current_user&.name,
            placeholder: "Your name",
            class: "border border-ink/15 rounded-md p-2 text-sm focus:border-moss outline-none bg-white" %>
      <% unless user_signed_in? %>
        <%= f.email_field :email, required: true,
              placeholder: "Email (kept private)",
              class: "border border-ink/15 rounded-md p-2 text-sm focus:border-moss outline-none bg-white" %>
      <% end %>
    </div>
    <div class="flex justify-end gap-3">
      <button type="button" data-action="reply-toggle#close"
              class="text-sm text-ink/60 hover:text-moss">Cancel</button>
      <%= f.submit "Post reply",
            class: "bg-moss text-cream rounded-full px-4 py-2 text-sm font-medium cursor-pointer hover:bg-ink" %>
    </div>
  <% end %>
</div>
```

- [ ] **Step 5: Create reply_toggle_controller.js**

Create `app/javascript/controllers/reply_toggle_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["composer"]

  toggle() {
    this.composerTarget.hidden = !this.composerTarget.hidden
  }

  close() {
    this.composerTarget.hidden = true
  }
}
```

- [ ] **Step 6: Update _card_footer.html.erb to wire the Reply button**

Edit `app/views/memories/_card_footer.html.erb`. Change the Reply button block from:

```erb
    <button type="button"
            class="border border-ink/20 text-ink/70 hover:border-moss hover:text-moss rounded-full px-3 py-1 text-xs">
      ↩ Reply
    </button>
```

to:

```erb
    <button type="button"
            data-action="reply-toggle#toggle"
            class="border border-ink/20 text-ink/70 hover:border-moss hover:text-moss rounded-full px-3 py-1 text-xs">
      ↩ Reply
    </button>
```

- [ ] **Step 7: Update the three card variants to render replies + composer + wrap in reply-toggle controller**

Each variant's `<article>` element needs `data-controller="reply-toggle"`, and after the footer, render existing replies and the composer.

Edit `app/views/memories/_text_card.html.erb`. Change the article wrapper:

```erb
<article data-memory-id="<%= memory.id %>" data-kind="text"
         data-controller="reply-toggle"
         class="bg-white rounded-md border border-ink/8 shadow-card p-7 max-w-[480px] mx-auto mb-12 lg:mb-16 lg:<%= memory.id.odd? ? 'mr-auto lg:ml-0' : 'ml-auto lg:mr-0' %>">
```

And after the `<%= render "memories/card_footer", memory: memory %>` line (still inside `<article>`), add:

```erb
  <% memory.replies.each do |reply| %>
    <%= render "memories/reply", reply: reply %>
  <% end %>
  <%= render "memories/reply_composer", memory: memory %>
</article>
```

Make the equivalent updates to `_photo_card.html.erb` and `_audio_card.html.erb` — add `data-controller="reply-toggle"` to the article tag, and render replies + composer inside the inner `<div class="p-7">` (after the existing footer render).

For `_photo_card.html.erb`, the existing inner structure is:

```erb
  <div class="p-7">
    <div class="text-eyebrow text-sage">...</div>
    ...
    <%= render "memories/card_footer", memory: memory %>
  </div>
</article>
```

Change to:

```erb
  <div class="p-7">
    <div class="text-eyebrow text-sage">...</div>
    ...
    <%= render "memories/card_footer", memory: memory %>
    <% memory.replies.each do |reply| %>
      <%= render "memories/reply", reply: reply %>
    <% end %>
    <%= render "memories/reply_composer", memory: memory %>
  </div>
</article>
```

Same shape for `_audio_card.html.erb`.

- [ ] **Step 8: Run tests**

```bash
bin/rails test test/integration/timeline_test.rb -n /memory_card_with_replies|reply_composer/ -v
```

Expected: 2 runs, both pass.

- [ ] **Step 9: Run full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 149 runs, all pass.

- [ ] **Step 10: Commit**

```bash
git add app/views/memories/ app/javascript/controllers/reply_toggle_controller.js test/integration/timeline_test.rb
git commit -m "Phase 3: reply partials + inline composer with toggle controller"
```

---

## Task 9: Share-a-Memory modal

**Files:**
- Create: `app/views/shared/_share_modal.html.erb`
- Create: `app/javascript/controllers/share_modal_controller.js`
- Create: `app/javascript/controllers/share_modal_trigger_controller.js`
- Create: `app/javascript/controllers/auto_open_share_modal_controller.js`
- Modify: `app/views/layouts/application.html.erb` — render the modal partial
- Modify: `app/views/memories/new.html.erb` — load index template + auto-open
- Modify: `app/views/shared/_home_nav.html.erb` — change "Share a memory" button to use modal trigger
- Modify: `app/views/pages/home/_hero.html.erb` — change "+ Share a memory" CTA to use modal trigger
- Modify: `app/views/pages/home/_honor_grid.html.erb` — Share a Memory card stays a link; no change needed
- Create: `test/integration/share_modal_test.rb`

The big task. The modal lives in the layout once. Every Share-a-memory button on every page dispatches an event that opens the dialog.

- [ ] **Step 1: Write failing integration tests**

Create `test/integration/share_modal_test.rb`:

```ruby
require "test_helper"

class ShareModalTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "share modal is present in the application layout on the homepage" do
    get root_path
    assert_select "dialog#share-modal[data-controller='share-modal']"
  end

  test "share modal is present on the timeline page" do
    get memories_path
    assert_select "dialog#share-modal"
  end

  test "homepage Share a memory button is wired to open the modal" do
    get root_path
    assert_select "button[data-controller~='share-modal-trigger']", minimum: 1
  end

  test "GET /timeline/new renders timeline with auto-open controller" do
    get new_memory_path
    assert_response :success
    assert_select "[data-controller~='auto-open-share-modal']"
  end

  test "modal has step 1 form fields visible by default" do
    get root_path
    assert_select "[data-share-modal-target='step1']" do
      assert_select "textarea[name='memory[content]']"
      assert_select "input[name='memory[date]']"
      assert_select "input[name='memory[location]']"
    end
  end

  test "modal has step 2 form fields hidden by default" do
    get root_path
    assert_select "[data-share-modal-target='step2'][hidden]" do
      assert_select "input[name='memory[name]']"
      assert_select "input[name='memory[relationship]']"
    end
  end

  test "anonymous modal shows email field on step 2" do
    get root_path
    assert_select "[data-share-modal-target='step2'] input[name='memory[email]']"
  end

  test "signed-in modal hides email field on step 2" do
    user = sign_in_contributor
    get root_path
    assert_select "[data-share-modal-target='step2'] input[name='memory[email]']", 0
  end

  test "modal form posts to memories_path with multipart" do
    get root_path
    assert_select "dialog#share-modal form[action=?][enctype='multipart/form-data']", memories_path
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/share_modal_test.rb -v
```

Expected: 9 failures (no modal rendered, no controller).

- [ ] **Step 3: Create the share_modal partial**

Create `app/views/shared/_share_modal.html.erb`:

```erb
<%# Share-a-Memory dialog — rendered once at the bottom of the application layout.
    Opens via JS on any element with data-action="share-modal-trigger#open". %>
<dialog id="share-modal"
        data-controller="share-modal"
        data-share-modal-current-step-value="1"
        class="rounded-lg bg-cream max-w-[640px] w-[92vw] p-0 backdrop:bg-ink/40">
  <%= form_with model: Memory.new, url: memories_path, multipart: true,
        local: true, data: { share_modal_target: "form" }, html: { class: "block" } do |f| %>

    <header class="px-8 pt-7 pb-4 border-b border-ink/8">
      <div class="text-eyebrow text-sage" data-share-modal-target="stepLabel">Step 1 of 2 · The memory</div>
      <div class="h-1 bg-ink/8 mt-2 rounded-full overflow-hidden">
        <div class="h-full bg-moss transition-all duration-300" style="width: 50%;" data-share-modal-target="progress"></div>
      </div>
    </header>

    <div data-share-modal-target="step1" class="p-8 space-y-6">
      <h2 class="font-serif text-4xl text-ink m-0">Tell us about a <em class="font-serif italic text-moss">moment</em>.</h2>

      <div>
        <label class="text-eyebrow text-sage block mb-1">Your memory</label>
        <%= f.text_area :content, rows: 6,
              class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white",
              placeholder: "A photo, a story, a recording — something specific you want to keep." %>
      </div>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="text-eyebrow text-sage block mb-1">When did it happen?</label>
          <%= f.date_field :date, required: true,
                class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
        </div>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Where?</label>
          <%= f.text_field :location,
                class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white",
                placeholder: "Stavanger, Norway" %>
        </div>
      </div>

      <div>
        <div class="text-eyebrow text-sage mb-2">Attach (optional)</div>
        <div class="flex gap-3 flex-wrap">
          <label class="cursor-pointer border border-dashed border-ink/30 rounded-full px-4 py-2 text-sm hover:border-moss inline-flex items-center">
            <span>Photo</span>
            <%= f.file_field :photos, multiple: true, accept: "image/*",
                  class: "hidden", data: { share_modal_target: "photoInput" } %>
          </label>
          <label class="cursor-pointer border border-dashed border-ink/30 rounded-full px-4 py-2 text-sm hover:border-moss inline-flex items-center">
            <span>Audio clip</span>
            <%= f.file_field :audio_clip, accept: "audio/*",
                  class: "hidden", data: { share_modal_target: "audioInput" } %>
          </label>
        </div>
        <div data-share-modal-target="attachments" class="mt-3 text-sm text-sage"></div>
      </div>

      <%= f.hidden_field :kind, value: "text", data: { share_modal_target: "kindInput" } %>
    </div>

    <div data-share-modal-target="step2" hidden class="p-8 space-y-6">
      <h2 class="font-serif text-4xl text-ink m-0">Who's <em class="font-serif italic text-moss">remembering</em>?</h2>

      <div class="grid grid-cols-1 sm:grid-cols-2 gap-4">
        <div>
          <label class="text-eyebrow text-sage block mb-1">Your name</label>
          <%= f.text_field :name, value: current_user&.name, required: true,
                class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
        </div>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Relationship to Chris</label>
          <%= f.text_field :relationship,
                class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white",
                placeholder: "Friend · Colleague · Family · …" %>
        </div>
      </div>

      <% unless user_signed_in? %>
        <div>
          <label class="text-eyebrow text-sage block mb-1">Email (kept private)</label>
          <%= f.email_field :email, required: true,
                class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
        </div>

        <div class="bg-moss/8 border border-moss/20 rounded-md p-4 text-sm text-ink">
          Signed-in users have memories posted immediately. Anonymous submissions go to a moderation queue and appear after review.
        </div>
      <% end %>
    </div>

    <footer class="px-8 py-5 border-t border-ink/8 flex justify-between items-center">
      <button type="button" data-action="share-modal#close" class="text-sm text-ink/60 hover:text-moss">Cancel</button>

      <div class="flex gap-3">
        <button type="button" data-action="share-modal#back" data-share-modal-target="backButton" hidden class="text-sm text-ink/60 hover:text-moss px-4 py-2">← Back</button>
        <button type="button" data-action="share-modal#next" data-share-modal-target="nextButton" class="bg-moss text-cream rounded-full px-5 py-2.5 text-sm font-medium cursor-pointer hover:bg-ink">Continue →</button>
        <%= f.submit "Plant memory", data: { share_modal_target: "submitButton" }, hidden: true,
              class: "bg-moss text-cream rounded-full px-5 py-2.5 text-sm font-medium cursor-pointer hover:bg-ink" %>
      </div>
    </footer>
  <% end %>
</dialog>
```

- [ ] **Step 4: Create the share_modal Stimulus controller**

Create `app/javascript/controllers/share_modal_controller.js`:

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
    // Listen for the global "share-modal:open" event so trigger buttons can request open.
    this.boundOpen = () => this.open()
    document.addEventListener("share-modal:open", this.boundOpen)
  }

  disconnect() {
    document.removeEventListener("share-modal:open", this.boundOpen)
  }

  open() {
    this.element.showModal()
    this.currentStepValue = 1
  }

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

  back() {
    this.currentStepValue = 1
  }

  handlePhotoSelect() {
    if (this.photoInputTarget.files.length > 0) this.kindInputTarget.value = "photo"
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
    if (!date.value) {
      date.focus()
      return false
    }
    return true
  }

  isDirty() {
    const fd = new FormData(this.formTarget)
    for (const [, v] of fd) {
      if (v && v.toString().trim()) return true
    }
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

- [ ] **Step 5: Create the share_modal_trigger Stimulus controller**

Create `app/javascript/controllers/share_modal_trigger_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Tiny shim: dispatches a custom event the modal listens for.
  // Decouples buttons from knowing about the modal's DOM id.
  open() {
    document.dispatchEvent(new CustomEvent("share-modal:open"))
  }
}
```

- [ ] **Step 6: Create the auto_open_share_modal Stimulus controller**

Create `app/javascript/controllers/auto_open_share_modal_controller.js`:

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.dispatchEvent(new CustomEvent("share-modal:open"))
  }
}
```

- [ ] **Step 7: Render the modal in the application layout**

Edit `app/views/layouts/application.html.erb`. Before the closing `</body>`, add:

```erb
    <%= render "shared/share_modal" %>
```

So the bottom of the body looks roughly:

```erb
    <%= render "shared/site_footer" %>
    <%= render "shared/share_modal" %>
  </body>
```

- [ ] **Step 8: Rewrite memories/new.html.erb to load the timeline + auto-open**

Replace `app/views/memories/new.html.erb` with:

```erb
<%# Direct URL /timeline/new — render the timeline with the modal auto-opening. %>
<div data-controller="auto-open-share-modal" class="hidden"></div>
<%= render template: "memories/index" %>
```

(The `data-controller="auto-open-share-modal"` div fires the open event when Stimulus connects.)

For this template render to work, the controller's `new` action sets all the timeline page instance variables. Currently the `new` action just does `@memory = Memory.new(...)`. Update it to also load the timeline:

Edit `app/controllers/memories_controller.rb`'s `new` action:

```ruby
  def new
    @memory = Memory.new(kind: :text, date: Date.today)
    # Pre-load timeline locals so the rendered index template has data.
    scope = Memory.published.includes(:user, :replies).order(date: :desc)
    @years = Memory.published.pluck("strftime('%Y', date)").uniq.sort.reverse.map(&:to_i)
    @active_year = nil
    @memories = scope
    @memories_count = scope.count
    @contributors_count = User.joins(:memories).distinct.count +
                          Memory.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
  end
```

(Repetition with `index` is real — a tiny helper method `private def load_timeline_locals` would DRY it up. Acceptable for Phase 3 since they're 6 lines and not changing.)

- [ ] **Step 9: Update _home_nav.html.erb Share a memory button**

Edit `app/views/shared/_home_nav.html.erb`. There are two "Share a memory" links (desktop + mobile menu) that currently link to `new_memory_path`. Update them to be buttons triggering the modal:

Find:

```erb
<%= link_to "Share a memory", new_memory_path,
      class: "bg-moss text-cream rounded-full px-5 py-2.5 text-sm no-underline hover:bg-ink transition-colors" %>
```

Replace with:

```erb
<button type="button"
        data-controller="share-modal-trigger"
        data-action="share-modal-trigger#open"
        class="bg-moss text-cream rounded-full px-5 py-2.5 text-sm cursor-pointer hover:bg-ink transition-colors">
  Share a memory
</button>
```

Do the same for the mobile-menu version. Both should become buttons.

- [ ] **Step 10: Update the hero's Share a memory CTA**

Edit `app/views/pages/home/_hero.html.erb`. Find:

```erb
<%= link_to "+ Share a memory", new_memory_path,
      class: "bg-transparent text-ink border border-ink/20 rounded-full px-6 py-4 text-[15px] no-underline hover:border-moss hover:text-moss transition-colors" %>
```

Replace with:

```erb
<button type="button"
        data-controller="share-modal-trigger"
        data-action="share-modal-trigger#open"
        class="bg-transparent text-ink border border-ink/20 rounded-full px-6 py-4 text-[15px] cursor-pointer hover:border-moss hover:text-moss transition-colors">
  + Share a memory
</button>
```

(Don't update the MVT I honor-grid Share a Memory card — it's a card that links to `new_memory_path`. That still works: hitting `/timeline/new` auto-opens the modal. Keeping that card as a link preserves direct-URL access and screen-reader friendliness.)

- [ ] **Step 11: Run modal integration tests**

```bash
bin/rails test test/integration/share_modal_test.rb -v
```

Expected: 9 runs, all pass.

- [ ] **Step 12: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 158 runs, all pass (was 149 + 9).

If any tests on `_home_nav` or `_hero` broke because they asserted against `link_to ... new_memory_path` with `text: /Share a memory/`, update those tests to assert against the button:

```ruby
assert_select "button", text: /Share a memory/
```

- [ ] **Step 13: Commit**

```bash
git add app/views/shared/_share_modal.html.erb app/views/shared/_home_nav.html.erb \
        app/views/pages/home/_hero.html.erb app/views/memories/new.html.erb \
        app/views/layouts/application.html.erb \
        app/controllers/memories_controller.rb \
        app/javascript/controllers/share_modal_controller.js \
        app/javascript/controllers/share_modal_trigger_controller.js \
        app/javascript/controllers/auto_open_share_modal_controller.js \
        test/integration/share_modal_test.rb
git commit -m "Phase 3: Share-a-Memory modal (two-step, anonymous-friendly, audio/photo attach)"
```

---

## Task 10: Update homepage MVT II preview card to use `kind` enum

**Files:**
- Modify: `app/views/pages/home/_preview_card.html.erb`
- Verify: existing homepage tests still pass

- [ ] **Step 1: Inspect current preview_card branching**

```bash
cat app/views/pages/home/_preview_card.html.erb
```

The current `<% if memory.photos.attached? %>` block infers type. Update to use the new enum.

- [ ] **Step 2: Replace the kind detection**

Edit `app/views/pages/home/_preview_card.html.erb`. Change:

```erb
<% if memory.photos.attached? %>
```

to:

```erb
<% if memory.kind_photo? %>
```

And add an audio variant block above the existing photo block (or after — order doesn't matter):

```erb
<% if memory.kind_audio? %>
  <%# Audio preview — small static badge, not the full player. %>
  <div class="bg-moss text-cream p-4 flex items-center gap-3">
    <span class="w-10 h-10 rounded-full bg-cream text-moss flex items-center justify-center text-lg" aria-hidden="true">▶</span>
    <div class="flex-1 min-w-0">
      <% if memory.audio_label.present? %>
        <div class="font-serif italic text-base truncate"><%= memory.audio_label %></div>
      <% end %>
      <div class="text-eyebrow text-cream/80 mt-1">Audio recording · listen on the timeline</div>
    </div>
  </div>
<% end %>
```

Also update the footer's type label line to use the enum:

Find:

```erb
<span class="text-eyebrow text-sage">
  <%= memory.photos.attached? ? "photograph" : "letter" %>
</span>
```

Replace with:

```erb
<span class="text-eyebrow text-sage">
  <%= { "text" => "letter", "photo" => "photograph", "audio" => "recording" }[memory.kind] %>
</span>
```

- [ ] **Step 3: Run homepage tests**

```bash
bin/rails test test/integration/homepage_test.rb -v
```

Expected: all pass. The Phase 2 tests assert behavior, not the specific `photos.attached?` predicate, so they should still pass.

- [ ] **Step 4: Run full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 158 runs, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add app/views/pages/home/_preview_card.html.erb
git commit -m "Phase 3: homepage MVT II preview card uses Memory#kind enum"
```

---

## Task 11: Final verification

**Files:** none (or minor fixes if verification surfaces issues)

- [ ] **Step 1: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 158 runs, 0 failures, 0 errors, 0 skips.

- [ ] **Step 2: Reset DB + start server**

```bash
lsof -ti:3000 | xargs kill 2>/dev/null
bin/rails db:reset 2>&1 | tail -5
bin/rails server &
SERVER_PID=$!
sleep 4
```

- [ ] **Step 3: HTTP smoke checks**

```bash
echo "=== HTTP status checks ===" && \
  for path in / /timeline /timeline/new /chris /style-guide; do
    code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000$path)
    echo "$path → $code"
  done

echo "=== Content checks ===" && \
  curl -s http://localhost:3000/ | grep -c "share-modal"
  curl -s http://localhost:3000/timeline | grep -c "Op. III"
  curl -s http://localhost:3000/timeline | grep -c "data-year-filter"
  curl -s http://localhost:3000/timeline | grep -c "he was"
  curl -s http://localhost:3000/timeline?year=2014 | grep -c "Munich"
  curl -s http://localhost:3000/timeline/new | grep -c "auto-open-share-modal"
```

Expected: all paths return 200. Each grep returns ≥1.

- [ ] **Step 4: Stop the server**

```bash
kill $SERVER_PID
sleep 1
```

- [ ] **Step 5: Visual + interaction check (manual)**

Start `bin/rails server` and open `http://localhost:3000` in a browser. Verify:

- **Homepage** — "Share a memory" buttons (nav + hero) open the modal.
- **Modal step 1** — content textarea, date, location, photo/audio attach. "Continue" advances.
- **Modal step 2** — name (pre-filled if signed in), relationship, email (anonymous only). "Plant memory" submits.
- **Submission** — anonymous: redirects to /timeline with "queued for review" message. Signed-in: redirects with "live on the timeline" message and the memory appears.
- **/timeline** — header, year filter chips work, year markers show "he was N", cards alternate left/right on desktop.
- **Photo card** — placeholder gradient renders when no photo. Real photo renders when attached.
- **Audio card** — moss header strip; clicking ▶ plays through wavesurfer (try uploading any small mp3 via the modal).
- **Reply button** — opens inline composer below card. Submitting creates a reply (signed-in: visible; anonymous: queued).
- **/timeline/new** — direct URL loads the timeline with modal pre-opened.
- **Resize to 375px** — modal fits; cards stack to one column; year filter scrolls horizontally; spine hidden.

Stop the server when done.

- [ ] **Step 6: Final commit (only if fixups needed)**

If verification surfaced a real bug and you fixed it:

```bash
git add -A
git commit -m "Phase 3: verification fixups"
```

If nothing changed: skip.

- [ ] **Step 7: Phase 3 complete**

Timeline + Share-a-Memory shipped. Phase 4 picks up the remaining inner pages (Biography, Tributes, Trees, News, Recipes).

---

## Self-review notes (post-write)

- ✓ Every spec section maps to a task:
  - Schema migration → T1
  - Memory model changes → T2
  - Reply model + routes → T3
  - MemoriesController updates → T4
  - RepliesController → T5
  - Timeline page header/spine/filter → T6
  - Memory card variants → T7
  - Replies UI → T8
  - Share modal → T9
  - Homepage MVT II update → T10
  - Final verification → T11

- ✓ Open questions from spec resolved:
  - DB: SQLite confirmed; `strftime` used.
  - Audio seed data: skipped (real audio via content task).
  - Spam protection: out of scope (moderation is the safety net).
  - Reply notifications: out of scope.

- ✓ No "TODO", "TBD", "implement later" placeholders. Each step has executable code.

- ✓ Type/name consistency:
  - `Memory#kind` enum with `prefix: :kind` → predicates `kind_text?`, `kind_photo?`, `kind_audio?` used consistently throughout.
  - `Memory#display_name`, `Memory#display_relationship`, `Memory::CHRIS_BIRTH_YEAR` defined once in T2, referenced in T6, T7, T10.
  - Stimulus controller names: `share-modal`, `share-modal-trigger`, `auto-open-share-modal`, `audio-player`, `reply-toggle`. Each referenced consistently across views and JS files.
  - Routes: `memory_replies_path(memory)` used in T5 tests, T8 form, generated by the nested `resources :replies, only: [:create]` route.
  - Data attributes: `data-memory-id`, `data-kind`, `data-year-filter`, `data-share-modal-target`, `data-reply-toggle-target` — all referenced consistently.

- ✓ Test discipline: every task with new production code starts with a failing test.

- ✓ Each task ends with a single, focused commit.

Known scope risks:

- **Task 9 is large** (modal + 3 controllers + layout changes + 2 callsite swaps + 9 tests). If implementation feels long mid-flight, the natural split point is "modal markup + share_modal controller" in 9a and "trigger/auto-open controllers + callsite swaps + tests" in 9b. Decide based on context budget.

- **wavesurfer.js network fetch**: importmap pulls from a CDN at runtime. In test environment, no network = no audio playback. Audio integration tests don't actually exercise wavesurfer — they only assert the controller attribute is on the markup. Manual visual verification (T11) is the only check that wavesurfer actually plays. Acceptable for Phase 3.

- **Reply moderation admin UI gap**: pending replies have no admin view. Admin can update them via the Rails console or by adding a future admin/replies controller. Out of scope.
