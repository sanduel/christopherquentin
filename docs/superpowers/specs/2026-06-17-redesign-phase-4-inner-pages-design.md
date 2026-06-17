# Phase 4 — Garden redesign: Inner pages

**Status:** Draft, awaiting user review
**Author:** Claude (Opus 4.7)
**Date:** 2026-06-17
**Branch:** `worktree-feature+garden-redesign`
**Source brief:** `/tmp/chris-inspo/design_handoff_chris_memorial/directions/garden-pages.jsx` + handoff README
**Builds on:** Phase 1 (foundation), Phase 2 (homepage), Phase 3 (timeline + share)

## Scope

Rebuild the five remaining inner pages in the Garden direction:

1. **Biography** (`/chris`) — long-form bio + sticky sidebar with portrait + Quick Facts + Repertoire section.
2. **Tributes** (`/tributes`) — masonry of tribute quote cards with category filter chips + Share a tribute CTA.
3. **Trees** (`/trees`) — hero, stylized world-map placeholder with stat callout, inline "Add your tree" form, full-bleed quote section, "Other ways in" grid.
4. **News & Press** (`/updates`) — vertical year-grouped timeline of press items.
5. **Recipes** (`/recipes`) — 3×2 grid of recipe cards with submit CTA.

After Phase 4, every page on the site lives in the Garden direction. Old Stone/Blue markup is gone.

## Out of scope

- Admin UI redesign — the existing `admin/` layout stays.
- Recipe show page — Phase 4 redesigns the index; the show page is touched lightly (just enough to render correctly inside Garden chrome).
- Tributes show page — same.
- Trees show page — same.
- Interactive Leaflet map on `/trees` — that's at `/map`; the Trees page uses a stylized placeholder + a link to `/map`.
- Article-detail pages for press items — the handoff has external links only.
- Migrating recipes to support categories/tags — out of scope (handoff design doesn't require them on the card).

## Locked-in decisions (from brainstorm)

| Decision | Choice |
|---|---|
| Tribute filter | Add `category` enum to Tribute (Family/Colleagues/Musicians/Students/Friends). Backfill seeded tributes. |
| News & Press data | YAML config `config/press_items.yml` loaded into a `PressItem` PORO. No DB. |
| Repertoire data | YAML config `config/repertoire.yml` with two groups (conducted, assisted). Loaded into a `Repertoire` PORO. |
| Trees world map | Stylized placeholder div with positioned dot markers per published Tree. Real map stays at `/map`. |
| "Add your tree" form on Trees page | Single-step inline form (not the multi-step UI from prototype). Submits to existing `trees#create`. |
| Recipes | Existing model unchanged. Redesign index + lightly redesign show. |

## Page-by-page design

### 1. Biography (`/chris`)

The bio page becomes the "definitive" page about Chris — long-form prose + visual + facts + repertoire.

**Layout (desktop):**

Two-column grid `lg:grid-cols-[1.5fr_1fr] gap-14`. Mobile: single column.

**Left column — long-form bio:**

- `musical_eyebrow("Op. II · Biography", with_rule: true)` 
- Cormorant 80px h1: `Christopher McMullen-Laird`
- Italic sage tagline: `Conductor · environmentalist · beloved`
- 5 paragraphs of bio prose (using existing content from `app/views/pages/chris.html.erb` — Cormorant 19px body)
- Press blockquote with rose left-rule (same as homepage hero quote)

**Right column — sticky sidebar (`lg:sticky lg:top-24 self-start`):**

- Large portrait placeholder gradient (aspect ratio 4/5)
- Two smaller photo placeholders below in a 2-col grid
- "Quick Facts" `<dl>` (Cormorant headings, JetBrains Mono labels, DM Sans values):
  - Born — November 1984, Boston MA
  - Education — Royal College of Music · Dartmouth College
  - Music Director of — Jæren Symfoniorkester, 2019 — 2020
  - Started career at — Bayerische Staatsoper, Munich
  - Made Stavanger his home — 2019

**Repertoire section** (below the two-column grid, full-width, linen background):

- `musical_eyebrow("Op. IV · Repertoire")`
- Section heading: "What he conducted, and where he assisted."
- Two-column grid: `lg:grid-cols-2`
  - **Operas Conducted** — `RepertoireGroup` partial
  - **Operas Assisted** — same partial, different data
- Each `RepertoireGroup`:
  - Eyebrow heading
  - 2-column table: composer (Cormorant 19px italic) · work (DM Sans 15px)
  - Data from `Repertoire.conducted` / `Repertoire.assisted`

### 2. Tributes (`/tributes`)

3-column CSS masonry of tribute quote cards.

**Header:**

- `musical_eyebrow("Op. V · Tributes", with_rule: true)`
- Cormorant h1: `In their <em class="text-moss">own words</em>.`
- Subtitle: `<%= pluralize(Tribute.published.count, "tribute") %> from family, colleagues, students, and friends.`

**Filter chip row:**

- Sticky cream/blur strip (same as timeline's year filter).
- Chips: `All` + each Tribute category enum value (`Family`, `Colleagues`, `Musicians`, `Students`, `Friends`).
- Active chip styling: bg-moss text-cream (same as timeline).
- Clicking submits `GET /tributes?category=family` (Turbo navigation).

**Masonry:**

- CSS `columns-1 md:columns-2 lg:columns-3 gap-5` (CSS columns masonry, not a JS lib).
- Each card uses the same `_tribute_quote_card.html.erb` partial we already have on the homepage MVT V — reuse it.
- Some tributes (those with `photo.attached?`) render a photo slot at the top of the card; others are text-only. The partial handles both.

**CTA strip at bottom:**

- Linen background full-width strip.
- "Have a story you'd like to share?" + moss pill `+ Share a tribute` → `new_tribute_path`.

**Schema additions:**

- Migration: `add_column :tributes, :category, :integer, default: 4, null: false` (4 = friends — sensible default).
- Tribute model: `enum :category, { family: 0, colleagues: 1, musicians: 2, students: 3, friends: 4 }, prefix: :category`.
- Backfill: existing 4 seeded tributes mapped manually (Margaret Thompson → family; James Anderson → students; Sigrid Olsen → musicians; Anna Lee → students).
- Tribute form (`new.html.erb`) adds a category select. Out of scope for Phase 4 visual scope but required for the field to be populated on new submissions; update the existing form minimally.

**Empty filter case:** "No tributes in this category yet." + "Clear filter →".

### 3. Trees (`/trees`)

**Hero:**

- `musical_eyebrow("Op. VI · The Trees", with_rule: true)`
- Cormorant h1: `A living memorial in <em>nine countries</em>.`
- Italic sage tagline: `lento e sereno`
- Subtitle: "One tree per memory. Plant one in his honor."

**World map placeholder:**

- 500px tall, ink-on-cream styling.
- Background: subtle dotted-grid pattern + faint continent outlines (CSS-only — SVG inline).
- For each published Tree with lat/lng: a small radial-gradient circle marker positioned via percentage (`left: (lng+180)/360*100%`, `top: (90-lat)/180*100%`). Each marker has a `title` attribute with the tree's `name`.
- Top-right stat callout (white rounded card): `<%= Tree.published.sum(:tree_count) %> trees · <%= Tree.published.distinct.count(:address) %> cities · 9 countries` (cities count hand-derived; countries hardcoded since Tree model doesn't have country).
- Below the map: "View full map →" link → `/map` (the real interactive map).

**Two-column section — Add your tree:**

- Grid `lg:grid-cols-2 gap-14`.
- Left: inline form (using existing `trees#create` action):
  - `musical_eyebrow("Plant a tree")`
  - Cormorant h2: "Add a tree to the map."
  - Form fields: `name` (Your name), `email`, `address` (Location — handoff calls it "Species / Location" but Tree model doesn't have species), `story` (textarea). Optional `tree_count` defaulted to 1.
  - Moss pill submit: "Plant my tree →"
- Right: portrait placeholder (gradient) of "the first Chris tree" with mono caption.

**Full-bleed quote section** (moss background, faint staff lines overlay):

- `musical_eyebrow("Op. VI.ii · Why trees", with_rule: true)` — cream-tinted
- Large Cormorant italic pull quote in cream:
  > "He'd plant a tree before he'd write a letter. So we plant trees."
- Attribution: cream eyebrow `— McMullen family`

**"Other ways in" grid:**

- 3-card grid mirroring the homepage honor grid pattern.
- Cards: Adopt a Bee Hive (`new_bee_hive_path`), Share a Memory (`new_memory_path`), Support a Fund (`funds_path`).
- Uses the same `_honor_card`-style markup as the homepage but with adjusted bodies for context.

### 4. News & Press (`/updates`)

The page lists 12+ press mentions of Chris.

**Header:**

- `musical_eyebrow("Op. VII · News & Press", with_rule: true)`
- Cormorant h1: `In the <em class="text-moss">world's</em> own words.`
- Subtitle: `<%= PressItem.all.count %> mentions across <%= PressItem.years.count %> years.`

**Vertical timeline grouped by year:**

- For each year in descending order:
  - Left column (Cormorant 56px moss): the year, sticky-positioned to the top of its group.
  - Right column: list of press items for that year.
  - Each item is a 3-column row at desktop:
    - **Col 1**: mono date `Jun 15, 2020` + sage source `Slippedisc`
    - **Col 2**: Cormorant 22px title (linked to external URL, opens in new tab) + DM Sans snippet (15px sage)
    - **Col 3**: kind chip (`Obituary` / `Interview` / `Feature` / `Listing` — bg-linen text-moss eyebrow) + `Read →` link

**Data structure (`config/press_items.yml`):**

```yaml
- date: 2020-06-15
  source: Slippedisc
  title: "Tragic death of young US conductor, 36"
  snippet: "American conductor Christopher Quentin McMullen-Laird has died at 36, weeks after taking up his post in Norway."
  kind: obituary
  url: https://slippedisc.com/2020/06/tragic-death-of-young-us-conductor-36/

- date: 2020-06-30
  source: Royal College of Music
  title: "In memoriam — Summer 2020"
  snippet: "Faculty and alumni remember Chris and his impact at RCM."
  kind: obituary
  url: https://www.rcm.ac.uk/upbeat/articles/inmemorysummer2020.aspx

# … one entry per existing news_links item, dates inferred from the URL paths or set to "undated" for items without a date
```

**PressItem PORO** (`app/models/press_item.rb`):

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
    @all ||= YAML.load_file(Rails.root.join("config/press_items.yml")).map { |a| new(a) }
  end

  def self.years
    all.map { |item| item.date&.year }.compact.uniq.sort.reverse
  end

  def self.grouped_by_year
    all.group_by { |item| item.date&.year }.sort_by { |year, _| -(year || 0) }
  end

  def year = date&.year
end
```

Loaded lazily, cached at class level. No `Rails.cache` invalidation needed — restart cycles the cache.

### 5. Recipes (`/recipes`)

3×2 grid of recipe cards.

**Header:**

- `musical_eyebrow("Op. VIII · Recipes", with_rule: true)`
- Cormorant h1: `What he <em class="text-moss">cooked</em>.`
- Subtitle: `<%= pluralize(Recipe.published.count, "recipe") %> from people who shared his kitchen.`

**Grid (`lg:grid-cols-3 gap-6`):**

- Each card:
  - Photo placeholder (gradient) OR real photo via `image_tag recipe.photo` if attached. Aspect 4/3.
  - Row of mono tags: a chip with `recipe.created_at` formatted (`Sep 2024`).
  - Cormorant 24px title (linked to `recipe_path`).
  - Italic sage attribution: `from <%= recipe.submitter_name %>`.
  - Body snippet (`truncate(recipe.ingredients, length: 100)` — the ingredients line gives a useful preview).
  - "Read the full recipe →" link (moss).

**Linen CTA below:**

- Linen background full-width strip.
- "Have a Chris recipe? Send it in." + moss pill `+ Submit a recipe` → `new_recipe_path`.

**Recipe show page (`recipes/show.html.erb`):**

Lightly restyled. Garden chrome wraps it (Phase 1 layout). Page body:

- `musical_eyebrow("recipe · #{l(recipe.created_at, format: :memory)}")`
- Cormorant 56px title
- Italic sage attribution
- Two columns desktop: ingredients (left, list) + instructions (right, prose).
- Photo at top if attached.

Full polish on the show page is a Phase-5 / content task. Goal here: doesn't look broken next to the redesigned index.

## Architecture

**New files (under `app/views/pages/chris/`, `app/views/tributes/`, etc.):**

```
app/views/pages/chris.html.erb          (rewritten)
app/views/pages/chris/
  _quick_facts.html.erb
  _repertoire_group.html.erb
  _repertoire_section.html.erb

app/views/tributes/
  index.html.erb                        (rewritten)
  _category_filter.html.erb
  # _tribute_quote_card.html.erb already exists at app/views/pages/home/
  # — Phase 4 promotes it to app/views/shared/ since it's used on both home + tributes.

app/views/trees/
  index.html.erb                        (rewritten)
  _world_map_placeholder.html.erb
  _add_tree_form.html.erb
  _other_ways_grid.html.erb

app/views/pages/news.html.erb           (rewritten)
app/views/pages/news/
  _press_item.html.erb
  _year_group.html.erb

app/views/recipes/
  index.html.erb                        (rewritten)
  show.html.erb                         (lightly rewritten)
  _recipe_card.html.erb

config/press_items.yml                  (new)
config/repertoire.yml                   (new)

app/models/press_item.rb                (new — PORO)
app/models/repertoire.rb                (new — PORO)
```

**Promoted partial:** `_tribute_quote_card.html.erb` moves from `app/views/pages/home/` to `app/views/shared/` so both the homepage MVT V and the new tributes index can render it. Phase 2's MVT V partial reference updates to `shared/tribute_quote_card`.

**Schema changes:**

- Migration: `add_column :tributes, :category, :integer, default: 4, null: false; add_index :tributes, :category`. Backfill via a second migration that maps the 4 seeded tributes by name.

## Controller changes

- `TributesController#index` — accept `?category=family` param, filter `@tributes` accordingly.
- `TreesController#index` — same as today but supply `@published_trees` for the map placeholder + `@new_tree = Tree.new` for the inline form.
- `PagesController#news` — loads `@years = PressItem.years; @items_by_year = PressItem.grouped_by_year`.
- `RecipesController#index` — already loads `@recipes` (probably). Verify.

## Tests

- **Biography:** integration test asserts h1 present, repertoire section renders with both groups, Quick Facts list present.
- **Tributes:** integration test asserts filter chips, category filtering works (?category=musicians shows only Musicians), masonry renders, Share a tribute CTA present.
- **Trees:** asserts map placeholder, stat callout, inline form posts to trees_path, Other ways grid present.
- **News:** asserts year grouping, each item renders date/source/title/kind chip/Read link.
- **Recipes:** asserts 3-col grid, each card has photo (gradient or attached), title, attribution, Read link.

Total target: ~20 new tests on top of Phase 3's 173.

## Definition of done

- Migration `add_column :tributes, :category` + backfill runs forward + backward cleanly.
- `/chris`, `/tributes`, `/trees`, `/updates`, `/recipes` all render the Garden direction.
- Tributes filter works (`?category=…`).
- Press items load from YAML.
- Repertoire loads from YAML.
- Existing 173 tests still pass, ~20 new tests added.
- Old Stone/Blue markup is gone from every redesigned page.
- Visual check at 1440 / 1024 / 768 / 375 px for each page.
- No JS console errors.

## Open questions

1. **Recipe categories/tags** — handoff design doesn't actually show them on the card. Skipping. If wanted later, add `tag` enum to Recipe.
2. **Tree species/genus field** — handoff says "Species / Location" but Tree model has only `address`. Skipping species. The Trees inline form just has location.
3. **Quick Facts content** — the spec gives 5 illustrative facts. The actual content needs Chris's family's input. Hardcoded with sample content for Phase 4; family edits the partial later.
4. **Press item dates** — many of the current 12 links don't have visible dates in their URLs. For Phase 4, dates are best-guess from URL paths or content. The YAML is hand-edited; family can refine later.
5. **`/updates` vs `/news`** — current routes: `get "news"` and `get "updates"` both point to `pages#news`. Keep both. Header uses Op. VII naming regardless.
6. **Repertoire content** — handoff is suggestive (Operas Conducted: Mozart Don Giovanni, etc.). For Phase 4, seed with a realistic set drawn from Chris's actual repertoire (bio mentions Beethoven, Mahler, Mozart) — family edits the YAML later.
