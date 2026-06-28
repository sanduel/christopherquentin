# Biographical Milestones — Design

## Problem

The timeline (`/timeline`, `memories#index`) renders only **memories** — community
contributions that each carry a submitter (name / relationship / email), a moderation
status, a kind (text / photo / audio), replies, and a map pin, and which feed the
"N memories · M contributors" counts.

There is no way to place **objective biographical facts** on the timeline — events like
*"Born in Tokyo"*, *"Began studies at Dartmouth"*, *"Appointed to the Stavanger Symphony"*.
These are not someone's shared memory: they have no submitter, take no replies, and should
read as official anchors of his life rather than contributions. A birth in 1984 should
anchor the bottom of the timeline even though the earliest memory is from 2002.

## Solution Overview

Introduce a dedicated `Milestone` model — separate from `Memory` — and interleave
milestones into the existing year-grouped timeline with a visually distinct, centered
marker. Milestones are admin-authored only (no public submission, no moderation) and are
excluded from the memory and contributor counts.

### Why a separate model, not a flag on `Memory`

A `Memory` carries submitter fields, a `status` enum, a `kind` enum, `replies`, geocoding
via `Mappable`, and it drives the contributor/memory counts. A biographical fact shares
almost none of this. Adding a `biographical` flag to `Memory` would scatter
`unless biographical?` conditionals through the model validations, the card dispatcher, the
reply composer, the map, and the two counts. A small dedicated model keeps each concept
cohesive and independently testable. The cost — merging two collections into one
year-grouped timeline — is incurred once in the controller/view and is the same work either
way.

## Data Model

New table `milestones`:

| column        | type   | constraints      | purpose                                   |
|---------------|--------|------------------|-------------------------------------------|
| `date`        | date   | null: false      | sorts the milestone into the timeline     |
| `headline`    | string | null: false      | the fact, e.g. "Born in Tokyo"            |
| `description` | text   | nullable         | a sentence of context (optional)          |
| `icon`        | string | nullable         | rails_icons name for the distinct marker  |
| `location`    | string | nullable         | display-only place; **not** geocoded      |
| timestamps    |        |                  |                                           |

Index on `date` (timeline ordering).

### `Milestone` model

```ruby
class Milestone < ApplicationRecord
  validates :date,     presence: true
  validates :headline, presence: true

  scope :chronological, -> { order(:date) }

  def year = date.year
  def age  = year - Memory::CHRIS_BIRTH_YEAR
end
```

- **No** `Mappable` include — biographical facts do not get map pins. `location` is a plain
  display string.
- **No** `status` / moderation — admin-authored, always visible.
- **No** submitter fields, **no** `replies`.
- Reuses `Memory::CHRIS_BIRTH_YEAR` (1984) for the "he was N" age label, matching memories.

### Date precision (decision: full date, displayed year-level)

`date` is a real, required date used purely for **sorting**. Per the timeline's existing
design, items live under a large year marker, so a milestone does **not** render its own
day/month — it displays under its year. For a year-only fact (e.g. a birth where only the
year is known) the admin sets any in-year date (e.g. Jan 1); since the per-entry date is not
shown, no misleading "January 1" appears. Within a year, milestones and memories order by
`date` ascending. No `date_precision` flag (explicitly out of scope).

### Visibility (decision: always visible)

Every milestone shows on the timeline. To remove one, delete it. No `published` flag
(explicitly out of scope — YAGNI).

## Admin Management

A full admin CRUD resource mirroring `Admin::MemoriesController`, minus the
moderation/status machinery.

- **Route:** `namespace :admin { resources :milestones }` (all REST actions).
- **Controller:** `Admin::MilestonesController < Admin::BaseController` with
  index / new / create / edit / update / destroy. Strong params:
  `:date, :headline, :description, :icon, :location`.
- **Views:** `admin/milestones/{index,new,edit,_form}.html.erb`, following the styling of
  the existing admin memory views (stone palette, same form/list markup). The index lists
  milestones in chronological order with edit/delete actions. No moderation action partial,
  no status badge.
- **Navigation:** add a "Milestones" link to the admin sidebar
  (`layouts/admin.html.erb`) and a "Milestones" count tile to the admin dashboard
  (`admin/dashboard/index.html.erb`, showing total milestone count).

## Public Timeline Integration

`MemoriesController#load_timeline_locals` currently builds `@memories` (published,
year-descending) plus `@years`, `@memories_count`, `@contributors_count`. Changes:

1. Load milestones: `@milestones = Milestone.all` (year-filtered when `params[:year]`).
2. `@years` = union of memory years **and** milestone years, sorted descending. This makes
   a milestone anchor a year that has no memories (e.g. 1984 birth).
3. `@memories_count` and `@contributors_count` stay **memories-only** — milestones are facts,
   not contributions, and must not inflate either count.
4. Build a merged, year-grouped, date-ascending structure for rendering. A small helper
   produces, per year, a list of timeline items each tagged as `:memory` or `:milestone`:

   ```ruby
   # in the controller
   @timeline_by_year = build_timeline(@memories, @milestones)
   # => { 2019 => [<memory>, <milestone>, ...], ..., 1984 => [<milestone>] }
   # each year's items sorted by date asc; years iterated desc in the view
   ```

   (Exact shape finalized in the implementation plan; the view needs year → ordered items
   where each item knows whether it is a memory or a milestone.)

### View

`memories/index.html.erb` iterates years descending; within each year it renders the
existing `_year_marker`, then each item via either the existing `memories/_memory_card`
(memories, unchanged — alternating left/right cards) or a **new** `memories/_milestone`
partial.

`memories/_milestone.html.erb` — a **centered marker on the spine**, visually distinct from
memory cards:

- centered column on the vertical spine (not left/right alternating)
- optional `icon` (via rails_icons) at top
- `headline` in serif
- optional `description` in muted text
- optional `location` as a small mono/eyebrow line
- no card border/shadow, no footer, no submitter, no replies — reads as a fact

Empty-state and year-filter behavior unchanged. The homepage timeline-band preview
(`pages/home.html.erb`) stays **memories-only** — milestones do not appear there.

### Not in scope

- No public show page for milestones (they are brief; shown inline only). No
  `resources :milestones` public route.
- No map pins for milestones.
- No reordering UI beyond `date`.
- No `published`/draft flag, no `date_precision` flag.

## Testing

TDD — tests first, watch them fail, then implement.

- **Model** (`test/models/milestone_test.rb`): `date` required; `headline` required;
  `description` / `icon` / `location` optional; `year` and `age` compute correctly;
  `chronological` scope orders by date.
- **Admin CRUD** (`test/controllers/admin/milestones_controller_test.rb` or integration):
  index lists milestones; create with valid params persists and redirects; create with
  missing headline re-renders with error; update edits fields; destroy removes. Requires
  admin auth (mirror existing admin memory controller tests).
- **Timeline integration** (extend `test/integration/` timeline coverage):
  - a milestone renders on `/timeline` under its year with its headline
  - a milestone in a year with no memories still produces that year's marker (e.g. 1984)
  - milestones are **excluded** from `@memories_count` and `@contributors_count`
    (the header counts do not change when a milestone is added)
  - within a shared year, memory and milestone order by date

## Files

**New**
- `db/migrate/<ts>_create_milestones.rb`
- `app/models/milestone.rb`
- `app/controllers/admin/milestones_controller.rb`
- `app/views/admin/milestones/{index,new,edit,_form}.html.erb`
- `app/views/memories/_milestone.html.erb`
- `test/models/milestone_test.rb`
- admin + timeline tests

**Modified**
- `config/routes.rb` (admin milestones resource)
- `app/controllers/memories_controller.rb` (load + merge milestones; keep counts memories-only)
- `app/views/memories/index.html.erb` (render merged timeline items)
- `app/views/layouts/admin.html.erb` (sidebar link)
- `app/views/admin/dashboard/index.html.erb` (count tile)
- `app/controllers/admin/dashboard_controller.rb` (milestone count, if dashboard counts are set there)
- `db/seeds.rb` (optional: a couple of sample milestones for development)
