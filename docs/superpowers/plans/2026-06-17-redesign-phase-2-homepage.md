# Phase 2: Homepage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the homepage body with six Garden-direction sections (hero, MVT I-V) rendered through small section partials, while leaving the Phase 1 chrome untouched.

**Architecture:** `home.html.erb` becomes a thin manifest that renders six section partials under `app/views/pages/home/`. Each partial owns one section. Two small card sub-partials (preview_card, event_card, tribute_quote_card) keep card markup factored. Controller loads data into instance variables; partials degrade gracefully when data is sparse. Seeds expand so dev/test environments render the page fully.

**Tech Stack:** Rails 8.1.2, ERB partials, Tailwind v4 (tokens from Phase 1), Stimulus (no new controllers needed), Minitest.

**Spec:** `docs/superpowers/specs/2026-06-17-redesign-phase-2-homepage-design.md`

---

## Files touched in this phase

**Created:**
- `app/views/pages/home/_hero.html.erb`
- `app/views/pages/home/_honor_grid.html.erb`
- `app/views/pages/home/_timeline_preview.html.erb`
- `app/views/pages/home/_preview_card.html.erb`
- `app/views/pages/home/_events_preview.html.erb`
- `app/views/pages/home/_event_card.html.erb`
- `app/views/pages/home/_gallery_preview.html.erb`
- `app/views/pages/home/_tributes_preview.html.erb`
- `app/views/pages/home/_tribute_quote_card.html.erb`
- `config/locales/en.yml`
- `test/integration/homepage_test.rb`

**Modified:**
- `app/models/event.rb` — add `service: 2` to `event_type` enum
- `app/controllers/pages_controller.rb` — `home` action loads 5 instance variables
- `app/views/pages/home.html.erb` — full rewrite as manifest (130 lines → ~15)
- `db/seeds.rb` — expanded sample data
- `test/integration/public_pages_test.rb` — update one assertion that referenced old "action-library-heading" markup

**Not touched:**
- Application layout, nav, footer (Phase 1).
- Any other page view.
- Memory/Tribute/Event/GalleryPhoto schema (no migrations).
- Routes.

---

## Task 1: Locale formats + Event enum addition

**Files:**
- Create: `config/locales/en.yml`
- Modify: `app/models/event.rb` (single line)
- Test: `test/models/event_test.rb` (extended)

This task lays the foundation: a third event category and the date/time formats every later partial uses.

- [ ] **Step 1: Read current event model test**

```bash
cat test/models/event_test.rb | head -30
```

Note the existing test pattern.

- [ ] **Step 2: Add a failing test for the service enum value**

Append to `test/models/event_test.rb` (inside the existing `class EventTest < ActiveSupport::TestCase`):

```ruby
  test "service is a valid event_type" do
    event = Event.new(
      title: "Annual Memorial Recital",
      event_type: :service,
      starts_at: 1.week.from_now,
      published: true
    )
    assert event.valid?, event.errors.full_messages.inspect
    assert event.service?
  end
```

- [ ] **Step 3: Run the test and watch it fail**

```bash
bin/rails test test/models/event_test.rb -n test_service_is_a_valid_event_type -v
```

Expected: `ArgumentError: 'service' is not a valid event_type`. The enum doesn't include it.

- [ ] **Step 4: Add service to the enum**

Edit `app/models/event.rb`. Change:

```ruby
enum :event_type, { webinar: 0, concert: 1 }
```

to:

```ruby
enum :event_type, { webinar: 0, concert: 1, service: 2 }
```

- [ ] **Step 5: Run the test again**

```bash
bin/rails test test/models/event_test.rb -n test_service_is_a_valid_event_type -v
```

Expected: 1 run, 1 assertion, 0 failures.

- [ ] **Step 6: Edit the existing locale file**

`config/locales/en.yml` already exists and contains a sample `en: hello: "Hello world"` entry. Add the date/time formats under the same `en:` block. Replace the file's full content with:

```yaml
# Files in the config/locales directory are used for internationalization and
# are automatically loaded by Rails.

en:
  hello: "Hello world"

  date:
    formats:
      memory: "%B %Y"               # e.g. "September 2002"
      event_date: "%A %b %-d, %Y"   # e.g. "Sunday Jun 14, 2026"
  time:
    formats:
      event_time: "%-l:%M %p %Z"    # e.g. "3:00 PM EDT"
```

The `hello: "Hello world"` is kept harmless — Rails ships it as a default; leaving it avoids a noisy diff and keeps the example for future reference.

- [ ] **Step 7: Verify formats work via console**

```bash
bin/rails runner 'puts I18n.l(Date.new(2002, 9, 1), format: :memory); puts I18n.l(Time.zone.local(2026, 6, 14, 10, 0), format: :event_date); puts I18n.l(Time.zone.local(2026, 6, 14, 10, 0), format: :event_time)'
```

Expected (timezone may vary by host — that's fine):

```
September 2002
Sunday Jun 14, 2026
10:00 AM EDT
```

If any format errors with `I18n::MissingTranslationData`, fix the YAML structure (ensure `date:` and `time:` are both children of `en:`, not nested).

- [ ] **Step 8: Run full suite to catch regressions**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 94 runs (was 93 + 1 new), 0 failures.

- [ ] **Step 9: Commit**

```bash
git add app/models/event.rb config/locales/en.yml test/models/event_test.rb
git commit -m "Phase 2: add :service event_type + date/time locale formats"
```

---

## Task 2: Seeds expansion

**Files:**
- Modify: `db/seeds.rb`

Beef up sample data so the homepage renders fully in dev/test.

- [ ] **Step 1: Read current seeds**

```bash
cat db/seeds.rb
```

Note existing pattern: `Rails.env.development?` guard, `find_or_create_by!` for idempotence.

- [ ] **Step 2: Replace the development sample-data block**

Find the `if Rails.env.development?` block. Inside it, after the existing `admin` setup, replace the existing sample-data section with:

```ruby
  # ---- Memories ----
  memories_data = [
    { date: Date.new(2002, 9, 1), title: "Mass Row, Dartmouth",
      content: "Sept 2002, Mass Row dorm. Two weeks into freshman year and Chris already had a chamber group meeting in his common room every Thursday. He'd score the parts by hand, then pass them out before dinner.",
      location: "Hanover, NH" },
    { date: Date.new(2014, 6, 15), title: "Munich concert",
      content: "I'll never forget the evening Christopher conducted Beethoven's 7th in Munich. The energy in the room was electric — and after the second movement he caught my eye in the balcony and grinned.",
      location: "Munich, Germany" },
    { date: Date.new(2019, 5, 12), title: "Stavanger rehearsal",
      content: "Watching Chris rehearse Mahler with the Jæren Symfoniorkester. He stopped after eight bars to make a joke about the violas. Everyone laughed. Then the next phrase was perfect.",
      location: "Stavanger, Norway" },
  ]

  memories_data.each do |attrs|
    Memory.find_or_create_by!(date: attrs[:date], title: attrs[:title]) do |m|
      m.content = attrs[:content]
      m.location = attrs[:location]
      m.user = admin
      m.status = :published
    end
  end

  # ---- Events ----
  events_data = [
    { title: "Chris's Memorial Call — five years on",
      event_type: :webinar,
      starts_at: Time.zone.local(2026, 8, 14, 10, 0),
      location: "Zoom (link emailed after RSVP)" },
    { title: "Jæren Symfoniorkester — Memorial Concert",
      event_type: :concert,
      starts_at: Time.zone.local(2026, 9, 12, 19, 30),
      location: "Jæren kulturhus, Bryne, Norway" },
    { title: "Dartmouth Conducting Endowment — annual recital",
      event_type: :service,
      starts_at: Time.zone.local(2026, 10, 23, 19, 0),
      location: "Spaulding Auditorium, Hanover, NH" },
  ]

  events_data.each do |attrs|
    Event.find_or_create_by!(title: attrs[:title]) do |e|
      e.event_type = attrs[:event_type]
      e.starts_at = attrs[:starts_at]
      e.location = attrs[:location]
      e.published = true
    end
  end

  # ---- Tributes ----
  tributes_data = [
    { name: "Margaret Thompson", relationship: "Family friend",
      content: "Christopher was an extraordinary person who touched everyone he met with his warmth, humor, and incredible talent. His memory is a blessing." },
    { name: "James Anderson", relationship: "Dartmouth classmate",
      content: "We shared a dorm room our sophomore year and I learned what it meant to truly love what you do. Chris would conduct in his sleep — literally, hands moving above the blankets." },
    { name: "Sigrid Olsen", relationship: "Colleague, Jæren Symfoniorkester",
      content: "Chris's scintillating charisma and smiling authority inspired singers and musicians alike to surpass themselves. We carry his phrasings with us into every performance." },
    { name: "Anna Lee", relationship: "Student",
      content: "He'd write notes in the margins of my scores that were half pedagogy, half love letters to the music. I still have them all." },
  ]

  tributes_data.each do |attrs|
    Tribute.find_or_create_by!(name: attrs[:name]) do |t|
      t.relationship = attrs[:relationship]
      t.content = attrs[:content]
      t.status = :published
    end
  end

  # ---- Tree (existing) ----
  Tree.find_or_create_by!(name: "McMullen Family") do |t|
    t.email = "family@example.com"
    t.address = "Ann Arbor, Michigan"
    t.latitude = 42.2808
    t.longitude = -83.7430
    t.tree_count = 1
    t.story = "The first Chris tree, planted by his parents."
    t.status = :published
  end

  puts "Sample data created (#{Memory.count} memories, #{Event.count} events, #{Tribute.count} tributes, #{Tree.count} trees)."
```

Confirm the old `Sample Tribute` find_or_create_by call and the single Memory "Munich concert" find_or_create_by are replaced — the new Margaret Thompson tribute and Munich memory above subsume them.

Also confirm the old `puts "Sample data created."` line is replaced with the new count-aware version.

- [ ] **Step 3: Drop the dev database and re-seed to verify idempotence + correctness**

```bash
bin/rails db:reset 2>&1 | tail -5
```

Expected: `Sample data created (3 memories, 3 events, 4 tributes, 1 trees).` near the end.

- [ ] **Step 4: Run seeds again to verify idempotence**

```bash
bin/rails db:seed 2>&1 | tail -3
```

Expected: same counts (3/3/4/1). No errors.

- [ ] **Step 5: Run the full test suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 94 runs, 0 failures. (Tests use fixtures and create their own data — seed changes don't affect tests.)

- [ ] **Step 6: Commit**

```bash
git add db/seeds.rb
git commit -m "Phase 2: expand seeds with 3 memories, 3 events, 4 tributes"
```

---

## Task 3: Controller + home.html.erb manifest

**Files:**
- Modify: `app/controllers/pages_controller.rb`
- Modify: `app/views/pages/home.html.erb` (full rewrite)
- Create (empty stubs for now): six partials under `app/views/pages/home/`

This task wires the skeleton end-to-end. After this task, the homepage renders six blank sections (just `<section>` boundary markers) — no real content yet. That sets up the visual scaffold for Tasks 4-9 to fill in section by section.

- [ ] **Step 1: Read the current home action**

```bash
cat app/controllers/pages_controller.rb
```

- [ ] **Step 2: Update the home action**

Replace the entire `home` action with:

```ruby
  def home
    @timeline_preview_memories = Memory.published.order(date: :desc, created_at: :desc).limit(3)
    @upcoming_events = Event.published.upcoming.with_attached_cover_image.limit(3)
    @gallery_photos = GalleryPhoto.all.limit(12)
    @recent_tributes = Tribute.published.order(created_at: :desc).limit(3)
    @tributes_count = Tribute.published.count
  end
```

The other actions (`chris`, `projects`, `funds`, `zero_waste`, `news`) and the `style_guide` action stay unchanged.

- [ ] **Step 3: Create the six empty section partials**

These are placeholder skeletons. Each one is a single `<section>` with a comment marking what it will become. Tasks 4-9 replace them with real content.

Create each of the following with the content shown:

`app/views/pages/home/_hero.html.erb`:

```erb
<section class="relative" data-section="hero">
  <%# Phase 2 Task 4 fills this in. %>
</section>
```

`app/views/pages/home/_honor_grid.html.erb`:

```erb
<section class="px-6 lg:px-14 py-24" data-section="honor-grid">
  <%# Phase 2 Task 5 fills this in. %>
</section>
```

`app/views/pages/home/_timeline_preview.html.erb`:

```erb
<section class="bg-linen px-6 lg:px-14 py-24 relative" data-section="timeline-preview">
  <%# Phase 2 Task 6 fills this in. %>
</section>
```

`app/views/pages/home/_events_preview.html.erb`:

```erb
<section class="px-6 lg:px-14 py-24" data-section="events-preview">
  <%# Phase 2 Task 7 fills this in. %>
</section>
```

`app/views/pages/home/_gallery_preview.html.erb`:

```erb
<section class="bg-linen px-6 lg:px-14 py-24" data-section="gallery-preview">
  <%# Phase 2 Task 8 fills this in. %>
</section>
```

`app/views/pages/home/_tributes_preview.html.erb`:

```erb
<section class="px-6 lg:px-14 py-24" data-section="tributes-preview">
  <%# Phase 2 Task 9 fills this in. %>
</section>
```

- [ ] **Step 4: Replace home.html.erb with the manifest**

Overwrite `app/views/pages/home.html.erb` (currently 130 lines of old Stone/Blue markup) with:

```erb
<% content_for :title, "Christopher Quentin McMullen-Laird — A Life in Music" %>

<%= render "pages/home/hero" %>
<%= render "pages/home/honor_grid" %>
<%= render "pages/home/timeline_preview", memories: @timeline_preview_memories %>
<%= render "pages/home/events_preview", events: @upcoming_events %>
<%= render "pages/home/gallery_preview", photos: @gallery_photos %>
<%= render "pages/home/tributes_preview", tributes: @recent_tributes, total_count: @tributes_count %>
```

That's the entire file. The old hero/action-library/timeline/etc. markup is gone.

- [ ] **Step 5: Boot the page and verify it renders without errors**

```bash
bin/rails runner 'puts ApplicationController.render(template: "pages/home", assigns: { timeline_preview_memories: Memory.published.limit(3), upcoming_events: Event.published.upcoming.limit(3), gallery_photos: GalleryPhoto.all.limit(12), recent_tributes: Tribute.published.limit(3), tributes_count: Tribute.published.count }).length'
```

Expected: a positive integer (the rendered page's character length). No exceptions.

- [ ] **Step 6: Run the full test suite**

```bash
bin/rails test 2>&1 | tail -10
```

**Expected:** one regression in `test/integration/public_pages_test.rb`:

- `test "home page loads"` — asserts `h1` matches `/Christopher Quentin/`. The hero is empty now, so there's no h1 yet. This will fail.
- `test "home page shows action library with tree, memory, bee hive, and fund CTAs"` — asserts the action-library section. That markup is gone. Will fail.

Note these failures but do NOT fix them yet. They'll pass once Tasks 4 and 5 implement the real hero and honor grid.

- [ ] **Step 7: Commit (despite the expected regressions)**

```bash
git add app/controllers/pages_controller.rb app/views/pages/home.html.erb app/views/pages/home/
git commit -m "Phase 2: rewrite home.html.erb as manifest with six section stubs"
```

Note: the test suite is briefly red after this commit. Tasks 4 and 5 restore it to green. Subsequent tasks add new tests.

---

## Task 4: Hero partial

**Files:**
- Modify: `app/views/pages/home/_hero.html.erb`
- Modify: `test/integration/public_pages_test.rb` (update existing assertion)
- Create: `test/integration/homepage_test.rb` (new tests for the hero)

- [ ] **Step 1: Create the new homepage integration test file with hero tests**

Create `test/integration/homepage_test.rb`:

```ruby
require "test_helper"

class HomepageTest < ActionDispatch::IntegrationTest
  test "hero renders the three-line name with italic Quentin in moss" do
    get root_path
    assert_response :success
    assert_select "h1.font-serif" do
      assert_select "*", text: /Christopher/
      assert_select "span.font-serif.italic.text-moss", text: "Quentin"
      assert_select "*", text: /McMullen-Laird/
    end
  end

  test "hero renders the Op. 1984 eyebrow with sage rule" do
    get root_path
    assert_select ".text-eyebrow", text: /Op\. 1984.+In Memoriam/
    assert_select "span.bg-sage", count: 1..50  # the with_rule short line
  end

  test "hero renders the tagline" do
    get root_path
    assert_select ".font-serif.italic", text: /Conductor.+environmentalist.+beloved/i
  end

  test "hero renders the Jaerbladet press blockquote with rose left border" do
    get root_path
    assert_select "blockquote" do
      assert_select "p", text: /scintillating charisma/
      assert_select "footer", text: /Jærbladet/
    end
  end

  test "hero renders the two CTA pills with correct destinations" do
    get root_path
    assert_select "a[href=?]", chris_path, text: /Read his story/
    assert_select "a[href=?]", new_memory_path, text: /Share a memory/
  end

  test "hero renders portrait placeholder with caption" do
    get root_path
    # The portrait is a styled div with a mono caption; assert the caption text exists.
    assert_match %r{\[ portrait — Stavanger 2019 \]}, response.body
  end

  test "hero includes faint staff_lines texture" do
    get root_path
    assert_select "[data-section='hero'] .staff-lines-bg"
  end
end
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
bin/rails test test/integration/homepage_test.rb -v
```

Expected: 7 runs, multiple failures (no h1, no eyebrow, no blockquote, no CTAs, no portrait caption, no staff-lines).

- [ ] **Step 3: Replace _hero.html.erb with the real markup**

Overwrite `app/views/pages/home/_hero.html.erb`:

```erb
<section class="relative px-6 lg:px-14 py-16 lg:py-24" data-section="hero">
  <%= render "shared/staff_lines", top: 120, height: 120, opacity: 0.09 %>

  <div class="grid grid-cols-1 lg:grid-cols-[1.15fr_1fr] gap-10 lg:gap-16 items-center lg:min-h-[620px] relative">
    <%# Left — text column %>
    <div class="relative z-[2]">
      <%= musical_eyebrow("Op. 1984 — In Memoriam", with_rule: true) %>

      <h1 class="font-serif text-[56px] md:text-[96px] lg:text-[120px] leading-[0.93] tracking-[-0.025em] text-ink font-normal mt-5 mb-0">
        Christopher<br>
        <span class="font-serif italic text-moss">Quentin</span><br>
        McMullen-Laird
      </h1>

      <div class="font-serif italic text-xl md:text-[24px] text-sage mt-7">
        Conductor &nbsp;·&nbsp; environmentalist &nbsp;·&nbsp; beloved
      </div>

      <blockquote class="mt-10 pl-5 border-l-2 border-rose max-w-[540px]">
        <p class="font-serif italic text-[19px] md:text-[22px] leading-[1.4] text-ink m-0">
          "His scintillating charisma and smiling authority inspired
          singers and musicians alike to surpass themselves."
        </p>
        <footer class="text-eyebrow text-ink/55 mt-3">— Jærbladet</footer>
      </blockquote>

      <div class="mt-11 flex flex-wrap items-center gap-4">
        <%= link_to "Read his story →", chris_path,
              class: "bg-moss text-cream rounded-full px-6 py-4 text-[15px] font-medium no-underline hover:bg-ink transition-colors" %>
        <%= link_to "+ Share a memory", new_memory_path,
              class: "bg-transparent text-ink border border-ink/20 rounded-full px-6 py-4 text-[15px] no-underline hover:border-moss hover:text-moss transition-colors" %>
      </div>
    </div>

    <%# Right — portrait placeholder %>
    <div class="relative h-[420px] md:h-[520px] lg:h-[620px] self-center">
      <div class="absolute inset-0 rounded-md shadow-[0_30px_60px_-28px_rgba(28,38,32,0.35)] flex items-end p-6"
           style="background: linear-gradient(160deg, rgba(58,82,64,0.18), rgba(168,88,76,0.18)), repeating-linear-gradient(45deg, rgba(58,82,64,0.08) 0 16px, transparent 16px 32px);">
        <div class="text-eyebrow text-cream mix-blend-difference">
          [ portrait — Stavanger 2019 ]
        </div>
      </div>
      <div class="absolute -right-7 -bottom-7 w-[200px] h-[240px] bg-linen border border-ink/8 rounded-[4px] transform rotate-[4deg] shadow-[0_20px_40px_-24px_rgba(28,38,32,0.25)] hidden md:flex items-end p-3.5">
        <div class="font-mono text-[9px] tracking-[0.12em] text-sage">
          [ on the podium ]
        </div>
      </div>
    </div>
  </div>
</section>
```

- [ ] **Step 4: Run the new tests and verify they pass**

```bash
bin/rails test test/integration/homepage_test.rb -v
```

Expected: 7 runs, all pass.

- [ ] **Step 5: Update the existing public_pages_test home-page-loads assertion**

The old assertion was:

```ruby
assert_select "h1", /Christopher Quentin/
```

The new h1 has `Christopher<br><em>Quentin</em><br>McMullen-Laird` — `assert_select "h1"` matches the element; the text content (with line breaks collapsed to spaces by `assert_select`) contains all three names. The existing assertion should still pass. Verify:

```bash
bin/rails test test/integration/public_pages_test.rb -n test_home_page_loads -v
```

Expected: PASS.

If it fails (whitespace normalization is sometimes odd), update the assertion in `test/integration/public_pages_test.rb` to:

```ruby
assert_select "h1.font-serif", /Christopher/
```

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 101 runs (94 + 7), failures only from the still-broken "action library" test (Task 5 will fix), not from anything else.

- [ ] **Step 7: Commit**

```bash
git add app/views/pages/home/_hero.html.erb test/integration/homepage_test.rb test/integration/public_pages_test.rb
git commit -m "Phase 2: hero section with Op. 1984 eyebrow, 3-line name, press quote, CTAs"
```

---

## Task 5: MVT I — Honor grid

**Files:**
- Modify: `app/views/pages/home/_honor_grid.html.erb`
- Modify: `test/integration/public_pages_test.rb` (replace one assertion)
- Modify: `test/integration/homepage_test.rb` (add new tests)

- [ ] **Step 1: Add failing tests for the honor grid**

Append to `test/integration/homepage_test.rb` (before the final `end` of the class):

```ruby
  test "MVT I renders movement label with andante con moto marking" do
    get root_path
    assert_select "[data-section='honor-grid'] .text-eyebrow", text: /MVT\. I/
    assert_select "[data-section='honor-grid'] h2", text: /Honor his memory/
    assert_select "[data-section='honor-grid'] span", text: /andante con moto/
  end

  test "MVT I renders four honor cards with correct destinations and titles" do
    get root_path
    [
      [new_tree_path,     "Plant a Tree"],
      [new_memory_path,   "Share a Memory"],
      [new_bee_hive_path, "Adopt a Bee Hive"],
      [funds_path,        "Support a Fund"],
    ].each do |path, title|
      assert_select "[data-section='honor-grid'] a[href=?]", path, text: /.*/  do
        assert_select "h3", text: title
      end
    end
  end

  test "MVT I cards each render a musical glyph" do
    get root_path
    body = response.body
    %w[❦ ¶ ♪ ♭].each do |glyph|
      assert_match Regexp.new(Regexp.escape(glyph)), body, "Expected glyph #{glyph} in honor grid"
    end
  end
```

- [ ] **Step 2: Run and watch fail**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_I/ -v
```

Expected: 3 runs, all fail (no movement label, no cards, no glyphs).

- [ ] **Step 3: Replace _honor_grid.html.erb with the real markup**

Overwrite `app/views/pages/home/_honor_grid.html.erb`:

```erb
<section class="px-6 lg:px-14 py-16 lg:py-24" data-section="honor-grid">
  <%= render "shared/movement_label", no: "MVT. I", title: "Honor his memory", marking: "andante con moto" %>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
    <% [
      { glyph: "❦", label: "I. Plant",      title: "Plant a Tree",
        body: "Add a tree to the living map of saplings planted in his memory across nine countries.",
        cta: "Plant a tree →",    path: new_tree_path,     accent: "text-moss" },
      { glyph: "¶", label: "II. Remember",  title: "Share a Memory",
        body: "A photo, a story, an audio clip — contribute to the timeline of his life.",
        cta: "Share a memory →",  path: new_memory_path,   accent: "text-rose" },
      { glyph: "♪", label: "III. Pollinate", title: "Adopt a Bee Hive",
        body: "Register a hive on the unified map — pollinators were one of his loves.",
        cta: "Adopt a hive →",    path: new_bee_hive_path, accent: "text-sage" },
      { glyph: "♭", label: "IV. Sustain",   title: "Support a Fund",
        body: "The Dartmouth Conducting Endowment and four other funds carry his work forward.",
        cta: "Contribute →",      path: funds_path,        accent: "text-moss" },
    ].each do |card| %>
      <%= link_to card[:path], class: "group block no-underline" do %>
        <article class="bg-white rounded-md border border-ink/8 shadow-card p-6 flex flex-col min-h-[280px] hover:border-ink/15 transition-colors">
          <div class="font-serif text-[32px] <%= card[:accent] %> leading-none mb-1.5"><%= card[:glyph] %></div>
          <%= musical_eyebrow(card[:label]) %>
          <h3 class="font-serif text-3xl text-ink mt-2.5 leading-tight font-normal"><%= card[:title] %></h3>
          <p class="text-sm leading-relaxed text-ink/70 mt-3 flex-1"><%= card[:body] %></p>
          <span class="<%= card[:accent] %> text-sm font-medium mt-4 group-hover:underline"><%= card[:cta] %></span>
        </article>
      <% end %>
    <% end %>
  </div>
</section>
```

- [ ] **Step 4: Run the new tests**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_I/ -v
```

Expected: 3 runs, all pass.

- [ ] **Step 5: Update the existing action-library test**

Edit `test/integration/public_pages_test.rb`. Find the test:

```ruby
test "home page shows action library with tree, memory, bee hive, and fund CTAs" do
  get root_path
  assert_response :success
  assert_select "section[aria-labelledby=?]", "action-library-heading" do
    assert_select "#action-library-heading"
    assert_select "a[href=?]", new_tree_path
    assert_select "a[href=?]", new_memory_path
    assert_select "a[href=?]", new_bee_hive_path
    assert_select "a[href=?]", funds_path
  end
end
```

Replace with:

```ruby
test "home page shows action library with tree, memory, bee hive, and fund CTAs" do
  get root_path
  assert_response :success
  assert_select "[data-section='honor-grid']" do
    assert_select "a[href=?]", new_tree_path
    assert_select "a[href=?]", new_memory_path
    assert_select "a[href=?]", new_bee_hive_path
    assert_select "a[href=?]", funds_path
  end
end
```

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 104 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/views/pages/home/_honor_grid.html.erb test/integration/homepage_test.rb test/integration/public_pages_test.rb
git commit -m "Phase 2: MVT I honor grid (Plant / Share / Adopt / Contribute)"
```

---

## Task 6: MVT II — Timeline preview

**Files:**
- Modify: `app/views/pages/home/_timeline_preview.html.erb`
- Create: `app/views/pages/home/_preview_card.html.erb`
- Modify: `test/integration/homepage_test.rb` (add tests)

- [ ] **Step 1: Append failing tests for MVT II**

Append to `test/integration/homepage_test.rb` (before the final `end`):

```ruby
  test "MVT II renders movement label with from-the-timeline eyebrow" do
    get root_path
    assert_select "[data-section='timeline-preview'] .text-eyebrow", text: /MVT\. II/
    assert_select "[data-section='timeline-preview'] h2", text: /A life, kept by/
    assert_select "[data-section='timeline-preview'] h2 em.text-moss", text: /many hands/
  end

  test "MVT II renders View full timeline pill linking to memories_path" do
    get root_path
    assert_select "[data-section='timeline-preview'] a[href=?]", memories_path, text: /View full timeline/
  end

  test "MVT II renders up to 3 preview cards from published memories" do
    # Seeded data: 3 published memories
    get root_path
    assert_select "[data-section='timeline-preview'] article", count: 1..3
  end

  test "MVT II preview card shows memory date, location, body, name" do
    get root_path
    assert_select "[data-section='timeline-preview']" do
      assert_select ".text-eyebrow", text: /Hanover|Munich|Stavanger/
      assert_select "p", text: /Mass Row|Beethoven|Mahler/
    end
  end

  test "MVT II empty state — shows Be the first card when no memories" do
    Memory.update_all(status: Memory.statuses[:pending])
    get root_path
    assert_select "[data-section='timeline-preview'] a[href=?]", new_memory_path, text: /Be the first/
  ensure
    Memory.update_all(status: Memory.statuses[:published])
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_II/ -v
```

Expected: 5 runs, 5 failures.

- [ ] **Step 3: Create the preview_card sub-partial**

Create `app/views/pages/home/_preview_card.html.erb`:

```erb
<%# Renders a single memory preview card. Photo variant if memory.photos.attached?,
    otherwise the text-only variant. The audio variant is Phase 3. %>
<article class="bg-white rounded-md overflow-hidden border border-ink/8 shadow-card flex flex-col">
  <% if memory.photos.attached? %>
    <div class="h-[200px] relative"
         style="background: linear-gradient(135deg, rgba(90,122,94,0.2), rgba(58,82,64,0.3)), repeating-linear-gradient(45deg, rgba(90,122,94,0.08) 0 12px, transparent 12px 24px);">
      <div class="absolute bottom-4 left-4 text-eyebrow text-cream mix-blend-difference">
        [ photo · <%= memory.location.presence || "—" %> ]
      </div>
    </div>
  <% end %>

  <div class="p-6 flex flex-col flex-1">
    <%= musical_eyebrow("#{l(memory.date, format: :memory)} · #{memory.location.presence || ''}".strip.chomp("·").strip) %>
    <p class="font-serif text-[19px] leading-snug text-ink mt-3 flex-1">
      <%= truncate(memory.content.to_s, length: 220) %>
    </p>
    <footer class="mt-4 pt-3.5 border-t border-ink/8 flex justify-between items-baseline">
      <div>
        <div class="text-sm font-medium text-ink"><%= memory.user&.name || "Anonymous" %></div>
      </div>
      <span class="text-eyebrow text-sage">
        <%= memory.photos.attached? ? "photograph" : "letter" %>
      </span>
    </footer>
  </div>
</article>
```

(Note: relationship is intentionally omitted — the field doesn't exist on User yet. Phase 3 adds it to Memory directly.)

- [ ] **Step 4: Replace _timeline_preview.html.erb**

Overwrite `app/views/pages/home/_timeline_preview.html.erb`:

```erb
<section class="bg-linen px-6 lg:px-14 py-20 lg:py-24 relative" data-section="timeline-preview">
  <%= render "shared/staff_lines", top: 0, height: 80, opacity: 0.06 %>

  <div class="flex flex-col lg:flex-row lg:justify-between lg:items-end gap-6 mb-9 relative">
    <div class="flex-1">
      <%= musical_eyebrow("MVT. II · from the timeline") %>
      <h2 class="font-serif text-4xl md:text-5xl lg:text-[64px] font-normal leading-none tracking-tight text-ink mt-2.5">
        A life, kept by <em class="font-serif italic text-moss">many hands</em>.
      </h2>
      <% if memories.any? %>
        <p class="text-[17px] text-ink/65 mt-3.5 max-w-[560px]">
          <%= pluralize(Memory.published.count, "memory", plural: "memories") %> so far. Browse them all, or add your own.
        </p>
      <% end %>
    </div>
    <%= link_to "View full timeline →", memories_path,
          class: "border border-moss text-moss rounded-full px-5 py-3 text-sm font-medium no-underline hover:bg-moss hover:text-cream transition-colors self-start lg:self-auto" %>
  </div>

  <% if memories.any? %>
    <div class="grid grid-cols-1 md:grid-cols-3 gap-5 relative">
      <% memories.each do |memory| %>
        <%= render "pages/home/preview_card", memory: memory %>
      <% end %>
    </div>
  <% else %>
    <div class="bg-white rounded-md border border-ink/8 shadow-card p-12 text-center relative">
      <%= link_to new_memory_path, class: "no-underline" do %>
        <div class="font-serif text-3xl text-moss">Be the first to share a memory →</div>
        <p class="text-sm text-ink/60 mt-2">A photo, a story, an audio clip.</p>
      <% end %>
    </div>
  <% end %>
</section>
```

- [ ] **Step 5: Run new tests**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_II/ -v
```

Expected: 5 runs, all pass.

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 109 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/views/pages/home/_timeline_preview.html.erb app/views/pages/home/_preview_card.html.erb test/integration/homepage_test.rb
git commit -m "Phase 2: MVT II timeline preview with text/photo variants + empty state"
```

---

## Task 7: MVT III — Events preview

**Files:**
- Modify: `app/views/pages/home/_events_preview.html.erb`
- Create: `app/views/pages/home/_event_card.html.erb`
- Modify: `test/integration/homepage_test.rb`

- [ ] **Step 1: Append failing tests**

Append to `test/integration/homepage_test.rb`:

```ruby
  test "MVT III renders movement label with vivace marking" do
    get root_path
    assert_select "[data-section='events-preview'] .text-eyebrow", text: /MVT\. III/
    assert_select "[data-section='events-preview'] h2", text: /Upcoming gatherings/
    assert_select "[data-section='events-preview'] span", text: /vivace/
  end

  test "MVT III renders one event card per upcoming event" do
    # Seeded data: 3 upcoming events
    get root_path
    assert_select "[data-section='events-preview'] article", count: 1..3
  end

  test "MVT III event card shows category chip" do
    get root_path
    assert_select "[data-section='events-preview'] article" do
      assert_select "span.bg-linen.text-moss", text: /Webinar|Concert|Service/i
    end
  end

  test "MVT III hides the section when no upcoming events" do
    Event.update_all(published: false)
    get root_path
    assert_select "[data-section='events-preview'] article", 0
  ensure
    Event.update_all(published: true)
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_III/ -v
```

Expected: 4 runs, multiple failures.

- [ ] **Step 3: Create event_card partial**

Create `app/views/pages/home/_event_card.html.erb`:

```erb
<article class="bg-white rounded-md border border-ink/8 p-6 relative">
  <span class="absolute top-5 right-5 px-2.5 py-1 rounded-full bg-linen text-moss text-eyebrow whitespace-nowrap">
    <%= event.event_type.to_s.capitalize %>
  </span>
  <h3 class="font-serif text-[22px] font-medium leading-snug text-ink pr-24">
    <%= event.title %>
  </h3>
  <div class="text-eyebrow text-sage mt-3 mb-2">
    <%= l(event.starts_at.in_time_zone(Event::DISPLAY_ZONES.first[0]), format: :event_date) %>
  </div>
  <div class="text-sm text-ink/70 leading-relaxed">
    <% Event::DISPLAY_ZONES.each do |zone, label| %>
      <div><%= label %> · <%= l(event.starts_at.in_time_zone(zone), format: :event_time) %></div>
    <% end %>
    <div class="text-moss mt-1.5"><%= event.location %></div>
  </div>
</article>
```

- [ ] **Step 4: Replace _events_preview.html.erb**

Overwrite `app/views/pages/home/_events_preview.html.erb`:

```erb
<% if events.any? %>
  <section class="px-6 lg:px-14 py-20 lg:py-24" data-section="events-preview">
    <%= render "shared/movement_label", no: "MVT. III", title: "Upcoming gatherings", marking: "vivace" %>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
      <% events.each do |event| %>
        <%= render "pages/home/event_card", event: event %>
      <% end %>
    </div>
  </section>
<% else %>
  <%# section hidden when no upcoming events %>
<% end %>
```

- [ ] **Step 5: Run new tests**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_III/ -v
```

Expected: 4 runs, all pass.

If the "hides the section" test fails because of caching: rerun. If it still fails because `Event.update_all(published: false)` triggered no effective DB change in the test transaction, ensure the assertion is `assert_select "[data-section='events-preview'] article", 0` (zero articles is the actual claim — the section wrapper may or may not exist depending on the empty branch).

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 113 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/views/pages/home/_events_preview.html.erb app/views/pages/home/_event_card.html.erb test/integration/homepage_test.rb
git commit -m "Phase 2: MVT III events preview with multi-timezone display"
```

---

## Task 8: MVT IV — Gallery preview

**Files:**
- Modify: `app/views/pages/home/_gallery_preview.html.erb`
- Modify: `test/integration/homepage_test.rb`

- [ ] **Step 1: Append failing tests**

Append to `test/integration/homepage_test.rb`:

```ruby
  test "MVT IV renders movement label with lento e sereno marking" do
    get root_path
    assert_select "[data-section='gallery-preview'] .text-eyebrow", text: /MVT\. IV/
    assert_select "[data-section='gallery-preview'] h2", text: /In photographs/
    assert_select "[data-section='gallery-preview'] span", text: /lento e sereno/
  end

  test "MVT IV renders Submit a photo link" do
    get root_path
    assert_select "[data-section='gallery-preview'] a[href=?]", new_photo_submission_path, text: /Submit a photo/
  end

  test "MVT IV renders 6 placeholder gradient blocks when GalleryPhoto is empty" do
    GalleryPhoto.delete_all  # Phase 2 doesn't seed gallery photos but a test might
    get root_path
    assert_select "[data-section='gallery-preview'] [data-gallery-tile]", count: 6
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_IV/ -v
```

Expected: 3 runs, all fail.

- [ ] **Step 3: Replace _gallery_preview.html.erb**

Overwrite `app/views/pages/home/_gallery_preview.html.erb`:

```erb
<section class="bg-linen px-6 lg:px-14 py-20 lg:py-24" data-section="gallery-preview">
  <%= render "shared/movement_label", no: "MVT. IV", title: "In photographs", marking: "lento e sereno" %>

  <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4">
    <% display_photos = photos.any? ? photos : Array.new(6) %>
    <% gradients = [
         "linear-gradient(135deg, rgba(58,82,64,0.25), rgba(90,122,94,0.18))",
         "linear-gradient(135deg, rgba(168,88,76,0.22), rgba(168,88,76,0.10))",
         "linear-gradient(135deg, rgba(90,122,94,0.22), rgba(58,82,64,0.28))",
         "linear-gradient(135deg, rgba(28,38,32,0.20), rgba(90,122,94,0.20))",
       ] %>
    <% display_photos.each_with_index do |photo, index| %>
      <% prominent = (index % 4 == 0) %>
      <div data-gallery-tile
           class="<%= prominent ? "row-span-2 aspect-[4/7]" : "aspect-[4/5]" %> relative rounded-md overflow-hidden border border-ink/8"
           style="background: <%= gradients[index % gradients.size] %>;">
        <% caption = photo.respond_to?(:caption) && photo.caption.present? ? photo.caption : "[ photo ]" %>
        <div class="absolute bottom-3 left-3 text-eyebrow text-cream mix-blend-difference">
          <%= caption %>
        </div>
      </div>
    <% end %>
  </div>

  <div class="text-center mt-10">
    <%= link_to "Submit a photo →", new_photo_submission_path,
          class: "text-moss text-sm font-medium no-underline hover:underline" %>
  </div>
</section>
```

- [ ] **Step 4: Run new tests**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_IV/ -v
```

Expected: 3 runs, all pass.

- [ ] **Step 5: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 116 runs, 0 failures.

- [ ] **Step 6: Commit**

```bash
git add app/views/pages/home/_gallery_preview.html.erb test/integration/homepage_test.rb
git commit -m "Phase 2: MVT IV gallery preview with placeholder gradients"
```

---

## Task 9: MVT V — Tributes preview

**Files:**
- Modify: `app/views/pages/home/_tributes_preview.html.erb`
- Create: `app/views/pages/home/_tribute_quote_card.html.erb`
- Modify: `test/integration/homepage_test.rb`

- [ ] **Step 1: Append failing tests**

Append to `test/integration/homepage_test.rb`:

```ruby
  test "MVT V renders movement label with cantabile marking" do
    get root_path
    assert_select "[data-section='tributes-preview'] .text-eyebrow", text: /MVT\. V/
    assert_select "[data-section='tributes-preview'] h2", text: /In their own words/
    assert_select "[data-section='tributes-preview'] span", text: /cantabile/
  end

  test "MVT V renders up to 3 tribute quote cards" do
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote", count: 1..3
  end

  test "MVT V cards show name and relationship" do
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote" do
      assert_select "*", text: /Margaret|James|Sigrid|Anna/
    end
  end

  test "MVT V renders pluralized Read all N tributes link" do
    get root_path
    # Seeded: 4 published tributes
    assert_select "[data-section='tributes-preview'] a[href=?]", tributes_path, text: /Read all \d+ tributes|Read the one tribute/
  end

  test "MVT V hides section when no tributes" do
    Tribute.update_all(status: Tribute.statuses[:pending])
    get root_path
    assert_select "[data-section='tributes-preview'] blockquote", 0
  ensure
    Tribute.update_all(status: Tribute.statuses[:published])
  end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_V/ -v
```

Expected: 5 runs, failures.

- [ ] **Step 3: Create tribute_quote_card partial**

Create `app/views/pages/home/_tribute_quote_card.html.erb`:

```erb
<blockquote class="bg-white rounded-md border border-ink/8 shadow-card p-7 relative">
  <span class="absolute -top-3 left-6 font-serif text-[80px] text-rose leading-none select-none" aria-hidden="true">"</span>
  <p class="font-serif text-[19px] italic leading-snug text-ink mt-6 m-0">
    <%= truncate(tribute.content.to_s, length: 240) %>
  </p>
  <footer class="mt-5 pt-3.5 border-t border-ink/8">
    <div class="text-sm font-medium text-ink">— <%= tribute.name %></div>
    <% if tribute.relationship.present? %>
      <div class="text-eyebrow text-sage mt-1"><%= tribute.relationship %></div>
    <% end %>
  </footer>
</blockquote>
```

- [ ] **Step 4: Replace _tributes_preview.html.erb**

Overwrite `app/views/pages/home/_tributes_preview.html.erb`:

```erb
<% if tributes.any? %>
  <section class="px-6 lg:px-14 py-20 lg:py-24" data-section="tributes-preview">
    <%= render "shared/movement_label", no: "MVT. V", title: "In their own words", marking: "cantabile" %>

    <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
      <% tributes.each do |tribute| %>
        <%= render "pages/home/tribute_quote_card", tribute: tribute %>
      <% end %>
    </div>

    <div class="text-center mt-10">
      <% link_label = total_count == 1 ? "Read the one tribute →" : "Read all #{total_count} tributes →" %>
      <%= link_to link_label, tributes_path,
            class: "text-moss text-sm font-medium no-underline hover:underline" %>
    </div>
  </section>
<% else %>
  <%# section hidden when no published tributes %>
<% end %>
```

- [ ] **Step 5: Run new tests**

```bash
bin/rails test test/integration/homepage_test.rb -n /MVT_V/ -v
```

Expected: 5 runs, all pass.

- [ ] **Step 6: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 121 runs, 0 failures.

- [ ] **Step 7: Commit**

```bash
git add app/views/pages/home/_tributes_preview.html.erb app/views/pages/home/_tribute_quote_card.html.erb test/integration/homepage_test.rb
git commit -m "Phase 2: MVT V tributes preview with rose-glyph quote cards"
```

---

## Task 10: Final verification

**Files:** none (or minor fixes if verification surfaces issues)

- [ ] **Step 1: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 121 runs, 0 failures, 0 errors, 0 skips.

- [ ] **Step 2: Re-seed and start the server**

```bash
bin/rails db:reset 2>&1 | tail -5
bin/rails server &
SERVER_PID=$!
sleep 4
```

- [ ] **Step 3: HTTP-level smoke test**

```bash
echo "=== HEAD checks ===" && \
  for path in / /chris /style-guide; do
    code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000$path)
    echo "$path → $code"
  done

echo "=== body content checks ===" && \
  curl -s http://localhost:3000/ | grep -c "MVT\. I" && \
  curl -s http://localhost:3000/ | grep -c "MVT\. II" && \
  curl -s http://localhost:3000/ | grep -c "MVT\. III" && \
  curl -s http://localhost:3000/ | grep -c "MVT\. IV" && \
  curl -s http://localhost:3000/ | grep -c "MVT\. V" && \
  curl -s http://localhost:3000/ | grep -c "Jærbladet"
```

Expected: all paths return 200, each grep returns ≥1.

- [ ] **Step 4: Stop the server**

```bash
kill $SERVER_PID
sleep 1
```

- [ ] **Step 5: Visual check (manual)**

Start `bin/rails server` (or `bin/dev` if Tailwind watch is desired) and open `http://localhost:3000` in a browser. Verify:

- Hero: cream background, 3-line Cormorant name with "Quentin" in italic moss; press blockquote with rose left border; two pill CTAs.
- MVT I: 4 cards with glyphs ❦ ¶ ♪ ♭; each links to its destination.
- MVT II: 3 memory preview cards over linen background; faint staff lines at top edge.
- MVT III: 3 event cards with category chips (Webinar / Concert / Service) and multi-timezone times.
- MVT IV: gallery placeholder gradients in a grid with some 2-row-spanning cells; Submit a photo link.
- MVT V: 3 tribute quote cards with rose oversized opening `"`; "Read all 4 tributes →" link.
- Footer: unchanged from Phase 1.
- Resize to 375px (mobile): all sections stack to a single column; hero text reflows down; placeholder portrait stacks below text.
- Resize to 768px (tablet): hero stays single column; MVT card grids drop to 2 columns; gallery to 3.

Stop the server when done.

- [ ] **Step 6: Final commit (if any fixups needed)**

If anything required adjustment, commit. Otherwise skip:

```bash
git status
# if there are changes:
git add -A
git commit -m "Phase 2: verification fixups"
```

- [ ] **Step 7: Phase 2 complete**

The redesigned homepage now renders the full Garden direction. Phases 3 and 4 build on this foundation.

---

## Self-review notes (post-write)

- ✓ Every spec section maps to a task: hero (T4), honor grid (T5), timeline preview (T6), events preview (T7), gallery preview (T8), tributes preview (T9).
- ✓ Spec's "Decisions locked in" align: placeholder gradients (hero + gallery), inferred type (preview_card), handoff copy verbatim (hero + honor grid bodies + section subtitles), dynamic counts (tributes), graceful degradation (each section's empty branch), seed expansion (T2).
- ✓ Locale formats and Event enum addition land in Task 1, before any partial that uses them.
- ✓ Controller updates land in Task 3, before tests that depend on the instance variables.
- ✓ The existing test that was about to break (`public_pages_test` action-library) is repaired in Task 5, the same task that ships the new honor grid.
- ✓ No "TBD", "TODO", "Add error handling" placeholders. Each step has executable code.
- ✓ Type/name consistency: `@timeline_preview_memories`, `@upcoming_events`, `@gallery_photos`, `@recent_tributes`, `@tributes_count` consistent across controller and partials.
- ✓ Each partial declared with its full markup — no "similar to Task N" handoffs.
- ✓ Locale YAML structure puts `date:` and `time:` as siblings under `en:`, not nested.
- ✓ Memory preview card honors the missing `relationship` field by simply not rendering it for Phase 2 (Phase 3 spec will add `name`/`relationship` columns to Memory; the partial will pick them up automatically without a partial change).

One latent risk: the "MVT II empty state" test (`Memory.update_all(status: pending)`) mutates the database in a non-transactional way relative to the integration test. The `ensure` block restores state, but if the test crashes between the mutation and the `ensure`, subsequent tests see corrupted seed data. Acceptable for development; if it bites, refactor to use a database transaction or fixture-based isolation.
