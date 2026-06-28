# Biographical Milestones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add admin-authored biographical milestones (e.g. "Born in Tokyo") that interleave into the public `/timeline` as distinct, centered markers — separate from community memories.

**Architecture:** A new standalone `Milestone` ActiveRecord model (no submitter, no moderation, no replies, no map pin) managed through an admin CRUD resource. The public timeline controller merges published memories and all milestones into one year-grouped, date-ordered structure; the view renders each item with either the existing memory card partial or a new milestone partial. Memory and contributor counts stay memories-only.

**Tech Stack:** Rails 8, Minitest (integration + model tests), Tailwind CSS v4, rails_icons (lucide), Devise (admin auth via `sign_in_admin` test helper).

## Global Constraints

- Ruby/Rails: match existing app (Rails 8). Use the project's existing conventions.
- TDD: every behavior gets a failing test first, then minimal implementation.
- Milestones must **never** be counted in `@memories_count` or `@contributors_count`.
- Milestones do **not** include the `Mappable` concern and get no map pin / geocoding.
- Milestone `date` is required and used only for sorting; the per-entry date is **not** displayed (items sit under the year marker). `headline` is required.
- Admin auth: admin controllers inherit `Admin::BaseController` (which runs `authenticate_admin!`). Tests sign in via `sign_in_admin` (from `SignInHelper` in `test/test_helper.rb`).
- Run the full suite with `bin/rails test`; run a single file with `bin/rails test path/to/test.rb`.

---

### Task 1: Milestone model + migration

**Files:**
- Create: `db/migrate/<timestamp>_create_milestones.rb`
- Create: `app/models/milestone.rb`
- Test: `test/models/milestone_test.rb`
- Modify (generated): `db/schema.rb` (via migration)

**Interfaces:**
- Produces: `Milestone` with attributes `date:date`, `headline:string`, `description:text`, `icon:string`, `location:string`; instance methods `#year -> Integer`, `#age -> Integer`; scope `.chronological` (order by date asc). Validations: `date` and `headline` required.
- Consumes: `Memory::CHRIS_BIRTH_YEAR` (existing constant, value `1984`) for `#age`.

- [ ] **Step 1: Generate the migration**

Run:
```bash
bin/rails generate migration CreateMilestones
```
Then replace the generated file body with:
```ruby
class CreateMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :milestones do |t|
      t.date    :date,        null: false
      t.string  :headline,    null: false
      t.text    :description
      t.string  :icon
      t.string  :location

      t.timestamps
    end

    add_index :milestones, :date
  end
end
```

- [ ] **Step 2: Run the migration**

Run:
```bash
bin/rails db:migrate
```
Expected: `create_table(:milestones)` runs, `db/schema.rb` now contains a `milestones` table.

- [ ] **Step 3: Write the failing model test**

Create `test/models/milestone_test.rb`:
```ruby
require "test_helper"

class MilestoneTest < ActiveSupport::TestCase
  test "valid with date and headline" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    assert milestone.valid?, milestone.errors.full_messages.inspect
  end

  test "invalid without date" do
    milestone = Milestone.new(headline: "Born in Tokyo")
    assert_not milestone.valid?
    assert_includes milestone.errors[:date], "can't be blank"
  end

  test "invalid without headline" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1))
    assert_not milestone.valid?
    assert_includes milestone.errors[:headline], "can't be blank"
  end

  test "description, icon, location are optional" do
    milestone = Milestone.new(date: Date.new(1984, 1, 1), headline: "Born")
    assert milestone.valid?
    assert_nil milestone.description
    assert_nil milestone.icon
    assert_nil milestone.location
  end

  test "year is derived from date" do
    milestone = Milestone.new(date: Date.new(2002, 9, 1), headline: "Dartmouth")
    assert_equal 2002, milestone.year
  end

  test "age is year minus 1984" do
    milestone = Milestone.new(date: Date.new(2002, 9, 1), headline: "Dartmouth")
    assert_equal 18, milestone.age
  end

  test "chronological scope orders by date ascending" do
    later   = Milestone.create!(date: Date.new(2019, 5, 1), headline: "Stavanger")
    earlier = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born")
    assert_equal [ earlier, later ], Milestone.chronological.to_a
  end
end
```

- [ ] **Step 4: Run the test to verify it fails**

Run:
```bash
bin/rails test test/models/milestone_test.rb
```
Expected: FAIL — `uninitialized constant MilestoneTest::Milestone` (model does not exist yet).

- [ ] **Step 5: Write the model**

Create `app/models/milestone.rb`:
```ruby
class Milestone < ApplicationRecord
  validates :date,     presence: true
  validates :headline, presence: true

  scope :chronological, -> { order(:date) }

  def year = date.year
  def age  = year - Memory::CHRIS_BIRTH_YEAR
end
```

- [ ] **Step 6: Run the test to verify it passes**

Run:
```bash
bin/rails test test/models/milestone_test.rb
```
Expected: PASS (7 runs, 0 failures).

- [ ] **Step 7: Commit**

```bash
git add db/migrate db/schema.rb app/models/milestone.rb test/models/milestone_test.rb
git commit -m "Milestone model: biographical timeline entries"
```

---

### Task 2: Admin CRUD for milestones

**Files:**
- Modify: `config/routes.rb` (add `resources :milestones` inside `namespace :admin`)
- Create: `app/controllers/admin/milestones_controller.rb`
- Create: `app/views/admin/milestones/index.html.erb`
- Create: `app/views/admin/milestones/new.html.erb`
- Create: `app/views/admin/milestones/edit.html.erb`
- Create: `app/views/admin/milestones/_form.html.erb`
- Modify: `app/views/layouts/admin.html.erb` (sidebar link)
- Modify: `app/controllers/admin/dashboard_controller.rb` (milestone count)
- Modify: `app/views/admin/dashboard/index.html.erb` (count tile)
- Test: `test/integration/admin_milestones_test.rb`

**Interfaces:**
- Consumes: `Milestone` (Task 1); `Admin::BaseController`; `sign_in_admin` helper.
- Produces: routes `admin_milestones_path`, `new_admin_milestone_path`, `edit_admin_milestone_path(milestone)`, `admin_milestone_path(milestone)`; `Admin::MilestonesController` with index/new/create/edit/update/destroy; strong params permitting `:date, :headline, :description, :icon, :location`.

- [ ] **Step 1: Write the failing admin integration test**

Create `test/integration/admin_milestones_test.rb`:
```ruby
require "test_helper"

class AdminMilestonesTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "index renders for admin" do
    sign_in_admin
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get admin_milestones_path
    assert_response :success
    assert_match "Born in Tokyo", response.body
  end

  test "new form renders for admin" do
    sign_in_admin
    get new_admin_milestone_path
    assert_response :success
  end

  test "admin can create a milestone" do
    sign_in_admin
    assert_difference -> { Milestone.count }, 1 do
      post admin_milestones_path, params: {
        milestone: { date: "1984-01-01", headline: "Born in Tokyo",
                     description: "The beginning.", location: "Tokyo, Japan" }
      }
    end
    created = Milestone.order(:created_at).last
    assert_equal "Born in Tokyo", created.headline
    assert_redirected_to admin_milestones_path
  end

  test "create with missing headline re-renders with error" do
    sign_in_admin
    assert_no_difference -> { Milestone.count } do
      post admin_milestones_path, params: { milestone: { date: "1984-01-01", headline: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin can update a milestone" do
    sign_in_admin
    milestone = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Old")
    patch admin_milestone_path(milestone), params: { milestone: { headline: "New headline" } }
    assert_equal "New headline", milestone.reload.headline
    assert_redirected_to admin_milestones_path
  end

  test "admin can destroy a milestone" do
    sign_in_admin
    milestone = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born")
    assert_difference -> { Milestone.count }, -1 do
      delete admin_milestone_path(milestone)
    end
  end

  test "non-admin is redirected away" do
    sign_in_contributor
    get admin_milestones_path
    assert_redirected_to root_path
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bin/rails test test/integration/admin_milestones_test.rb
```
Expected: FAIL — `undefined local variable or method 'admin_milestones_path'` (route absent).

- [ ] **Step 3: Add the route**

In `config/routes.rb`, inside the `namespace :admin do` block, after the `resources :memories` line (currently around line 35), add:
```ruby
    resources :milestones, only: [ :index, :new, :create, :edit, :update, :destroy ]
```

- [ ] **Step 4: Write the controller**

Create `app/controllers/admin/milestones_controller.rb`:
```ruby
class Admin::MilestonesController < Admin::BaseController
  before_action :set_milestone, only: [ :edit, :update, :destroy ]

  def index
    @milestones = Milestone.chronological
  end

  def new
    @milestone = Milestone.new
  end

  def create
    @milestone = Milestone.new(milestone_params)
    if @milestone.save
      redirect_to admin_milestones_path, notice: "Milestone created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @milestone.update(milestone_params)
      redirect_to admin_milestones_path, notice: "Milestone updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @milestone.destroy
    redirect_to admin_milestones_path, notice: "Milestone deleted."
  end

  private

  def set_milestone
    @milestone = Milestone.find(params[:id])
  end

  def milestone_params
    params.require(:milestone).permit(:date, :headline, :description, :icon, :location)
  end
end
```

- [ ] **Step 5: Write the form partial**

Create `app/views/admin/milestones/_form.html.erb`:
```erb
<%= form_with model: [:admin, record], local: true, class: "space-y-6 max-w-3xl" do |f| %>
  <% if record.errors.any? %>
    <div class="bg-red-50 border-l-4 border-red-400 p-4">
      <ul class="text-red-700 text-sm">
        <% record.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
    <div>
      <%= f.label :date, class: "block text-sm font-medium text-stone-700 mb-1" %>
      <%= f.date_field :date, class: "w-full px-3 py-2 border border-stone-300 rounded" %>
      <p class="text-xs text-stone-500 mt-1">Used to place the milestone in the timeline. The timeline shows it under its year, not the exact day.</p>
    </div>
    <div>
      <%= f.label :icon, "Icon (optional)", class: "block text-sm font-medium text-stone-700 mb-1" %>
      <%= f.text_field :icon, placeholder: "Lucide name, e.g. star, music, graduation-cap", class: "w-full px-3 py-2 border border-stone-300 rounded" %>
    </div>
  </div>

  <div>
    <%= f.label :headline, class: "block text-sm font-medium text-stone-700 mb-1" %>
    <%= f.text_field :headline, placeholder: "Born in Tokyo", class: "w-full px-3 py-2 border border-stone-300 rounded" %>
  </div>

  <div>
    <%= f.label :description, "Description (optional)", class: "block text-sm font-medium text-stone-700 mb-1" %>
    <%= f.text_area :description, rows: 4, class: "w-full px-3 py-2 border border-stone-300 rounded" %>
  </div>

  <div>
    <%= f.label :location, "Location (optional)", class: "block text-sm font-medium text-stone-700 mb-1" %>
    <%= f.text_field :location, placeholder: "Tokyo, Japan", class: "w-full px-3 py-2 border border-stone-300 rounded" %>
  </div>

  <div class="flex gap-3">
    <%= f.submit (record.new_record? ? "Create" : "Save"),
          class: "px-4 py-2 bg-stone-800 text-white rounded hover:bg-stone-700 transition cursor-pointer" %>
    <%= link_to "Cancel", admin_milestones_path,
          class: "px-4 py-2 border border-stone-300 text-stone-700 rounded hover:bg-stone-100 transition" %>
  </div>
<% end %>
```

- [ ] **Step 6: Write the index, new, and edit views**

Create `app/views/admin/milestones/index.html.erb`:
```erb
<div class="flex items-center justify-between mb-4">
  <h1 class="text-3xl font-title text-stone-800">Milestones</h1>
  <%= link_to "+ New milestone", new_admin_milestone_path,
        class: "px-4 py-2 bg-stone-800 text-white rounded text-sm hover:bg-stone-700 transition" %>
</div>

<div class="space-y-4">
  <% @milestones.each do |milestone| %>
    <div class="bg-white p-6 rounded-lg shadow-sm border border-stone-200">
      <div class="flex justify-between items-start mb-2">
        <div>
          <span class="font-medium text-blue-800"><%= milestone.year %></span>
          <span class="font-medium text-stone-800 ml-2"><%= milestone.headline %></span>
          <% if milestone.location.present? %>
            <span class="text-xs text-stone-400 ml-2"><%= milestone.location %></span>
          <% end %>
        </div>
        <div class="flex gap-3 text-xs">
          <%= link_to "Edit", edit_admin_milestone_path(milestone), class: "text-blue-700 hover:text-blue-600 underline" %>
          <%= button_to "Delete", admin_milestone_path(milestone), method: :delete,
                form: { data: { turbo_confirm: "Delete this milestone?" } },
                class: "text-red-700 hover:text-red-600 underline cursor-pointer" %>
        </div>
      </div>
      <% if milestone.description.present? %>
        <p class="text-stone-600 text-sm"><%= truncate(milestone.description, length: 300) %></p>
      <% end %>
    </div>
  <% end %>
</div>
```

Create `app/views/admin/milestones/new.html.erb`:
```erb
<h1 class="text-3xl font-title text-stone-800 mb-6">New Milestone</h1>

<%= render "form", record: @milestone %>
```

Create `app/views/admin/milestones/edit.html.erb`:
```erb
<h1 class="text-3xl font-title text-stone-800 mb-6">Edit Milestone</h1>

<%= render "form", record: @milestone %>
```

- [ ] **Step 7: Run the admin test to verify it passes**

Run:
```bash
bin/rails test test/integration/admin_milestones_test.rb
```
Expected: PASS (7 runs, 0 failures).

- [ ] **Step 8: Add the sidebar nav link**

In `app/views/layouts/admin.html.erb`, after the "Memories" nav link, add:
```erb
        <%= link_to "Milestones", admin_milestones_path, class: "block px-3 py-2 rounded hover:bg-stone-800 hover:text-white transition" %>
```

- [ ] **Step 9: Add the dashboard count tile**

In `app/controllers/admin/dashboard_controller.rb`, add inside `index`:
```ruby
    @milestones_count = Milestone.count
```

In `app/views/admin/dashboard/index.html.erb`, add a tile inside the grid (after the Bee Hives tile):
```erb
  <%= link_to admin_milestones_path, class: "block bg-white p-6 rounded-lg shadow-sm border border-stone-200 hover:border-blue-300 transition" do %>
    <p class="text-3xl font-bold text-stone-700"><%= @milestones_count %></p>
    <p class="text-stone-500">Milestones</p>
  <% end %>
```

- [ ] **Step 10: Run the dashboard/admin suite to verify nothing broke**

Run:
```bash
bin/rails test test/integration/admin_test.rb test/integration/admin_milestones_test.rb
```
Expected: PASS.

- [ ] **Step 11: Commit**

```bash
git add config/routes.rb app/controllers/admin/milestones_controller.rb app/views/admin/milestones app/views/layouts/admin.html.erb app/controllers/admin/dashboard_controller.rb app/views/admin/dashboard/index.html.erb test/integration/admin_milestones_test.rb
git commit -m "Admin: CRUD for biographical milestones"
```

---

### Task 3: Public timeline integration

**Files:**
- Modify: `app/controllers/memories_controller.rb` (`load_timeline_locals` + new `build_timeline_by_year`)
- Modify: `app/views/memories/index.html.erb` (render merged items)
- Create: `app/views/memories/_milestone.html.erb`
- Test: `test/integration/timeline_milestones_test.rb`

**Interfaces:**
- Consumes: `Milestone` (Task 1); existing `Memory.published`, `memories/_memory_card`, `memories/_year_marker`, `memories/_year_filter` partials; `Memory::CHRIS_BIRTH_YEAR`.
- Produces: controller ivars for the index/new views — `@timeline_by_year` (Hash of `year(Integer) => [items]`, years iterated in descending order, items within a year ordered by date descending, each item is a `Memory` or a `Milestone`), `@years` (descending union of memory + milestone years), unchanged `@memories`, `@memories_count`, `@contributors_count`, `@active_year`.

- [ ] **Step 1: Write the failing timeline integration test**

Create `test/integration/timeline_milestones_test.rb`:
```ruby
require "test_helper"

class TimelineMilestonesTest < ActionDispatch::IntegrationTest
  def setup
    Memory.delete_all
    Milestone.delete_all
    Memory.create!(date: Date.new(2014, 6, 15), content: "Munich concert",
                   name: "Colleague", email: "c@a.com", kind: :text, status: :published)
  end

  test "a milestone renders on the timeline under its year" do
    Milestone.create!(date: Date.new(2014, 3, 1), headline: "Joined the orchestra",
                      description: "A new chapter.")
    get memories_path
    assert_response :success
    assert_match "Joined the orchestra", response.body
    assert_match "A new chapter.", response.body
  end

  test "a milestone anchors a year that has no memories" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    assert_match "Born in Tokyo", response.body
    # 1984 year marker appears even though no memory exists that year
    assert_match "1984", response.body
    assert_match "he was 0", response.body
  end

  test "milestones are excluded from the memory and contributor counts" do
    get memories_path
    baseline = response.body[/(\d+)\s+memor/, 1]

    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    after = response.body[/(\d+)\s+memor/, 1]

    assert_equal baseline, after, "adding a milestone must not change the memory count"
  end

  test "a milestone year appears as a year filter chip" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path
    assert_select "[data-year-filter]" do
      assert_select "a, button", text: "1984"
    end
  end

  test "filtering by a milestone-only year shows the milestone" do
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get memories_path, params: { year: 1984 }
    assert_match "Born in Tokyo", response.body
    assert_no_match "Munich concert", response.body
  end

  test "within a shared year memory and milestone both render" do
    Milestone.create!(date: Date.new(2014, 1, 1), headline: "Milestone in 2014")
    get memories_path, params: { year: 2014 }
    assert_match "Milestone in 2014", response.body
    assert_match "Munich concert", response.body
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

Run:
```bash
bin/rails test test/integration/timeline_milestones_test.rb
```
Expected: FAIL — milestone text not found in body (controller/view do not yet load or render milestones).

- [ ] **Step 3: Update the controller**

In `app/controllers/memories_controller.rb`, replace the entire `load_timeline_locals` method with:
```ruby
  def load_timeline_locals
    @active_year = params[:year]&.to_i

    memory_scope    = Memory.published.includes(:user, :replies).order(date: :desc)
    milestone_scope = Milestone.all

    if @active_year
      range = Date.new(@active_year, 1, 1)..Date.new(@active_year, 12, 31)
      memory_scope    = memory_scope.where(date: range)
      milestone_scope = milestone_scope.where(date: range)
    end

    @memories         = memory_scope
    @timeline_by_year = build_timeline_by_year(@memories, milestone_scope)
    @years            = (Memory.published.pluck(:date) + Milestone.pluck(:date))
                          .map(&:year).uniq.sort.reverse

    @memories_count = @memories.count
    @contributors_count = User.joins(:memories).merge(Memory.published).distinct.count +
                          Memory.published.where(user_id: nil).where.not(email: nil).select(:email).distinct.count
  end

  def build_timeline_by_year(memories, milestones)
    (memories.to_a + milestones.to_a).sort_by(&:date).reverse.group_by(&:year)
  end
```

- [ ] **Step 4: Create the milestone partial**

Create `app/views/memories/_milestone.html.erb`:
```erb
<%# Centered biographical milestone marker on the timeline spine. Local: milestone %>
<div data-milestone-id="<%= milestone.id %>"
     class="relative flex justify-center my-10 text-center">
  <div class="max-w-[420px]">
    <% if milestone.icon.present? %>
      <div class="flex justify-center mb-3 text-accent">
        <%= icon milestone.icon, class: "w-6 h-6" %>
      </div>
    <% end %>
    <% if milestone.location.present? %>
      <div class="font-mono text-[11px] tracking-[0.16em] uppercase text-mono mb-2"><%= milestone.location %></div>
    <% end %>
    <h3 class="font-serif font-medium text-[24px] leading-snug text-ink m-0"><%= milestone.headline %></h3>
    <% if milestone.description.present? %>
      <p class="text-[15px] leading-[1.55] text-muted mt-2 mb-0"><%= milestone.description %></p>
    <% end %>
  </div>
</div>
```

- [ ] **Step 5: Update the index view body**

In `app/views/memories/index.html.erb`, replace the timeline-body conditional (currently the `<% if @memories.any? %> ... <% end %>` block that does `@memories.group_by(&:year)`) with:
```erb
  <% if @timeline_by_year.any? %>
    <% @timeline_by_year.each do |year, items| %>
      <%= render "memories/year_marker", year: year, age: year - Memory::CHRIS_BIRTH_YEAR %>
      <% items.each do |item| %>
        <% if item.is_a?(Milestone) %>
          <%= render "memories/milestone", milestone: item %>
        <% else %>
          <%= render "memories/memory_card", memory: item %>
        <% end %>
      <% end %>
    <% end %>
  <% else %>
    <div class="text-center py-20">
      <p class="font-serif italic text-[22px] text-muted mb-4">No memories for <%= @active_year %>.</p>
      <%= link_to "Clear filter →", memories_path, class: "text-accent text-[15px] font-semibold no-underline hover:opacity-70 transition-opacity" %>
    </div>
  <% end %>
```

- [ ] **Step 6: Run the timeline milestone test to verify it passes**

Run:
```bash
bin/rails test test/integration/timeline_milestones_test.rb
```
Expected: PASS (6 runs, 0 failures).

- [ ] **Step 7: Run the existing timeline test to verify no regression**

Run:
```bash
bin/rails test test/integration/timeline_test.rb
```
Expected: PASS (existing memory-only behavior unchanged).

- [ ] **Step 8: Commit**

```bash
git add app/controllers/memories_controller.rb app/views/memories/index.html.erb app/views/memories/_milestone.html.erb test/integration/timeline_milestones_test.rb
git commit -m "Timeline: interleave biographical milestones with memories"
```

---

### Task 4: Seed sample milestones (development)

**Files:**
- Modify: `db/seeds.rb`

**Interfaces:**
- Consumes: `Milestone` (Task 1). Dev-only seed data; idempotent via `find_or_create_by!`.

- [ ] **Step 1: Add idempotent milestone seeds**

In `db/seeds.rb`, near the existing development memory seeds (around lines 11–32), add:
```ruby
  [
    { date: Date.new(1984, 1, 1),  headline: "Born", location: "Tokyo, Japan",
      description: "The beginning of a life that would touch people across nine countries." },
    { date: Date.new(2002, 9, 1),  headline: "Began studies at Dartmouth", location: "Hanover, NH" },
    { date: Date.new(2019, 5, 1),  headline: "Appointed at the Stavanger Symphony", location: "Stavanger, Norway" },
  ].each do |attrs|
    Milestone.find_or_create_by!(date: attrs[:date], headline: attrs[:headline]) do |m|
      m.location    = attrs[:location]
      m.description = attrs[:description]
    end
  end
```
(Place this inside the same `if Rails.env.development?` guard the sample memories use, if one exists; otherwise mirror the surrounding seed structure.)

- [ ] **Step 2: Verify seeds run cleanly**

Run:
```bash
bin/rails db:seed
```
Expected: no error; running it twice creates no duplicates (idempotent).

- [ ] **Step 3: Commit**

```bash
git add db/seeds.rb
git commit -m "Seed: sample biographical milestones for development"
```

---

### Task 5: Full suite + final verification

- [ ] **Step 1: Run the complete test suite**

Run:
```bash
bin/rails test
```
Expected: all tests pass, 0 failures, 0 errors (baseline was 240 runs; this adds ~20).

- [ ] **Step 2: Manual smoke check (optional)**

Run `bin/dev` (or the project's dev command), sign in as admin, visit `/admin/milestones`, create a milestone, then view `/timeline` and confirm it renders as a centered marker under the correct year.

- [ ] **Step 3: Commit any fixes**

If the full suite surfaced anything, fix and commit with a descriptive message.

---

## Self-Review

**Spec coverage:**
- Separate `Milestone` model, no submitter/status/replies/Mappable → Task 1. ✓
- Columns date/headline/description/icon/location → Task 1 migration. ✓
- Admin CRUD + sidebar + dashboard tile → Task 2. ✓
- Timeline interleave, year union, year-anchoring, counts memories-only → Task 3. ✓
- Distinct centered milestone partial → Task 3 Step 4. ✓
- No public show page, no map pin → not implemented (correctly out of scope). ✓
- Year-level date display (no per-entry date) → milestone partial omits date. ✓
- Always visible (no published flag) → no flag added. ✓
- Seeds optional → Task 4. ✓
- Tests: model, admin CRUD, timeline integration → Tasks 1–3. ✓

**Placeholder scan:** No TBD/TODO; every code step shows full code. ✓

**Type consistency:** `build_timeline_by_year(memories, milestones)` defined and called identically in Task 3; `@timeline_by_year`, `@years`, `@memories_count` consistent between controller (Task 3 Step 3) and view (Task 3 Step 5); `Milestone#year`/`#age`/`.chronological` defined in Task 1 and used in Tasks 2–3. ✓
