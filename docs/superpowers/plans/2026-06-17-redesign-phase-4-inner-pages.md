# Phase 4: Inner Pages Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the five remaining inner pages (Biography, Tributes, Trees, News & Press, Recipes) into the Garden direction, plus a small Tribute schema migration and two YAML-backed POROs.

**Architecture:** Each page rebuilds `index.html.erb` (and lightly its `show.html.erb` where applicable) using Phase 1 chrome + Phase 1/3 helpers. Two non-DB data sources (PressItem, Repertoire) live in `config/*.yml` and load via small POROs. Tribute gets a `category` enum to support filtering. The existing `_tribute_quote_card` partial is promoted from `app/views/pages/home/` to `app/views/shared/` so both the homepage MVT V and the new Tributes index can render it.

**Tech Stack:** Rails 8.1.2, ERB partials, Tailwind v4 (tokens from Phase 1), Stimulus (no new controllers needed), YAML config, Minitest.

**Spec:** `docs/superpowers/specs/2026-06-17-redesign-phase-4-inner-pages-design.md`

---

## Files touched in this phase

**Created:**
- `db/migrate/<ts>_add_category_to_tributes.rb`
- `db/migrate/<ts+1>_backfill_tribute_categories.rb`
- `app/models/press_item.rb`
- `app/models/repertoire.rb`
- `config/press_items.yml`
- `config/repertoire.yml`
- `app/views/shared/_tribute_quote_card.html.erb` (moved from pages/home/)
- `app/views/pages/chris/_quick_facts.html.erb`
- `app/views/pages/chris/_repertoire_group.html.erb`
- `app/views/tributes/_category_filter.html.erb`
- `app/views/trees/_world_map_placeholder.html.erb`
- `app/views/trees/_add_tree_form.html.erb`
- `app/views/trees/_other_ways_grid.html.erb`
- `app/views/pages/news/_press_item.html.erb`
- `app/views/pages/news/_year_group.html.erb`
- `app/views/recipes/_recipe_card.html.erb`
- `test/models/press_item_test.rb`
- `test/models/repertoire_test.rb`
- `test/integration/biography_test.rb`
- `test/integration/tributes_index_test.rb`
- `test/integration/trees_index_test.rb`
- `test/integration/news_test.rb`
- `test/integration/recipes_index_test.rb`

**Modified:**
- `app/models/tribute.rb` — add category enum
- `app/views/pages/chris.html.erb` — full rewrite
- `app/views/tributes/index.html.erb` — full rewrite
- `app/views/tributes/new.html.erb` — add category select
- `app/views/trees/index.html.erb` — full rewrite
- `app/views/pages/news.html.erb` — full rewrite (data now from PressItem)
- `app/views/recipes/index.html.erb` — full rewrite
- `app/views/recipes/show.html.erb` — light rewrite
- `app/controllers/tributes_controller.rb` — permit category, accept ?category filter
- `app/controllers/trees_controller.rb` — set `@new_tree` for inline form
- `app/controllers/pages_controller.rb` — `news` action loads PressItem data
- `app/views/pages/home/_tributes_preview.html.erb` — update render path for moved partial
- `db/seeds.rb` — set category on seeded tributes

**Not touched:**
- Phase 1-3 chrome, layout, models other than Tribute, controllers other than the three above.

---

## Task 1: Tribute category enum + migration + backfill

**Files:**
- Create: `db/migrate/<ts>_add_category_to_tributes.rb`
- Create: `db/migrate/<ts+1>_backfill_tribute_categories.rb`
- Modify: `app/models/tribute.rb`
- Modify: `test/models/tribute_test.rb`

- [ ] **Step 1: Generate the migration**

```bash
bin/rails generate migration add_category_to_tributes
```

Replace contents with:

```ruby
class AddCategoryToTributes < ActiveRecord::Migration[8.1]
  def change
    add_column :tributes, :category, :integer, default: 4, null: false
    add_index  :tributes, :category
  end
end
```

(Default 4 = `friends`, the safest fallback.)

- [ ] **Step 2: Generate the backfill migration**

```bash
bin/rails generate migration backfill_tribute_categories
```

Replace contents with:

```ruby
class BackfillTributeCategories < ActiveRecord::Migration[8.1]
  def up
    {
      "Margaret Thompson" => 0,  # family
      "James Anderson"    => 3,  # students (Dartmouth classmate but they're now alumni — student bucket)
      "Sigrid Olsen"      => 2,  # musicians
      "Anna Lee"          => 3,  # students
    }.each do |name, category|
      execute "UPDATE tributes SET category = #{category} WHERE name = '#{name}'"
    end
  end

  def down
    # No-op — column-level default handles fresh rows.
  end
end
```

- [ ] **Step 3: Write failing model tests**

Append to `test/models/tribute_test.rb` (or create if absent):

```ruby
require "test_helper"

class TributeTest < ActiveSupport::TestCase
  test "default category is friends" do
    t = Tribute.new(name: "X", content: "y")
    assert_equal "friends", t.category
  end

  test "category enum supports family/colleagues/musicians/students/friends" do
    t = Tribute.new(name: "X", content: "y")
    %w[family colleagues musicians students friends].each do |cat|
      t.category = cat
      assert_equal cat, t.category
    end
  end

  test "category predicates use prefix" do
    t = Tribute.new(name: "X", content: "y", category: :musicians)
    assert t.category_musicians?
    assert_not t.category_family?
  end
end
```

- [ ] **Step 4: Run migration + verify default**

```bash
bin/rails db:migrate
bin/rails runner 'puts Tribute.column_names.include?("category"); puts Tribute.first&.category.inspect'
```

Expected: `true` then a category name (post-backfill).

- [ ] **Step 5: Run tests and watch fail**

```bash
bin/rails test test/models/tribute_test.rb -v
```

Expected: model doesn't have the enum predicates yet → failures.

- [ ] **Step 6: Update Tribute model**

Edit `app/models/tribute.rb`. Add the category enum:

```ruby
class Tribute < ApplicationRecord
  enum :status, { pending: 0, published: 1, rejected: 2 }
  enum :category, { family: 0, colleagues: 1, musicians: 2, students: 3, friends: 4 }, prefix: :category

  has_one_attached :photo

  validates :name, :content, presence: true
end
```

- [ ] **Step 7: Run tests**

```bash
bin/rails test test/models/tribute_test.rb -v
```

Expected: 3 runs, all pass (the new ones; any existing tribute tests should also still pass).

- [ ] **Step 8: Verify backfill ran**

```bash
bin/rails runner 'Tribute.published.each { |t| puts "#{t.name}: #{t.category}" }'
```

Expected: Margaret → family, James → students, Sigrid → musicians, Anna → students.

- [ ] **Step 9: Update seeds.rb**

In `db/seeds.rb`, the existing `tributes_data` array doesn't have `category:`. Add it to each hash and to the `find_or_create_by!` block.

Change the array to:

```ruby
tributes_data = [
  { name: "Margaret Thompson", relationship: "Family friend", category: "family",
    content: "Christopher was an extraordinary person who touched everyone he met with his warmth, humor, and incredible talent. His memory is a blessing." },
  { name: "James Anderson", relationship: "Dartmouth classmate", category: "students",
    content: "We shared a dorm room our sophomore year and I learned what it meant to truly love what you do. Chris would conduct in his sleep — literally, hands moving above the blankets." },
  { name: "Sigrid Olsen", relationship: "Colleague, Jæren Symfoniorkester", category: "musicians",
    content: "Chris's scintillating charisma and smiling authority inspired singers and musicians alike to surpass themselves. We carry his phrasings with us into every performance." },
  { name: "Anna Lee", relationship: "Student", category: "students",
    content: "He'd write notes in the margins of my scores that were half pedagogy, half love letters to the music. I still have them all." },
]
```

And the block:

```ruby
tributes_data.each do |attrs|
  Tribute.find_or_create_by!(name: attrs[:name]) do |t|
    t.relationship = attrs[:relationship]
    t.content = attrs[:content]
    t.category = attrs[:category]
    t.status = :published
  end
end
```

- [ ] **Step 10: Verify seeds work**

```bash
bin/rails db:reset 2>&1 | tail -5
```

Expected: `Sample data created (3 memories, 3 events, 4 tributes, 1 trees).`

- [ ] **Step 11: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 176 runs (was 173, added 3 tribute tests), all pass.

- [ ] **Step 12: Commit**

```bash
git add db/migrate/ db/schema.rb app/models/tribute.rb test/models/tribute_test.rb db/seeds.rb
git commit -m "Phase 4: add category enum to Tribute + backfill"
```

---

## Task 2: PressItem PORO + YAML config

**Files:**
- Create: `app/models/press_item.rb`
- Create: `config/press_items.yml`
- Create: `test/models/press_item_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/models/press_item_test.rb`:

```ruby
require "test_helper"

class PressItemTest < ActiveSupport::TestCase
  test "all loads items from YAML" do
    items = PressItem.all
    assert items.size > 0
    assert_instance_of PressItem, items.first
  end

  test "each item has date, source, title, url, kind, snippet" do
    item = PressItem.all.first
    assert_respond_to item, :date
    assert_respond_to item, :source
    assert_respond_to item, :title
    assert_respond_to item, :url
    assert_respond_to item, :kind
    assert_respond_to item, :snippet
  end

  test "years returns descending unique years" do
    years = PressItem.years
    assert_equal years, years.uniq
    assert_equal years, years.sort.reverse
  end

  test "grouped_by_year groups items into year buckets, descending" do
    groups = PressItem.grouped_by_year
    years = groups.map(&:first)
    assert_equal years, years.sort_by { |y| -(y || 0) }
    groups.each { |year, items| assert items.all? { |i| i.year == year } }
  end
end
```

- [ ] **Step 2: Run tests, watch fail**

```bash
bin/rails test test/models/press_item_test.rb -v
```

Expected: `NameError: uninitialized constant PressItem`.

- [ ] **Step 3: Create the YAML data file**

Create `config/press_items.yml` with 12 entries derived from the existing hardcoded array in `app/views/pages/news.html.erb`. Use plausible dates (matching what's in the URL path for items that include a year; June 2020 for obituary items; "undated" handled with `~`/null for items without a date):

```yaml
- date: 2020-06-15
  source: Slippedisc
  title: "Tragic death of young US conductor, 36"
  snippet: "American conductor Christopher Quentin McMullen-Laird has died at 36, weeks after taking up his post in Norway."
  kind: obituary
  url: https://slippedisc.com/2020/06/tragic-death-of-young-us-conductor-36/

- date: 2020-06-16
  source: Pizzicato
  title: "American conductor Christopher Quentin McMullen-Laird dies at 36"
  snippet: "The conducting community mourns the loss of a charismatic and gifted young leader."
  kind: obituary
  url: https://www.pizzicato.lu/american-conductor-christopher-quentin-mcmullen-laird-dies-at-36/

- date: 2020-06-30
  source: Royal College of Music
  title: "In memoriam — Summer 2020"
  snippet: "Faculty and alumni remember Chris and his impact at RCM."
  kind: obituary
  url: https://www.rcm.ac.uk/upbeat/articles/inmemorysummer2020.aspx

- date: 2020-06-20
  source: The Violin Channel
  title: "American conductor Christopher Quentin McMullen-Laird, obituary"
  snippet: "Tributes pour in for the young American conductor who recently became Music Director of the Jæren Symfoniorkester."
  kind: obituary
  url: https://new.theviolinchannel.com/american-conductor-christopher-quentin-mcmullen-laird-died-passed-away-obituary/

- date: 2020-06-22
  source: Dartmouth Music Department
  title: "Christopher Quentin McMullen-Laird '05"
  snippet: "The music department remembers an alumnus whose career touched stages across Europe and America."
  kind: obituary
  url: https://music.dartmouth.edu/news/2020/06/christopher-quentin-mcmullen-laird-05

- date: 2020-06-25
  source: Dartmouth German Studies
  title: "Passing of a German studies alum"
  snippet: "Reflections from the German Studies faculty on Chris's intellectual breadth."
  kind: obituary
  url: https://german.dartmouth.edu/news/2020/06/passing-german-studies-alum

- date: 2020-07-01
  source: KCLSO
  title: "In memoriam"
  snippet: "The King's College London Symphony Orchestra remembers Chris."
  kind: obituary
  url: https://www.kclso.com/in-memoriam

- date: 2020-07-15
  source: MIO Munich
  title: "Dirigent Christopher McMullen-Laird"
  snippet: "Munich International Orchestra remembers their former music director."
  kind: feature
  url: https://www.mio-home.de/de/dirigent-christopher-mcmullen-laird

- date: 2020-07-20
  source: 2005 Dartmouth Class
  title: "Christopher Quentin McMullen-Laird"
  snippet: "The class of 2005 honors a classmate gone too soon."
  kind: feature
  url: https://2005.dartmouth.org/s/1353/clubs-classes15/index.aspx?sid=1353&gid=188&pgid=23501

- date: 2004-09-15
  source: The Dartmouth
  title: "Death brings literary experience to Moore"
  snippet: "An earlier campus piece referencing Christopher's literary engagement."
  kind: listing
  url: https://www.thedartmouth.com/article/2004/09/death-brings-literary-experience-to-moore

- source: The Dartmouth
  title: "Staff page — Christopher Q. McMullen-Laird"
  snippet: "Archive of Chris's contributions to The Dartmouth student newspaper."
  kind: listing
  url: https://www.thedartmouth.com/staff/christopher-q-mcmullen-laird

- source: Remembr.com
  title: "Memorial page"
  snippet: "Family-curated memorial site with photos and condolences."
  kind: listing
  url: https://www.remembr.com/en/christopher.ml.rcm
```

Note: the last two items have no `date:` key — they're undated.

- [ ] **Step 4: Create the PORO**

Create `app/models/press_item.rb`:

```ruby
class PressItem
  attr_reader :date, :source, :title, :snippet, :kind, :url

  def initialize(attrs)
    @date    = attrs["date"]
    @source  = attrs["source"]
    @title   = attrs["title"]
    @snippet = attrs["snippet"]
    @kind    = attrs["kind"]
    @url     = attrs["url"]
  end

  def self.all
    @all ||= load_items
  end

  def self.years
    all.map(&:year).compact.uniq.sort.reverse
  end

  def self.grouped_by_year
    all.group_by(&:year).sort_by { |year, _| -(year || 0) }
  end

  def year
    date&.year
  end

  def undated?
    date.nil?
  end

  def self.reload!
    @all = nil
  end

  def self.load_items
    raw = YAML.load_file(Rails.root.join("config/press_items.yml"))
    raw.map { |attrs| new(attrs) }
  end
end
```

- [ ] **Step 5: Run tests and watch pass**

```bash
bin/rails test test/models/press_item_test.rb -v
```

Expected: 4 runs, all pass.

- [ ] **Step 6: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 180 runs (was 176 + 4), all pass.

- [ ] **Step 7: Commit**

```bash
git add app/models/press_item.rb config/press_items.yml test/models/press_item_test.rb
git commit -m "Phase 4: add PressItem PORO backed by config/press_items.yml"
```

---

## Task 3: Repertoire PORO + YAML config

**Files:**
- Create: `app/models/repertoire.rb`
- Create: `config/repertoire.yml`
- Create: `test/models/repertoire_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/models/repertoire_test.rb`:

```ruby
require "test_helper"

class RepertoireTest < ActiveSupport::TestCase
  test "conducted returns an array of works grouped by composer" do
    list = Repertoire.conducted
    assert list.size > 0
    assert_respond_to list.first, :composer
    assert_respond_to list.first, :works
    assert_kind_of Array, list.first.works
  end

  test "assisted returns an array of works grouped by composer" do
    list = Repertoire.assisted
    assert list.size > 0
    assert_respond_to list.first, :composer
    assert_respond_to list.first, :works
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/models/repertoire_test.rb -v
```

Expected: `NameError`.

- [ ] **Step 3: Create the YAML data file**

Create `config/repertoire.yml` (placeholder content — family can refine later):

```yaml
conducted:
  - composer: Mozart
    works:
      - Die Entführung aus dem Serail
      - Le nozze di Figaro
  - composer: Beethoven
    works:
      - Symphony No. 7
      - Fidelio (excerpts)
  - composer: Mahler
    works:
      - Symphony No. 4
      - Lieder eines fahrenden Gesellen
  - composer: Verdi
    works:
      - La traviata (Cape Cod Opera)
      - Rigoletto (Opera Providence)
  - composer: Wagner
    works:
      - Tristan und Isolde (excerpts, Bayerische Staatsoper)

assisted:
  - composer: Strauss
    works:
      - Der Rosenkavalier (with Kirill Petrenko)
      - Salome (with Kent Nagano)
  - composer: Britten
    works:
      - Peter Grimes (Royal Ballet adaptation)
  - composer: Stravinsky
    works:
      - The Rite of Spring (Rambert Dance)
  - composer: Puccini
    works:
      - La bohème (Bayerische Staatsoper Education)
```

- [ ] **Step 4: Create the PORO**

Create `app/models/repertoire.rb`:

```ruby
class Repertoire
  Group = Struct.new(:composer, :works)

  def self.conducted
    load[:conducted]
  end

  def self.assisted
    load[:assisted]
  end

  def self.reload!
    @load = nil
  end

  def self.load
    @load ||= begin
      raw = YAML.load_file(Rails.root.join("config/repertoire.yml"))
      {
        conducted: raw["conducted"].map { |g| Group.new(g["composer"], g["works"]) },
        assisted:  raw["assisted"].map { |g| Group.new(g["composer"], g["works"]) },
      }
    end
  end
end
```

- [ ] **Step 5: Run tests**

```bash
bin/rails test test/models/repertoire_test.rb -v
```

Expected: 2 runs, both pass.

- [ ] **Step 6: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 182 runs.

- [ ] **Step 7: Commit**

```bash
git add app/models/repertoire.rb config/repertoire.yml test/models/repertoire_test.rb
git commit -m "Phase 4: add Repertoire PORO backed by config/repertoire.yml"
```

---

## Task 4: Move _tribute_quote_card to shared, update references

**Files:**
- Move: `app/views/pages/home/_tribute_quote_card.html.erb` → `app/views/shared/_tribute_quote_card.html.erb`
- Modify: `app/views/pages/home/_tributes_preview.html.erb` (update render path)

- [ ] **Step 1: Move the file**

```bash
git mv app/views/pages/home/_tribute_quote_card.html.erb app/views/shared/_tribute_quote_card.html.erb
```

- [ ] **Step 2: Update the existing render reference on the homepage**

Edit `app/views/pages/home/_tributes_preview.html.erb`. Find:

```erb
<%= render "pages/home/tribute_quote_card", tribute: tribute %>
```

Replace with:

```erb
<%= render "shared/tribute_quote_card", tribute: tribute %>
```

- [ ] **Step 3: Run full suite — homepage tests should still pass**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 182 runs, 0 failures.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Phase 4: promote _tribute_quote_card to shared partial"
```

---

## Task 5: Biography page (`/chris`)

**Files:**
- Modify: `app/views/pages/chris.html.erb` (full rewrite)
- Create: `app/views/pages/chris/_quick_facts.html.erb`
- Create: `app/views/pages/chris/_repertoire_group.html.erb`
- Create: `test/integration/biography_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/integration/biography_test.rb`:

```ruby
require "test_helper"

class BiographyTest < ActionDispatch::IntegrationTest
  test "biography renders header with eyebrow + h1" do
    get chris_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. II · Biography/
    assert_select "h1.font-serif", text: /Christopher McMullen-Laird/
  end

  test "biography renders the press blockquote" do
    get chris_path
    assert_select "blockquote" do
      assert_select "p", text: /scintillating charisma/
    end
  end

  test "biography renders Quick Facts dl" do
    get chris_path
    assert_select "dl.quick-facts" do
      assert_select "dt", minimum: 3
      assert_select "dd", minimum: 3
    end
  end

  test "biography renders Repertoire section with both groups" do
    get chris_path
    assert_select "[data-section='repertoire']" do
      assert_select "h3", text: /Operas Conducted/
      assert_select "h3", text: /Operas Assisted/
    end
  end

  test "Repertoire renders composers" do
    get chris_path
    assert_select "[data-section='repertoire']" do
      assert_select "*", text: /Mozart|Beethoven|Mahler/
    end
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/biography_test.rb -v
```

Expected: 5 failures.

- [ ] **Step 3: Create `_quick_facts.html.erb`**

```erb
<%# Sticky sidebar Quick Facts list. Locals: none (data hardcoded — family edits this partial directly). %>
<dl class="quick-facts space-y-4">
  <% [
    ["Born", "November 1984, Boston MA"],
    ["Education", "Royal College of Music · Dartmouth College"],
    ["Music Director of", "Jæren Symfoniorkester, 2019 — 2020"],
    ["Started career at", "Bayerische Staatsoper, Munich"],
    ["Made Stavanger his home", "2019"],
  ].each do |label, value| %>
    <div>
      <dt class="text-eyebrow text-sage mb-1"><%= label %></dt>
      <dd class="font-serif text-[18px] text-ink m-0"><%= value %></dd>
    </div>
  <% end %>
</dl>
```

- [ ] **Step 4: Create `_repertoire_group.html.erb`**

```erb
<%# Renders one RepertoireGroup list. Locals: title (string), groups (array of Repertoire::Group) %>
<div>
  <h3 class="font-serif text-[28px] text-ink mt-0 mb-5 font-normal"><%= title %></h3>
  <dl class="space-y-3">
    <% groups.each do |g| %>
      <div class="grid grid-cols-[1fr_2fr] gap-4 items-baseline">
        <dt class="font-serif italic text-[19px] text-moss m-0"><%= g.composer %></dt>
        <dd class="text-sm text-ink/80 leading-relaxed m-0">
          <%= g.works.join(" · ") %>
        </dd>
      </div>
    <% end %>
  </dl>
</div>
```

- [ ] **Step 5: Replace `app/views/pages/chris.html.erb`**

```erb
<% content_for :title, "Biography — Christopher Quentin McMullen-Laird" %>

<%# Two-column layout — bio left, sticky sidebar right %>
<section class="px-6 lg:px-14 pt-12 pb-16">
  <div class="grid grid-cols-1 lg:grid-cols-[1.5fr_1fr] gap-10 lg:gap-14">
    <%# Left column — bio %>
    <div>
      <%= musical_eyebrow("Op. II · Biography", with_rule: true) %>
      <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3 mb-0">
        Christopher McMullen-Laird
      </h1>
      <p class="font-serif italic text-xl md:text-2xl text-sage mt-5">
        Conductor &nbsp;·&nbsp; environmentalist &nbsp;·&nbsp; beloved
      </p>

      <div class="font-serif text-[19px] leading-relaxed text-ink mt-10 space-y-6">
        <p>
          American conductor Christopher Quentin McMullen-Laird started the 2019 — 2020 season in his new
          post of Music Director of the Jæren Symfoniorkester in Norway. He began his career at the
          Bayerische Staatsoper in Munich, where he prompted over 50 opera productions, working alongside
          Music Directors Kent Nagano and Kirill Petrenko.
        </p>
        <p>
          Christopher conducted productions for Cape Cod Opera, Opera Providence, Opera Rogaland,
          Schlosstheater Rheinsberg, Tokyo Opera Association, and the education department at the Bayerische
          Staatsoper. He also assisted on dance productions at the Royal Ballet and Rambert Dance
          Company in London.
        </p>
        <p>
          In addition to opera and ballet, Christopher kept a busy and varied concert schedule. He was
          previously Music Director of the Munich International Orchestra, the Bjergsted Symfoniorkester,
          and the Phoenix Youth Orchestra, and appeared as guest conductor with the Dartington Festival
          Orchestra, the Filharmonia Zielenogorska, and the Abaco Orchester.
        </p>
        <p>
          He held degrees from Dartmouth College and the Royal College of Music in London, where he studied
          conducting on full scholarship. He spoke five languages with varying fluency, gardened in three
          climates, and corresponded with friends from his student years until the week he died.
        </p>
        <p>
          Christopher made his home in Stavanger, Norway in 2019. He died there in June 2020 at the age of
          36, weeks after his first season with the Jæren Symfoniorkester ended.
        </p>
      </div>

      <blockquote class="mt-10 pl-5 border-l-2 border-rose max-w-[640px]">
        <p class="font-serif italic text-[19px] md:text-[22px] leading-[1.4] text-ink m-0">
          "His scintillating charisma and smiling authority inspired singers and musicians alike to surpass themselves."
        </p>
        <footer class="text-eyebrow text-ink/55 mt-3">— Jærbladet</footer>
      </blockquote>
    </div>

    <%# Right column — sidebar %>
    <aside class="lg:sticky lg:top-24 self-start space-y-6">
      <%# Portrait placeholder %>
      <div class="aspect-[4/5] rounded-md border border-ink/8 shadow-card relative overflow-hidden"
           style="background: linear-gradient(160deg, rgba(58,82,64,0.20), rgba(168,88,76,0.18)), repeating-linear-gradient(45deg, rgba(58,82,64,0.08) 0 16px, transparent 16px 32px);">
        <div class="absolute bottom-3 left-3 text-eyebrow text-cream mix-blend-difference">
          [ portrait — Stavanger 2019 ]
        </div>
      </div>

      <%# Two small photo placeholders %>
      <div class="grid grid-cols-2 gap-3">
        <div class="aspect-square rounded-md border border-ink/8" style="background: linear-gradient(135deg, rgba(90,122,94,0.18), rgba(58,82,64,0.25));">
          <div class="text-eyebrow text-cream mix-blend-difference p-2">[ rehearsal ]</div>
        </div>
        <div class="aspect-square rounded-md border border-ink/8" style="background: linear-gradient(135deg, rgba(168,88,76,0.15), rgba(90,122,94,0.25));">
          <div class="text-eyebrow text-cream mix-blend-difference p-2">[ podium ]</div>
        </div>
      </div>

      <%= render "pages/chris/quick_facts" %>
    </aside>
  </div>
</section>

<%# Repertoire section %>
<section data-section="repertoire" class="bg-linen px-6 lg:px-14 py-16 lg:py-24">
  <%= musical_eyebrow("Op. IV · Repertoire") %>
  <h2 class="font-serif text-4xl md:text-5xl lg:text-[56px] font-normal leading-tight tracking-tight text-ink mt-3 mb-10">
    What he conducted, and where he <em class="font-serif italic text-moss">assisted</em>.
  </h2>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-12">
    <%= render "pages/chris/repertoire_group", title: "Operas Conducted", groups: Repertoire.conducted %>
    <%= render "pages/chris/repertoire_group", title: "Operas Assisted", groups: Repertoire.assisted %>
  </div>
</section>
```

- [ ] **Step 6: Run tests**

```bash
bin/rails test test/integration/biography_test.rb -v
```

Expected: 5 runs, all pass.

- [ ] **Step 7: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 187 runs (was 182 + 5), all pass.

- [ ] **Step 8: Commit**

```bash
git add app/views/pages/chris.html.erb app/views/pages/chris/ test/integration/biography_test.rb
git commit -m "Phase 4: biography page redesign with Quick Facts + Repertoire"
```

---

## Task 6: Tributes page (`/tributes`)

**Files:**
- Modify: `app/views/tributes/index.html.erb` (full rewrite)
- Modify: `app/views/tributes/new.html.erb` (add category select)
- Modify: `app/controllers/tributes_controller.rb` (filter by category, permit category)
- Create: `app/views/tributes/_category_filter.html.erb`
- Create: `test/integration/tributes_index_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/integration/tributes_index_test.rb`:

```ruby
require "test_helper"

class TributesIndexTest < ActionDispatch::IntegrationTest
  def setup
    Tribute.delete_all
    Tribute.create!(name: "Mom", relationship: "Mother", content: "My dearest son.", category: :family, status: :published)
    Tribute.create!(name: "Colleague", content: "A genius in the pit.", category: :musicians, status: :published)
    Tribute.create!(name: "Student", content: "He changed my musical life.", category: :students, status: :published)
  end

  test "renders header" do
    get tributes_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. V · Tributes/
    assert_select "h1.font-serif", text: /In their/
  end

  test "renders category filter chips" do
    get tributes_path
    assert_select "[data-category-filter]" do
      assert_select "*", text: "All"
      assert_select "*", text: /Family/i
      assert_select "*", text: /Colleagues/i
      assert_select "*", text: /Musicians/i
      assert_select "*", text: /Students/i
      assert_select "*", text: /Friends/i
    end
  end

  test "all chip active by default" do
    get tributes_path
    assert_select "[data-category-filter] .bg-moss.text-cream", text: "All"
  end

  test "category filter selects only that category" do
    get tributes_path, params: { category: "musicians" }
    assert_match "A genius in the pit.", response.body
    assert_no_match "My dearest son.", response.body
    assert_no_match "He changed my musical life.", response.body
  end

  test "renders Share a tribute CTA" do
    get tributes_path
    assert_select "a[href=?]", new_tribute_path, text: /Share a tribute/i
  end

  test "empty category shows Clear filter link" do
    get tributes_path, params: { category: "family" }
    Tribute.where(category: :family).delete_all
    get tributes_path, params: { category: "family" }
    assert_match(/No tributes in this category/, response.body)
    assert_select "a[href=?]", tributes_path, text: /Clear filter/i
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/tributes_index_test.rb -v
```

Expected: 6 failures (old Stone/Blue page, no filter, etc.).

- [ ] **Step 3: Update TributesController**

Edit `app/controllers/tributes_controller.rb`. Replace its contents with:

```ruby
class TributesController < ApplicationController
  def index
    scope = Tribute.published.order(created_at: :desc)
    @active_category = params[:category].presence
    @tributes = @active_category ? scope.where(category: @active_category) : scope
    @categories = Tribute.categories.keys  # ["family", "colleagues", "musicians", "students", "friends"]
    @total_count = Tribute.published.count
  end

  def show
    @tribute = Tribute.published.find(params[:id])
  end

  def new
    @tribute = Tribute.new(category: :friends)
  end

  def create
    @tribute = Tribute.new(tribute_params)
    @tribute.status = :pending

    if @tribute.save
      redirect_to tributes_path, notice: "Thank you for your tribute. It will appear after review."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def tribute_params
    params.require(:tribute).permit(:name, :relationship, :content, :category, :photo)
  end
end
```

- [ ] **Step 4: Create category filter partial**

Create `app/views/tributes/_category_filter.html.erb`:

```erb
<%# Sticky category filter chip row. Locals: categories (array of strings), active (string or nil) %>
<div data-category-filter
     class="sticky top-[68px] z-30 bg-cream/90 backdrop-blur-[10px] border-b border-ink/8 px-6 lg:px-14 py-3 flex gap-2 overflow-x-auto">
  <%= link_to "All", tributes_path, class: chip_class(active: active.nil?) %>
  <% categories.each do |c| %>
    <%= link_to c.titleize, tributes_path(category: c), class: chip_class(active: active == c) %>
  <% end %>
</div>
```

(Uses `chip_class` helper added in Phase 3.)

- [ ] **Step 5: Replace `app/views/tributes/index.html.erb`**

```erb
<% content_for :title, "Tributes — Christopher Quentin" %>

<section class="px-6 lg:px-14 pt-12 pb-8">
  <%= musical_eyebrow("Op. V · Tributes", with_rule: true) %>
  <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3">
    In their <em class="font-serif italic text-moss">own words</em>.
  </h1>
  <p class="text-[17px] text-ink/65 mt-3 max-w-[640px]">
    <%= pluralize(@total_count, "tribute") %> from family, colleagues, students, and friends.
  </p>
</section>

<%= render "tributes/category_filter", categories: @categories, active: @active_category %>

<section class="px-6 lg:px-14 py-12">
  <% if @tributes.any? %>
    <div class="columns-1 md:columns-2 lg:columns-3 gap-5">
      <% @tributes.each do |tribute| %>
        <div class="break-inside-avoid mb-5">
          <%= render "shared/tribute_quote_card", tribute: tribute %>
        </div>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-20">
      <p class="font-serif italic text-2xl text-ink/70 mb-4">No tributes in this category yet.</p>
      <%= link_to "Clear filter →", tributes_path, class: "text-moss text-sm font-medium hover:underline" %>
    </div>
  <% end %>
</section>

<%# Share-a-tribute CTA strip %>
<section class="bg-linen px-6 lg:px-14 py-16">
  <div class="max-w-[720px] mx-auto text-center">
    <h2 class="font-serif text-3xl md:text-4xl text-ink mt-0">
      Have a story you'd like to share?
    </h2>
    <p class="text-[17px] text-ink/65 mt-3">Add a tribute to the collection.</p>
    <%= link_to "+ Share a tribute", new_tribute_path,
          class: "inline-block mt-6 bg-moss text-cream rounded-full px-6 py-3 text-sm font-medium no-underline hover:bg-ink transition-colors" %>
  </div>
</section>
```

- [ ] **Step 6: Update tribute new form to include category**

Edit `app/views/tributes/new.html.erb`. Find the existing form fields. Add a category select alongside the relationship field. Since the existing form may still be in Stone/Blue styling, this is a minimal update — find the form_with block and add this somewhere inside (after the relationship field if one exists, or before content):

```erb
<div class="mb-4">
  <%= f.label :category, "Category", class: "block text-sm font-medium text-stone-700 mb-1" %>
  <%= f.select :category, Tribute.categories.keys.map { |c| [c.titleize, c] }, {}, class: "w-full px-3 py-2 border border-stone-300 rounded-lg" %>
</div>
```

(The form's overall styling is not being redesigned in Phase 4 — just the category field is added.)

- [ ] **Step 7: Run tests**

```bash
bin/rails test test/integration/tributes_index_test.rb -v
```

Expected: 6 runs, all pass.

- [ ] **Step 8: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 193 runs (was 187 + 6).

- [ ] **Step 9: Commit**

```bash
git add app/views/tributes/ app/controllers/tributes_controller.rb test/integration/tributes_index_test.rb
git commit -m "Phase 4: tributes page redesign with category filter masonry"
```

---

## Task 7: Trees page (`/trees`)

**Files:**
- Modify: `app/views/trees/index.html.erb` (full rewrite)
- Modify: `app/controllers/trees_controller.rb` (load new tree + published trees)
- Create: `app/views/trees/_world_map_placeholder.html.erb`
- Create: `app/views/trees/_add_tree_form.html.erb`
- Create: `app/views/trees/_other_ways_grid.html.erb`
- Create: `test/integration/trees_index_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/integration/trees_index_test.rb`:

```ruby
require "test_helper"

class TreesIndexTest < ActionDispatch::IntegrationTest
  test "renders header with lento e sereno" do
    get trees_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. VI · The Trees/
    assert_select "h1.font-serif", text: /A living memorial/
    assert_match "lento e sereno", response.body
  end

  test "renders world map placeholder with markers for published trees" do
    get trees_path
    assert_select "[data-section='trees-map']"
    assert_select "[data-tree-marker]"  # at least one marker (seeded tree)
  end

  test "renders stat callout" do
    get trees_path
    assert_match(/\d+ trees/, response.body)
    assert_match(/9 countries/, response.body)
  end

  test "renders inline add-tree form" do
    get trees_path
    assert_select "form[action=?]", trees_path do
      assert_select "input[name='tree[name]']"
      assert_select "input[name='tree[email]']"
      assert_select "input[name='tree[address]']"
    end
  end

  test "renders Why trees pull quote" do
    get trees_path
    assert_match(/plant a tree before he'd write a letter/i, response.body)
  end

  test "renders Other ways in grid" do
    get trees_path
    assert_select "[data-section='other-ways']" do
      assert_select "a[href=?]", new_bee_hive_path
      assert_select "a[href=?]", new_memory_path
      assert_select "a[href=?]", funds_path
    end
  end

  test "links to full interactive map" do
    get trees_path
    assert_select "a[href=?]", map_path, text: /full map/i
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/trees_index_test.rb -v
```

Expected: 7 failures.

- [ ] **Step 3: Update TreesController**

Edit `app/controllers/trees_controller.rb`. Replace its contents with:

```ruby
class TreesController < ApplicationController
  def index
    @trees = Tree.published.order(created_at: :desc)
    @new_tree = Tree.new
    @stats = {
      trees: Tree.published.sum(:tree_count),
      cities: Tree.published.where.not(address: nil).distinct.count(:address),
      countries: 9, # static for Phase 4; country field doesn't exist on Tree
    }
  end

  def show
    @tree = Tree.published.find(params[:id])
  end

  def new
    @tree = Tree.new
  end

  def create
    @tree = Tree.new(tree_params)
    @tree.status = :pending

    if @tree.save
      redirect_to trees_path, notice: "Thank you for planting a tree! It will appear on the map after review."
    else
      @trees = Tree.published.order(created_at: :desc)
      @new_tree = @tree
      @stats = {
        trees: Tree.published.sum(:tree_count),
        cities: Tree.published.where.not(address: nil).distinct.count(:address),
        countries: 9,
      }
      render :index, status: :unprocessable_entity
    end
  end

  private

  def tree_params
    params.require(:tree).permit(:name, :email, :address, :tree_count, :story, :photo)
  end
end
```

- [ ] **Step 4: Create `_world_map_placeholder.html.erb`**

```erb
<%# Stylized world-map placeholder with positioned markers.
    Locals: trees (collection of Trees with latitude/longitude), stats (hash) %>
<section data-section="trees-map" class="relative px-6 lg:px-14 py-12">
  <div class="relative h-[400px] md:h-[500px] rounded-md border border-ink/8 overflow-hidden"
       style="background: radial-gradient(ellipse at center, rgba(90,122,94,0.05) 0%, rgba(58,82,64,0.10) 60%, rgba(28,38,32,0.18) 100%);">
    <%# Faint dotted-grid pattern as continent suggestion %>
    <div class="absolute inset-0 opacity-25"
         style="background-image: radial-gradient(rgba(28,38,32,0.18) 1px, transparent 1px); background-size: 14px 14px;"
         aria-hidden="true"></div>

    <%# Tree markers — one per published tree with lat/lng %>
    <% trees.each do |tree| %>
      <% next unless tree.latitude && tree.longitude %>
      <% x = ((tree.longitude + 180.0) / 360.0 * 100).clamp(0.0, 100.0) %>
      <% y = ((90.0 - tree.latitude) / 180.0 * 100).clamp(0.0, 100.0) %>
      <div data-tree-marker
           class="absolute w-3 h-3 rounded-full -translate-x-1/2 -translate-y-1/2"
           style="left: <%= x %>%; top: <%= y %>%; background: radial-gradient(circle, rgba(58,82,64,1) 0%, rgba(58,82,64,0.4) 70%, transparent 100%);"
           title="<%= tree.name %>"></div>
    <% end %>

    <%# Stat callout top-right %>
    <div class="absolute top-5 right-5 bg-white rounded-md border border-ink/8 shadow-card p-4 text-sm">
      <div class="text-eyebrow text-sage mb-1">Living tally</div>
      <div class="font-serif text-2xl text-ink"><%= stats[:trees] %> trees</div>
      <div class="text-sm text-ink/65 mt-1"><%= stats[:cities] %> cities · <%= stats[:countries] %> countries</div>
    </div>
  </div>

  <div class="mt-4 text-center">
    <%= link_to "View the full map →", map_path,
          class: "text-moss text-sm font-medium no-underline hover:underline" %>
  </div>
</section>
```

- [ ] **Step 5: Create `_add_tree_form.html.erb`**

```erb
<%# Inline single-step add-tree form. Locals: tree (Tree.new or @new_tree) %>
<%= form_with model: tree, class: "space-y-4" do |f| %>
  <% if tree.errors.any? %>
    <div class="bg-linen border-l-2 border-rose text-rose p-3 text-sm">
      <% tree.errors.full_messages.each do |msg| %>
        <div><%= msg %></div>
      <% end %>
    </div>
  <% end %>

  <div>
    <%= f.label :name, "Your name", class: "text-eyebrow text-sage block mb-1" %>
    <%= f.text_field :name, required: true,
          class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
  </div>

  <div>
    <%= f.label :email, "Email", class: "text-eyebrow text-sage block mb-1" %>
    <%= f.email_field :email, required: true,
          class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
  </div>

  <div>
    <%= f.label :address, "Location (city, country)", class: "text-eyebrow text-sage block mb-1" %>
    <%= f.text_field :address, required: true,
          placeholder: "Stavanger, Norway",
          class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
  </div>

  <%= f.hidden_field :tree_count, value: 1 %>

  <div>
    <%= f.label :story, "Why are you planting this tree? (optional)", class: "text-eyebrow text-sage block mb-1" %>
    <%= f.text_area :story, rows: 4,
          class: "w-full border border-ink/15 rounded-md p-3 focus:border-moss outline-none bg-white" %>
  </div>

  <%= f.submit "Plant my tree →",
        class: "bg-moss text-cream rounded-full px-6 py-3 text-sm font-medium cursor-pointer hover:bg-ink transition-colors" %>
<% end %>
```

- [ ] **Step 6: Create `_other_ways_grid.html.erb`**

```erb
<%# Three-card grid mirroring the homepage honor cards. No locals. %>
<section data-section="other-ways" class="px-6 lg:px-14 py-16">
  <%= render "shared/movement_label", no: "Op. VI.iii", title: "Other ways in", marking: "dolce" %>
  <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
    <% [
      { glyph: "♪", title: "Adopt a Bee Hive", body: "Pollinators were one of his loves. Register a hive on the unified map.",
        cta: "Adopt a hive →", path: new_bee_hive_path, accent: "text-sage" },
      { glyph: "¶", title: "Share a Memory", body: "A photo, a story, an audio clip — contribute to the timeline.",
        cta: "Share a memory →", path: new_memory_path, accent: "text-rose" },
      { glyph: "♭", title: "Support a Fund", body: "The Dartmouth Conducting Endowment and four other funds.",
        cta: "Contribute →", path: funds_path, accent: "text-moss" },
    ].each do |card| %>
      <%= link_to card[:path], class: "group block no-underline" do %>
        <article class="bg-white rounded-md border border-ink/8 shadow-card p-6 flex flex-col min-h-[200px] hover:border-ink/15 transition-colors">
          <div class="font-serif text-[32px] <%= card[:accent] %> leading-none mb-1.5" aria-hidden="true"><%= card[:glyph] %></div>
          <h3 class="font-serif text-3xl text-ink mt-1.5 leading-tight font-normal"><%= card[:title] %></h3>
          <p class="text-sm leading-relaxed text-ink/70 mt-3 flex-1"><%= card[:body] %></p>
          <span class="<%= card[:accent] %> text-sm font-medium mt-4 group-hover:underline"><%= card[:cta] %></span>
        </article>
      <% end %>
    <% end %>
  </div>
</section>
```

- [ ] **Step 7: Replace `app/views/trees/index.html.erb`**

```erb
<% content_for :title, "Trees — Christopher Quentin" %>

<%# Hero %>
<section class="px-6 lg:px-14 pt-12 pb-8">
  <%= musical_eyebrow("Op. VI · The Trees", with_rule: true) %>
  <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3">
    A living memorial in <em class="font-serif italic text-moss">nine countries</em>.
  </h1>
  <p class="font-serif italic text-xl md:text-2xl text-sage mt-4">lento e sereno</p>
  <p class="text-[17px] text-ink/65 mt-3 max-w-[640px]">
    One tree per memory. Plant one in his honor.
  </p>
</section>

<%# World map placeholder %>
<%= render "trees/world_map_placeholder", trees: @trees, stats: @stats %>

<%# Add-a-tree section %>
<section class="px-6 lg:px-14 py-16">
  <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 lg:gap-16">
    <div>
      <%= musical_eyebrow("Plant a tree") %>
      <h2 class="font-serif text-4xl md:text-5xl text-ink mt-3 mb-6 font-normal leading-tight">
        Add a tree to the map.
      </h2>
      <%= render "trees/add_tree_form", tree: @new_tree %>
    </div>
    <div class="aspect-[4/5] rounded-md border border-ink/8 relative overflow-hidden"
         style="background: linear-gradient(160deg, rgba(58,82,64,0.20), rgba(168,88,76,0.16)), repeating-linear-gradient(45deg, rgba(58,82,64,0.08) 0 16px, transparent 16px 32px);">
      <div class="absolute bottom-3 left-3 text-eyebrow text-cream mix-blend-difference">
        [ the first Chris tree — Ann Arbor, planted by his parents ]
      </div>
    </div>
  </div>
</section>

<%# Full-bleed quote section (moss bg) %>
<section class="relative bg-moss text-cream px-6 lg:px-14 py-20 lg:py-28">
  <%= render "shared/staff_lines", top: 0, height: 120, opacity: 0.10 %>
  <div class="relative max-w-[860px] mx-auto text-center">
    <div class="text-eyebrow text-cream/70 mb-6">Op. VI.ii · Why trees</div>
    <blockquote class="font-serif italic text-3xl md:text-4xl lg:text-5xl leading-snug m-0">
      "He'd plant a tree before he'd write a letter. So we plant trees."
    </blockquote>
    <footer class="text-eyebrow text-cream/70 mt-6">— McMullen family</footer>
  </div>
</section>

<%= render "trees/other_ways_grid" %>
```

- [ ] **Step 8: Verify seeded tree appears as a marker**

```bash
bin/rails runner 'puts Tree.published.where.not(latitude: nil, longitude: nil).count'
```

Expected: ≥ 1.

- [ ] **Step 9: Run tests**

```bash
bin/rails test test/integration/trees_index_test.rb -v
```

Expected: 7 runs, all pass.

- [ ] **Step 10: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 200 runs (was 193 + 7), all pass.

- [ ] **Step 11: Commit**

```bash
git add app/views/trees/ app/controllers/trees_controller.rb test/integration/trees_index_test.rb
git commit -m "Phase 4: trees page redesign with stylized map + inline form + Why trees quote"
```

---

## Task 8: News & Press page (`/updates`)

**Files:**
- Modify: `app/views/pages/news.html.erb` (full rewrite)
- Modify: `app/controllers/pages_controller.rb` (`news` action loads PressItem data)
- Create: `app/views/pages/news/_press_item.html.erb`
- Create: `app/views/pages/news/_year_group.html.erb`
- Create: `test/integration/news_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/integration/news_test.rb`:

```ruby
require "test_helper"

class NewsTest < ActionDispatch::IntegrationTest
  test "renders header" do
    get news_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. VII · News & Press/
    assert_select "h1.font-serif", text: /world's/i
  end

  test "renders at least one year group" do
    get news_path
    assert_select "[data-year-group]", minimum: 1
  end

  test "renders press items with source + title + kind chip" do
    get news_path
    assert_select "[data-press-item]" do
      assert_select "*", text: /Slippedisc|RCM|Pizzicato|Dartmouth/i
    end
  end

  test "press item title link opens external URL in new tab" do
    get news_path
    assert_select "[data-press-item] a[target='_blank'][rel='noopener']"
  end

  test "kind chip shown for each item" do
    get news_path
    # At least one obituary chip
    assert_select ".text-eyebrow", text: /obituary|interview|feature|listing/i, minimum: 1
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/news_test.rb -v
```

Expected: 5 failures.

- [ ] **Step 3: Update `PagesController#news`**

Edit `app/controllers/pages_controller.rb`. Replace the `news` action:

```ruby
  def news
    @items_by_year = PressItem.grouped_by_year
    @total = PressItem.all.count
    @years = PressItem.years
  end
```

- [ ] **Step 4: Create `_press_item.html.erb`**

```erb
<%# Single press item row. Local: item (PressItem) %>
<div data-press-item class="grid grid-cols-1 md:grid-cols-[180px_1fr_160px] gap-4 md:gap-6 py-5 border-b border-ink/8 items-start">
  <div class="text-sm">
    <% if item.date %>
      <div class="text-eyebrow text-sage"><%= l(item.date, format: :event_date) rescue item.date.strftime("%b %-d, %Y") %></div>
    <% else %>
      <div class="text-eyebrow text-sage opacity-60">undated</div>
    <% end %>
    <div class="font-serif italic text-ink/80 mt-1"><%= item.source %></div>
  </div>

  <div>
    <h3 class="font-serif text-[22px] leading-snug text-ink m-0 font-normal">
      <%= link_to item.title, item.url, target: "_blank", rel: "noopener",
            class: "no-underline text-ink hover:text-moss" %>
    </h3>
    <p class="text-[15px] text-ink/65 leading-relaxed mt-2 m-0"><%= item.snippet %></p>
  </div>

  <div class="flex flex-col md:items-end gap-2">
    <span class="text-eyebrow text-moss bg-linen rounded-full px-3 py-1 inline-block"><%= item.kind %></span>
    <%= link_to "Read →", item.url, target: "_blank", rel: "noopener",
          class: "text-sm text-moss font-medium hover:underline no-underline" %>
  </div>
</div>
```

- [ ] **Step 5: Create `_year_group.html.erb`**

```erb
<%# Year group: left column with the year (Cormorant 56px moss), right column with items.
    Locals: year (int or nil), items (array of PressItem) %>
<div data-year-group class="grid grid-cols-1 lg:grid-cols-[180px_1fr] gap-6 lg:gap-12 py-8 border-t border-ink/8">
  <div>
    <h2 class="font-serif text-5xl md:text-[56px] font-normal text-moss leading-none m-0 lg:sticky lg:top-24">
      <%= year || "—" %>
    </h2>
  </div>
  <div>
    <% items.each do |item| %>
      <%= render "pages/news/press_item", item: item %>
    <% end %>
  </div>
</div>
```

- [ ] **Step 6: Replace `app/views/pages/news.html.erb`**

```erb
<% content_for :title, "News & Press — Christopher Quentin" %>

<section class="px-6 lg:px-14 pt-12 pb-8">
  <%= musical_eyebrow("Op. VII · News & Press", with_rule: true) %>
  <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3">
    In the <em class="font-serif italic text-moss">world's</em> own words.
  </h1>
  <p class="text-[17px] text-ink/65 mt-3">
    <%= pluralize(@total, "mention") %> across <%= pluralize(@years.count, "year") %>.
  </p>
</section>

<section class="px-6 lg:px-14 pb-20">
  <% @items_by_year.each do |year, items| %>
    <%= render "pages/news/year_group", year: year, items: items %>
  <% end %>
</section>
```

- [ ] **Step 7: Run tests**

```bash
bin/rails test test/integration/news_test.rb -v
```

Expected: 5 runs, all pass.

- [ ] **Step 8: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 205 runs.

- [ ] **Step 9: Commit**

```bash
git add app/views/pages/news.html.erb app/views/pages/news/ app/controllers/pages_controller.rb test/integration/news_test.rb
git commit -m "Phase 4: news & press page redesign with year-grouped vertical timeline"
```

---

## Task 9: Recipes page (`/recipes`)

**Files:**
- Modify: `app/views/recipes/index.html.erb` (full rewrite)
- Modify: `app/views/recipes/show.html.erb` (light rewrite)
- Create: `app/views/recipes/_recipe_card.html.erb`
- Create: `test/integration/recipes_index_test.rb`

- [ ] **Step 1: Write failing tests**

Create `test/integration/recipes_index_test.rb`:

```ruby
require "test_helper"

class RecipesIndexTest < ActionDispatch::IntegrationTest
  def setup
    Recipe.delete_all
    Recipe.create!(
      submitter_name: "Aunt Margaret",
      title: "Chris's Cape Cod Clam Chowder",
      ingredients: "Clams, potatoes, onions, cream",
      instructions: "Simmer.",
      status: :published
    )
    Recipe.create!(
      submitter_name: "Sigrid",
      title: "Norwegian Cinnamon Buns",
      ingredients: "Flour, butter, cinnamon, cardamom",
      instructions: "Knead.",
      status: :published
    )
  end

  test "renders header" do
    get recipes_path
    assert_response :success
    assert_select ".text-eyebrow", text: /Op\. VIII · Recipes/
    assert_select "h1.font-serif", text: /cooked/i
  end

  test "renders one recipe card per published recipe" do
    get recipes_path
    assert_select "[data-recipe-card]", count: 2
  end

  test "recipe card shows title, attribution, link" do
    get recipes_path
    assert_select "[data-recipe-card]" do
      assert_select "h3", text: /Cape Cod Clam Chowder/
      assert_select "*", text: /from Aunt Margaret/
    end
  end

  test "submit a recipe CTA links to new_recipe_path" do
    get recipes_path
    assert_select "a[href=?]", new_recipe_path, text: /Submit a recipe/i
  end

  test "Recipe show page renders without crashing" do
    recipe = Recipe.first
    get recipe_path(recipe)
    assert_response :success
    assert_select "h1.font-serif", text: /#{recipe.title}/
  end
end
```

- [ ] **Step 2: Run, watch fail**

```bash
bin/rails test test/integration/recipes_index_test.rb -v
```

Expected: 5 failures.

- [ ] **Step 3: Create `_recipe_card.html.erb`**

```erb
<%# Single recipe card. Local: recipe %>
<article data-recipe-card class="bg-white rounded-md border border-ink/8 shadow-card overflow-hidden">
  <% if recipe.photo.attached? %>
    <%= image_tag recipe.photo, class: "w-full aspect-[4/3] object-cover", alt: recipe.title %>
  <% else %>
    <div class="w-full aspect-[4/3] relative"
         style="background: linear-gradient(135deg, rgba(168,88,76,0.18), rgba(58,82,64,0.20)), repeating-linear-gradient(45deg, rgba(90,122,94,0.06) 0 12px, transparent 12px 24px);">
      <div class="absolute bottom-3 left-3 text-eyebrow text-cream mix-blend-difference">
        [ recipe ]
      </div>
    </div>
  <% end %>
  <div class="p-6">
    <div class="flex items-center justify-between mb-3">
      <span class="text-eyebrow text-sage"><%= l(recipe.created_at.to_date, format: :memory) %></span>
    </div>
    <h3 class="font-serif text-[24px] font-normal text-ink leading-tight m-0">
      <%= link_to recipe.title, recipe_path(recipe), class: "no-underline text-ink hover:text-moss" %>
    </h3>
    <p class="font-serif italic text-sage text-base mt-2 m-0">from <%= recipe.submitter_name %></p>
    <p class="text-sm text-ink/65 leading-relaxed mt-3 m-0"><%= truncate(recipe.ingredients.to_s, length: 100) %></p>
    <%= link_to "Read the full recipe →", recipe_path(recipe),
          class: "text-moss text-sm font-medium mt-4 inline-block no-underline hover:underline" %>
  </div>
</article>
```

- [ ] **Step 4: Replace `app/views/recipes/index.html.erb`**

```erb
<% content_for :title, "Recipes — Christopher Quentin" %>

<section class="px-6 lg:px-14 pt-12 pb-8">
  <%= musical_eyebrow("Op. VIII · Recipes", with_rule: true) %>
  <h1 class="font-serif text-5xl md:text-6xl lg:text-[80px] font-normal leading-tight tracking-tight text-ink mt-3">
    What he <em class="font-serif italic text-moss">cooked</em>.
  </h1>
  <p class="text-[17px] text-ink/65 mt-3 max-w-[640px]">
    <%= pluralize(@recipes.count, "recipe") %> from people who shared his kitchen.
  </p>
</section>

<section class="px-6 lg:px-14 pb-16">
  <% if @recipes.any? %>
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
      <% @recipes.each do |recipe| %>
        <%= render "recipes/recipe_card", recipe: recipe %>
      <% end %>
    </div>
  <% else %>
    <div class="text-center py-16">
      <p class="font-serif italic text-2xl text-ink/70">No recipes shared yet.</p>
    </div>
  <% end %>
</section>

<%# Submit CTA strip %>
<section class="bg-linen px-6 lg:px-14 py-16">
  <div class="max-w-[720px] mx-auto text-center">
    <h2 class="font-serif text-3xl md:text-4xl text-ink mt-0">
      Have a Chris recipe? Send it in.
    </h2>
    <p class="text-[17px] text-ink/65 mt-3">Family recipes, favourite dishes, things he cooked for you.</p>
    <%= link_to "+ Submit a recipe", new_recipe_path,
          class: "inline-block mt-6 bg-moss text-cream rounded-full px-6 py-3 text-sm font-medium no-underline hover:bg-ink transition-colors" %>
  </div>
</section>
```

- [ ] **Step 5: Lightly rewrite `app/views/recipes/show.html.erb`**

Replace its contents with:

```erb
<% content_for :title, "#{@recipe.title} — Christopher Quentin" %>

<section class="px-6 lg:px-14 pt-12 pb-16 max-w-[860px] mx-auto">
  <%= musical_eyebrow("Recipe · #{l(@recipe.created_at.to_date, format: :memory)}") %>
  <h1 class="font-serif text-4xl md:text-5xl lg:text-[64px] font-normal leading-tight tracking-tight text-ink mt-3">
    <%= @recipe.title %>
  </h1>
  <p class="font-serif italic text-xl text-sage mt-4">from <%= @recipe.submitter_name %></p>

  <% if @recipe.photo.attached? %>
    <%= image_tag @recipe.photo, class: "w-full aspect-[16/9] object-cover rounded-md border border-ink/8 my-10" %>
  <% end %>

  <div class="grid grid-cols-1 lg:grid-cols-2 gap-12 mt-10">
    <div>
      <%= musical_eyebrow("Ingredients") %>
      <div class="font-serif text-[19px] leading-relaxed text-ink mt-4 whitespace-pre-line"><%= @recipe.ingredients %></div>
    </div>
    <div>
      <%= musical_eyebrow("Instructions") %>
      <div class="font-serif text-[19px] leading-relaxed text-ink mt-4 whitespace-pre-line"><%= @recipe.instructions %></div>
    </div>
  </div>

  <div class="mt-12">
    <%= link_to "← All recipes", recipes_path, class: "text-moss text-sm font-medium hover:underline no-underline" %>
  </div>
</section>
```

- [ ] **Step 6: Run tests**

```bash
bin/rails test test/integration/recipes_index_test.rb -v
```

Expected: 5 runs, all pass.

- [ ] **Step 7: Run full suite**

```bash
bin/rails test 2>&1 | tail -5
```

Expected: 210 runs.

- [ ] **Step 8: Commit**

```bash
git add app/views/recipes/ test/integration/recipes_index_test.rb
git commit -m "Phase 4: recipes index + show page redesign"
```

---

## Task 10: Final verification

**Files:** none (or fixups)

- [ ] **Step 1: Run the full suite**

```bash
bin/rails test 2>&1 | tail -10
```

Expected: 210 runs, 0 failures, 0 errors, 0 skips.

- [ ] **Step 2: Kill any lingering server, reset DB, start server**

```bash
lsof -ti:3000 | xargs kill 2>/dev/null
bin/rails db:reset 2>&1 | tail -5
bin/rails server &
SERVER_PID=$!
sleep 5
```

- [ ] **Step 3: HTTP smoke checks**

```bash
echo "=== HTTP status checks ===" && \
  for path in / /chris /tributes /trees /updates /recipes /timeline /style-guide; do
    code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000$path)
    echo "$path → $code"
  done

echo "=== Content checks ===" && \
  curl -s http://localhost:3000/chris    | grep -c "Op. II"
  curl -s http://localhost:3000/chris    | grep -c "Operas Conducted"
  curl -s http://localhost:3000/tributes | grep -c "Op. V"
  curl -s http://localhost:3000/tributes | grep -c "data-category-filter"
  curl -s http://localhost:3000/trees    | grep -c "Op. VI"
  curl -s http://localhost:3000/trees    | grep -c "data-tree-marker"
  curl -s http://localhost:3000/updates  | grep -c "Op. VII"
  curl -s http://localhost:3000/updates  | grep -c "Slippedisc"
  curl -s http://localhost:3000/recipes  | grep -c "Op. VIII"
```

Expected: all paths return 200. Each grep returns ≥1.

- [ ] **Step 4: Filter check**

```bash
curl -s "http://localhost:3000/tributes?category=musicians" | grep -c "musicians"
```

Expected: ≥1 (the active chip shows musicians text).

- [ ] **Step 5: Stop the server**

```bash
kill $SERVER_PID
sleep 1
```

- [ ] **Step 6: Final commit (only if fixups needed)**

If something needed adjustment:

```bash
git status
git add -A
git commit -m "Phase 4: verification fixups"
```

Otherwise skip.

- [ ] **Step 7: Phase 4 complete**

Every page is now in the Garden direction. The redesign is fully shipped end-to-end.

---

## Self-review notes (post-write)

- ✓ Every spec section maps to a task:
  - Biography → Task 5
  - Tributes → Task 6 (depends on Task 1 + Task 4)
  - Trees → Task 7
  - News & Press → Task 8 (depends on Task 2)
  - Recipes → Task 9
  - Repertoire data → Task 3 (used by Task 5)
  - Tribute filter → Task 1 (used by Task 6)
  - Shared tribute card → Task 4 (used by Task 6)

- ✓ Open questions from spec resolved with concrete defaults:
  - Recipe categories — skipped, not in design
  - Tree species — only `address`
  - Quick Facts — hardcoded sample content in `_quick_facts.html.erb`; family edits later
  - Press dates — hand-picked plausible dates in YAML; family refines
  - `/updates` vs `/news` — both routes still resolve to `pages#news`
  - Repertoire content — sample data in YAML; family refines

- ✓ No placeholders, TBDs, or "implement later" markers. Every step has executable code.

- ✓ Type/name consistency:
  - `Tribute.categories.keys` produces array of strings; `category_class` chip uses string comparison. Filter param is a string. Consistent.
  - `Repertoire.conducted` / `Repertoire.assisted` return arrays of `Repertoire::Group(composer:, works:)`. The `_repertoire_group` partial expects `composer` and `works` accessors. Consistent.
  - `PressItem` instances respond to `date`, `source`, `title`, `snippet`, `kind`, `url`, `year`. The `_press_item` partial uses all of these. Consistent.
  - `chip_class(active:)` helper from Phase 3 used in Task 6 (`_category_filter`). Verified present.
  - Routes: `tributes_path`, `new_tribute_path`, `trees_path`, `new_tree_path`, `map_path`, `recipes_path`, `new_recipe_path`, `news_path`, `chris_path` — all exist in current routes file.

- ✓ Each task ends with a single, focused commit.

Known scope risks:

- **Task 5 (Biography)** is largest by content volume — 5 paragraphs of bio prose, Quick Facts, two repertoire groups. Markup is straightforward but the partial is long.
- **Task 7 (Trees)** includes a full-bleed quote section with moss bg + staff_lines + 3 different content rows. Significant view markup but no new behaviors.
- **Tributes filter test for empty state** — the test deletes all `family`-category tributes between two requests. Make sure the second request is the one being asserted.
