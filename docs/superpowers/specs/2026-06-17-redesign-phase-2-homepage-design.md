# Phase 2 — Garden redesign: Homepage

**Status:** Draft, awaiting user review
**Author:** Claude (Opus 4.7)
**Date:** 2026-06-17
**Branch:** `worktree-feature+garden-redesign`
**Source brief:** `/tmp/chris-inspo/design_handoff_chris_memorial/directions/garden-home.jsx`
**Spec it builds on:** `2026-05-24-redesign-phase-1-foundation-design.md`

## Scope

Replace `app/views/pages/home.html.erb` end-to-end with the Garden direction homepage. The page sits inside the chrome already shipped in Phase 1 (sticky nav + ink footer); this phase fills in the body — six sections, top to bottom:

1. **Hero** — name display + tagline + press blockquote + 2 CTAs + portrait placeholder.
2. **MVT. I — Honor his memory** — 4-card grid (Plant / Share / Adopt / Support).
3. **MVT. II — From the timeline** — 3 preview cards drawn from `Memory.published`.
4. **MVT. III — Upcoming gatherings** — 3 event cards from `Event.published.upcoming`.
5. **MVT. IV — In photographs** — varied-height gallery grid from `GalleryPhoto`.
6. **MVT. V — In their own words** — 3 tribute quote cards from `Tribute.published`.

The nav and footer (Phase 1) already render through `application.html.erb` — they are not re-touched here.

## Out of scope

- Timeline page redesign (Phase 3).
- Share-a-memory modal (Phase 3).
- Audio variant of memory cards (Phase 3 — depends on a schema change to Memory).
- Real photo content — placeholder gradients ship in Phase 2. A separate content task replaces them with `GalleryPhoto` records or images after Phases 2-4 land.
- Repertoire-section anchor links in the hero (the `chris_path#repertoire` jump targets — Phase 4 rebuilds the Chris page and adds them).
- Mobile drawer animation (Phase 2 keeps the basic stacked-list from Phase 1).
- Any model or schema change.

## Decisions locked in

| Decision | Choice | Why |
|---|---|---|
| Hero photos | Placeholder gradients with `[ portrait — Stavanger 2019 ]` mono caption | Family photo curation is its own content task; the design intentionally supports this look. |
| Memory type detection | Infer at render time: photos attached → photo card variant; otherwise → text variant | The current `Memory` schema has no `kind` field. Audio is Phase 3. |
| Copy | Use handoff copy verbatim (Jærbladet quote, "Conductor · environmentalist · beloved", action card paragraphs, section headings) | A content pass after Phases 2-4 will revise. |
| Tribute count | Dynamic from `Tribute.published.count` | "Read all N tributes →" must not lie. |
| Empty-data handling | Each section degrades gracefully: shows as many cards as exist; hidden entirely if 0 | Memorial site, not a CMS — never show "no data" warnings to visitors. |
| Seeds | Expand `db/seeds.rb` to add 3+ published memories, 3 upcoming events, 12 gallery photos (with placeholder ActiveStorage attachments), 3+ tributes | The page should render fully in dev/test from `bin/rails db:prepare`. |

## Section-by-section design

Each section is a partial under `app/views/pages/home/` (a new sub-directory) so the `home.html.erb` index reads as a manifest:

```erb
<%= render "pages/home/hero" %>
<%= render "pages/home/honor_grid" %>
<%= render "pages/home/timeline_preview", memories: @timeline_preview_memories %>
<%= render "pages/home/events_preview", events: @upcoming_events %>
<%= render "pages/home/gallery_preview", photos: @gallery_photos %>
<%= render "pages/home/tributes_preview", tributes: @recent_tributes, total_count: @tributes_count %>
```

`PagesController#home` populates the locals.

### Hero

Two-column grid (`lg:grid-cols-[1.15fr_1fr]` on desktop, single column on mobile). 88px vertical padding. Min-height 720 desktop / unconstrained mobile.

**Left column (relative, z-2):**

- Eyebrow row: `<%= musical_eyebrow("Op. 1984 — In Memoriam", with_rule: true) %>` (the `with_rule` style — short sage line then text).
- H1: three lines, Cormorant Garamond 96px desktop / 56px mobile, 0.93 line-height, -0.025em letter-spacing, ink color. Markup:
  ```
  Christopher
  <span class="font-serif italic text-moss">Quentin</span>
  McMullen-Laird
  ```
- Tagline: Cormorant italic 24px (smaller on mobile), sage color, ~28px top margin: `Conductor · environmentalist · beloved` (mid-dot separators with non-breaking spaces).
- Press blockquote: 2px rose left-rule, italic Cormorant 22px, max-width 540px, 40px top margin. Footer line in mono uppercase sage 13px: `— Jærbladet`.
- CTA row, 44px top margin, 16px gap:
  - Filled moss pill: `Read his story →` → links to `chris_path`.
  - Outline ink pill: `+ Share a memory` → links to `new_memory_path`.

**Right column (relative):**

The portrait placeholder. 620px tall. Two rectangles:
1. Primary placeholder filling the column. Diagonal `linear-gradient(160deg, rgba(58,82,64,0.18), rgba(168,88,76,0.18))` + a 45° striped overlay at 8% opacity. Border-radius 6, shadow `0 30px 60px -28px rgba(28,38,32,0.35)`. Mono caption in bottom-left: `[ portrait — Stavanger 2019 ]`.
2. Secondary 200×240 linen block overlapped bottom-right (`right: -28px, bottom: -28px`), rotated 4deg, with its own caption `[ on the podium ]`.

**Staff-line texture:** behind both columns, via `<%= render "shared/staff_lines", top: 120, height: 120, opacity: 0.09 %>`. The hero section gets `class="relative"` so the staff lines absolute-position correctly.

**Mobile:** single column. Portrait placeholder stacks below the text. Min-height drops. Hero h1 scales to 56px. Staff lines hidden via `hidden lg:block` on the outer wrapper.

### MVT. I — Honor his memory

`<%= render "shared/movement_label", no: "MVT. I", title: "Honor his memory", marking: "andante con moto" %>`

4-card grid: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5`.

Each card is a `<%= link_to ... do %>` block to its destination. Card structure:

```
<article class="bg-white rounded-md border border-ink/8 shadow-card p-6 flex flex-col min-h-[280px]">
  <div class="font-serif text-3xl text-{accent} leading-none mb-1.5">{glyph}</div>
  <%= musical_eyebrow(label) %>
  <h3 class="font-serif text-3xl mt-2.5 leading-tight">{title}</h3>
  <p class="text-sm leading-relaxed text-ink/70 mt-3 flex-1">{body}</p>
  <span class="text-moss text-sm font-medium mt-4 group-hover:underline">{cta}</span>
</article>
```

Four cards, hardcoded:

| Glyph | Label | Title | Body | CTA | Destination | Accent |
|---|---|---|---|---|---|---|
| `❦` | I. Plant | Plant a Tree | "Add a tree to the living map of saplings planted in his memory across nine countries." | Plant a tree → | `new_tree_path` | text-moss |
| `¶` | II. Remember | Share a Memory | "A photo, a story, an audio clip — contribute to the timeline of his life." | Share a memory → | `new_memory_path` | text-rose |
| `♪` | III. Pollinate | Adopt a Bee Hive | "Register a hive on the unified map — pollinators were one of his loves." | Adopt a hive → | `new_bee_hive_path` | text-sage |
| `♭` | IV. Sustain | Support a Fund | "The Dartmouth Conducting Endowment and four other funds carry his work forward." | Contribute → | `funds_path` | text-moss |

The cards live in `_honor_grid.html.erb` as a single rendered list (no separate `_honor_card` partial — there are only 4, and they don't repeat outside this section).

### MVT. II — From the timeline

`linen` background. 96px vertical padding. Faint staff lines on top edge (`top: 0, height: 80, opacity: 0.06`).

Header row (flex-between, baseline):
- Left: eyebrow `MVT. II · from the timeline`, then h2 Cormorant 64px desktop "A life, kept by `<em class='text-moss'>many hands</em>`.", then a sub-paragraph in sage tone: `"<n> memories so far, from <m> decades and <c> cities. Browse them all, or add your own."` — where `n` is `Memory.published.count`. `m` and `c` are derived from `Memory.published` dates and locations (decade count from year, city count from `location`). If those are awkward to compute, fall back to a static line: `"A growing collection — browse it all, or add your own."`
- Right: outline moss pill `View full timeline →` → `memories_path`.

Card grid: `grid grid-cols-1 md:grid-cols-3 gap-5`. Up to 3 cards drawn from `Memory.published.order(created_at: :desc).limit(3)`.

`_preview_card.html.erb` (one partial, handles both variants):

```
<article class="bg-white rounded-md overflow-hidden border border-ink/8 shadow-card flex flex-col">
  <% if memory.photos.attached? %>
    <%# Photo top slot — 200px gradient placeholder until real photos %>
    <div class="h-[200px] relative" style="background: linear-gradient(135deg, rgba(90,122,94,0.2), rgba(58,82,64,0.3)), repeating-linear-gradient(45deg, rgba(90,122,94,0.08) 0 12px, transparent 12px 24px);">
      <div class="absolute bottom-4 left-4 text-eyebrow text-cream mix-blend-difference">
        [ photo · <%= memory.location %> ]
      </div>
    </div>
  <% end %>
  <div class="p-6 flex flex-col flex-1">
    <%= musical_eyebrow("#{l(memory.date, format: :memory)} · #{memory.location}") %>
    <p class="font-serif text-[19px] leading-snug text-ink mt-3 flex-1">
      <%= truncate(memory.content, length: 220) %>
    </p>
    <footer class="mt-4 pt-3.5 border-t border-ink/8 flex justify-between items-baseline">
      <div>
        <div class="text-sm font-medium"><%= memory.user&.name || "Anonymous" %></div>
        <div class="text-xs text-ink/55"><%= memory.user&.relationship_to_chris || "Friend" %></div>
      </div>
      <span class="text-eyebrow text-sage">
        <%= memory.photos.attached? ? "photograph" : "letter" %>
      </span>
    </footer>
  </div>
</article>
```

A few notes on this partial:
- `l(memory.date, format: :memory)` requires a date format defined in `config/locales/en.yml`. We add `memory: "%B %Y"` so dates render as "January 2014".
- `User#relationship_to_chris` doesn't currently exist. For Phase 2, fall back to a static `"Friend"` string when `user.relationship_to_chris` is missing. (Phase 3's Memory schema work adds the field.)
- Empty case: if `@timeline_preview_memories.empty?`, the section's card grid renders a single full-width invitation card: "Be the first to share a memory →" linking to `new_memory_path`. No 'no memories yet' phrasing.

### MVT. III — Upcoming gatherings

`<%= render "shared/movement_label", no: "MVT. III", title: "Upcoming gatherings", marking: "vivace" %>`

96px vertical padding. Cream background (default).

3-card grid `grid grid-cols-1 md:grid-cols-3 gap-5`. Each card from `@upcoming_events` (existing controller sets `Event.published.upcoming.with_attached_cover_image.limit(3)`).

**Schema notes (verified against `app/models/event.rb`):**

- Event has `enum :event_type, { webinar: 0, concert: 1 }`. Add `service: 2` to support the design's third category — no migration needed (integer column already exists).
- Event has `location` (not `venue`); the spec uses `event.location`.
- Event has a `DISPLAY_ZONES` constant: `[["America/New_York", "ET"], ["Europe/London", "London"], ["Europe/Berlin", "Berlin"]]`. The card renders one time row per zone via this constant.

`_event_card.html.erb` structure:

```
<article class="bg-white rounded-md border border-ink/8 p-6 relative">
  <span class="absolute top-5 right-5 px-2.5 py-1 rounded-full bg-linen text-moss text-eyebrow">
    <%= event.event_type.capitalize %>
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

The locale also needs an `event_time` format: `"%-l:%M %p %Z"` → e.g. `"3:00 PM EDT"`.

Empty case: if 0 events, the section is hidden entirely (`<% if events.any? %>` wrapper inside the partial).

### MVT. IV — In photographs

`linen` background. 96px vertical padding.

`<%= render "shared/movement_label", no: "MVT. IV", title: "In photographs", marking: "lento e sereno" %>`

Varied-height gallery grid. Pattern: `grid-cols-2 md:grid-cols-3 lg:grid-cols-4 gap-4`. Some cards span 2 rows (visual rhythm). For Phase 2:
- First 12 GalleryPhoto records (`@gallery_photos`).
- Each renders as a `<a href="#" class="block aspect-[4/5] ..." style="background: <gradient based on index>">` where the gradient is a deterministic placeholder based on the index modulo 4 (four gradient variations to break monotony).
- Every 4th card gets `row-span-2 aspect-[4/7]` to create the varied-height feel.

A small mono caption per card (using `photo.caption` if present, else `[ photo ]`).

Below the grid, a center-aligned link: `Submit a photo →` → `new_photo_submission_path`.

Empty case: if 0 photos, render the grid with 6 placeholder gradient blocks (no link target). Visual continuity matters more than data presence here.

### MVT. V — In their own words

`<%= render "shared/movement_label", no: "MVT. V", title: "In their own words", marking: "cantabile" %>`

3-card grid `grid grid-cols-1 md:grid-cols-3 gap-5`.

`_tribute_quote_card.html.erb`:

```
<blockquote class="bg-white rounded-md border border-ink/8 shadow-card p-7 relative">
  <span class="absolute -top-3 left-6 font-serif text-[80px] text-rose leading-none select-none" aria-hidden="true">"</span>
  <p class="font-serif text-[19px] italic leading-snug text-ink mt-6">
    <%= truncate(tribute.content, length: 240) %>
  </p>
  <footer class="mt-5 pt-3.5 border-t border-ink/8">
    <div class="text-sm font-medium text-ink">— <%= tribute.name %></div>
    <% if tribute.relationship.present? %>
      <div class="text-eyebrow text-sage mt-1"><%= tribute.relationship %></div>
    <% end %>
  </footer>
</blockquote>
```

Below, center-aligned link: `Read all <%= @tributes_count %> tributes →` (singular case "Read the one tribute →" if count is exactly 1).

Empty case: section hidden if 0 published tributes.

## Controller changes

Edit `PagesController#home` to set three new instance variables alongside the existing ones:

```ruby
def home
  @timeline_preview_memories = Memory.published.order(created_at: :desc).limit(3)
  @upcoming_events = Event.published.upcoming.with_attached_cover_image.limit(3)
  @gallery_photos = GalleryPhoto.all.limit(12)
  @recent_tributes = Tribute.published.order(created_at: :desc).limit(3)
  @tributes_count = Tribute.published.count
end
```

(Existing variables `@recent_tributes`, `@gallery_photos`, `@upcoming_events` are kept. Renaming `@recent_tributes` is unnecessary — the partial just uses what it's passed.)

## Seed data updates

Edit `db/seeds.rb` to make `bin/rails db:prepare` produce a renderable homepage:

- **Memories:** add 3 published memories with content (one with `photos.attached`, two text-only). Use placeholder content roughly aligned with the handoff sample data.
- **Events:** add 3 future events spanning the next 6 months. Categories: Webinar, Concert, Service. Use realistic-sounding titles + venues + times.
- **Gallery photos:** **skip** in seeds. `GalleryPhoto` validates `photo` presence, so seeding without files would require either disabling validation or attaching real image bytes. Phase 2's gallery section is designed to render placeholder gradients when `@gallery_photos.empty?` — that path actually exercises in dev. Real `GalleryPhoto` records can be uploaded via `/admin/gallery_photos` later; the homepage will pick them up automatically.
- **Tributes:** add 4 published tributes with realistic-sounding `name`, `relationship`, and `message`.

These additions are idempotent (use `find_or_create_by` keyed by a unique field) so re-running `db:seed` doesn't duplicate.

## Locale additions

`config/locales/en.yml` (create if absent):

```yaml
en:
  date:
    formats:
      memory: "%B %Y"               # e.g. "September 2002"
      event_date: "%A %b %-d, %Y"   # e.g. "Sunday Jun 14, 2026"
  time:
    formats:
      event_time: "%-l:%M %p %Z"    # e.g. "3:00 PM EDT"
```

## Architecture & file structure

```
app/views/pages/
├── home.html.erb                          (rewritten; thin manifest)
├── home/
│   ├── _hero.html.erb                     (new)
│   ├── _honor_grid.html.erb               (new)
│   ├── _timeline_preview.html.erb         (new)
│   ├── _preview_card.html.erb             (new; used by timeline_preview)
│   ├── _events_preview.html.erb           (new)
│   ├── _event_card.html.erb               (new; used by events_preview)
│   ├── _gallery_preview.html.erb          (new)
│   ├── _tributes_preview.html.erb         (new)
│   └── _tribute_quote_card.html.erb       (new; used by tributes_preview)
```

The reason these go under `pages/home/` rather than `shared/`: they're specific to the homepage layout. If the same card surfaces are needed on inner pages (Phase 4), they'll be promoted to `shared/` at that time.

## Testing strategy

**Integration test:** `test/integration/homepage_test.rb`:

- Visits `/`.
- Verifies hero renders: h1 contains "Christopher", "Quentin" (italic), "McMullen-Laird"; press blockquote with rose left border; both CTA pill links present.
- Verifies MVT. I honor grid: 4 cards with the right glyphs, titles, and link destinations.
- Verifies MVT. II timeline preview: header text + at least one card with a memory's content (assumes seeded data).
- Verifies MVT. III events preview: when events exist, 3 cards with category chips. When no events, section absent.
- Verifies MVT. IV gallery: ~12 image placeholders + "Submit a photo →" link.
- Verifies MVT. V tributes: 3 blockquote cards + correct "Read all N tributes →" pluralization.
- Verifies the staff_lines partial renders inside the hero (absolute positioned div with `staff-lines-bg` class).

**Existing test impacts:**

- `test/integration/public_pages_test.rb`:
  - `test "home page loads"` — asserts `assert_select "h1", /Christopher Quentin/`. The new hero has `Christopher` on one line, `Quentin` in italic on the next. The `h1` text content is `Christopher Quentin McMullen-Laird` (whitespace-collapsed). Test still passes — keep it.
  - `test "home page shows action library with tree, memory, bee hive, and fund CTAs"` — currently asserts `assert_select "section[aria-labelledby=?]", "action-library-heading"`. The new design changes this to a `MovementLabel`-headed section. The test will be updated to assert against the new section's structure (4 cards with correct destinations). Counts and link presence remain; markup changes.

## Definition of done

- `/` renders the six new sections in the new design.
- All seeds run cleanly via `bin/rails db:reset && bin/rails db:seed`.
- The page is visually sound at viewport widths 1440, 1024, 768, 375 — no horizontal overflow, no broken stacking.
- Sections degrade when empty (MVT II empty-state card, MVT III hidden, MVT IV placeholder fill, MVT V hidden).
- Full test suite: 93 (existing) + ~12-14 new homepage tests, all green.
- `/style-guide` still works (Phase 1 regression).
- Existing pages (`/chris`, `/timeline`, etc.) still render with the Phase 1 chrome — the homepage body change does not leak into other pages.

## Open questions

1. Event model fields — `category`, `time_zones`, `venue`. I'll inspect the model in the plan phase. If `category` isn't a field but `kind` is (an enum), the spec adapts.
2. Memory `user.relationship_to_chris` — doesn't exist. Phase 2 falls back to `"Friend"`. Phase 3's schema work adds the field; Phase 2's homepage view will automatically pick it up when the column exists. No spec deviation needed.
3. Whether the hero portrait placeholder should swap to a real `GalleryPhoto` if `GalleryPhoto.where(hero: true).first` exists — defaulting to no (Phase 2 is placeholder-only, content task handles photos).
4. Whether MVT. IV's "every 4th card spans 2 rows" rule should be data-driven (e.g., a `prominent` flag) or purely positional (every 4th by index). Defaulting to positional for Phase 2.
