# Phase 1 — Garden redesign foundation

**Status:** Draft, awaiting user review
**Author:** Claude (Opus 4.7)
**Date:** 2026-05-24
**Branch:** `worktree-feature+garden-redesign`
**Source brief:** `/tmp/chris-inspo/design_handoff_chris_memorial/README.md` (Garden direction)

## Why this is Phase 1

The full redesign covers 8 screens (homepage, timeline, share modal, biography, tributes, trees, news, recipes). Trying to spec all of them in one document produces a doc nobody can hold in their head, and forces every later screen to wait on details that don't matter to it yet. Phase 1 builds only the foundation every later screen will sit on:

1. The design tokens (colors, type, spacing) that every screen consumes.
2. The font wiring (Cormorant Garamond, DM Sans, JetBrains Mono).
3. The base layout shell (cream body, ink text, DM Sans default, page padding).
4. The shared chrome partials: top nav, footer, movement label, staff-lines texture.
5. A style guide page proving the system works end-to-end.

Pages do **not** get rebuilt in this phase. Existing pages (homepage, biography, etc.) keep their current Stone/Blue styling and Josefin Sans font, layered under the new layout. That's intentional — Phase 1 lands without making any page look broken. The redesigned pages come in Phases 2-4, each rebuilt against the system this phase defines.

## Scope summary

| In | Out |
|---|---|
| Design tokens via Tailwind v4 `@theme` | Page-level redesigns |
| Google Fonts wiring | Memory schema changes |
| Layout shell (`application.html.erb`) | Admin layout (kept as-is) |
| Shared partials: nav, footer, movement label, staff lines | wavesurfer.js / audio |
| `musical_eyebrow` / `mono_meta` helpers | World map redesign |
| Style guide page at `/style-guide` (dev-only) | Mobile nav drawer — done in Phase 2 |
| Mobile responsive breakpoints baked into tokens | |
| Removing Josefin Sans + old Stone palette from base | |

## Approach

**Recommended:** Tailwind v4 `@theme` block with CSS variables + plain Rails partials under `app/views/shared/`. No new gems, no new build steps, no ViewComponent. The existing app uses partials; we stay consistent.

**Considered alternatives:**

- **ViewComponent** — would give type-safe props and isolated component tests. Adds a gem, a different mental model, and a `lib/components/` tree the existing codebase doesn't have. Solo+AI workflow doesn't benefit enough to justify the overhead. Skip.
- **Stimulus-only nav + footer** — overkill; the chrome is mostly static markup. Stimulus is reserved for actual interactions (mobile menu toggle, modal, year filter).

## Design tokens

### Palette (Tailwind v4 `@theme`)

```css
@theme {
  --color-cream: #faf6ee;
  --color-linen: #f1ebde;
  --color-ink:   #1c2620;
  --color-sage:  #5a7a5e;
  --color-moss:  #3a5240;
  --color-rose:  #a8584c;
}
```

Generates `bg-cream`, `text-ink`, `border-sage`, etc., automatically. Pulling from these six only — no other hues introduced. The existing `--font-title: "Josefin Sans"` token is removed.

### Typography

```css
@theme {
  --font-serif: "Cormorant Garamond", ui-serif, Georgia, serif;
  --font-sans:  "DM Sans", system-ui, -apple-system, sans-serif;
  --font-mono:  "JetBrains Mono", ui-monospace, "SF Mono", monospace;
}
```

Tailwind v4 wires these to `font-serif`, `font-sans`, `font-mono`. **Body default** changes from `font-sans` (current Tailwind default, system) to DM Sans by setting `font-sans` on `<body>` in the layout.

**Type scale (handoff spec, exposed as utilities):**

- Display hero: ~96–120px on desktop, scales down on mobile. `text-display` custom utility.
- Section heading (movement title): ~56–64px → `text-movement`.
- Card heading: ~24–30px → existing `text-2xl`/`text-3xl` plus a font-serif preset.
- Body (emotional): 17–22px Cormorant → `text-prose` utility.
- UI body: 14–17px DM Sans → default `text-sm`/`text-base`.
- Eyebrow/mono metadata: 10–11px JetBrains Mono uppercase 0.18–0.24em letter-spacing → `text-eyebrow` utility class defined in `application.css` since Tailwind doesn't have built-in letter-spacing token for this exact case.

### Spacing & shape tokens

```css
@theme {
  --radius-card: 6px;
  --radius-pill: 9999px;

  /* Page padding: 56px desktop, 24px mobile */
  --page-padding-inline: 56px;
}
```

Used directly in utilities (`rounded-[var(--radius-card)]`) when needed. Most Tailwind shape utilities map fine: `rounded-md` ≈ 6px, `rounded-full` for pills.

**Custom shadow:** the handoff specifies `0 1px 0 rgba(28,38,32,0.03), 0 20px 40px -28px rgba(28,38,32,0.18)` for cards. Add as `--shadow-card` token, expose as `shadow-card`.

### Responsive plan

Desktop-first since the prototype is 1280px. Two breakpoints worth honoring:

- `md:` (≥768px) — tablet. Inner pages reflow card grids to 2 columns where the prototype shows 3-4. Hero becomes single column.
- Default (mobile) — single column. Page padding `px-6` instead of `px-14`. Hero text scales from 120px to ~56px. Nav collapses to a hamburger (drawer-style menu — Phase 2 implements behavior; Phase 1 just hides the desktop nav and shows a placeholder hamburger).

Tablet+ uses `lg:px-14` for the 56px page padding; mobile uses `px-6`. The handoff says 56px is constant — but only on desktop, so this is consistent.

## Fonts

Loaded via Google Fonts `<link>` tag in `<head>` (same pattern as the current Josefin Sans). All three families in one request to minimize round-trips:

```
https://fonts.googleapis.com/css2
  ?family=Cormorant+Garamond:ital,wght@0,400;0,500;1,400;1,500
  &family=DM+Sans:wght@400;500;600
  &family=JetBrains+Mono:wght@400;500
  &display=swap
```

`preconnect` to googleapis.com and gstatic.com is already in the layout — keep it.

**Performance:** ~85KB of woff2 across the three families. Acceptable for a content-heavy memorial site. If lighthouse scores demand, we can self-host the subset later (out of scope for Phase 1).

## Layout shell — `app/views/layouts/application.html.erb`

Significantly rewritten. New responsibilities:

1. Set `<body>` to `bg-cream text-ink font-sans flex flex-col min-h-full`. Drop the old `bg-stone-50 text-stone-800` classes.
2. Drop the old utility bar (sign-in row above the header). Sign-in/admin links move into the new nav (right-side, smaller, after the Share-a-memory CTA).
3. Drop the old header markup entirely — replaced by `render "shared/home_nav"`.
4. Drop the old footer markup entirely — replaced by `render "shared/site_footer"`.
5. Keep `<%= yield :head %>`, csrf/csp meta, importmap tags, stylesheet link, flash messages, `<%= yield %>` main.
6. Flash messages restyled — green-50/red-50 boxes → `bg-linen text-moss` (notice) and `bg-linen text-rose` (alert) with rose/moss left border at 2px. Stay above main content, page-padded.

## Shared partials

All under `app/views/shared/`.

### `_home_nav.html.erb`

The sticky cream/blur nav from the handoff.

Structure:
- `<nav class="sticky top-0 z-50 bg-cream/90 backdrop-blur-[10px] border-b border-ink/8 lg:px-14 px-6 py-[22px] flex items-center justify-between font-sans">`
- Left: `Christopher Quentin` wordmark in Cormorant 22px + `1984 — 2020` mono date.
- Right (desktop, `hidden md:flex`): Biography / Memories / Trees / Projects / Funds links + Share-a-memory pill CTA (`bg-moss text-cream`).
- Sign-in / Admin / Sign-out links appear after the CTA, smaller (text-xs, text-ink/60), separated by an `aria-hidden` dot.
- Right (mobile, `md:hidden`): hamburger button. Phase 1 ships a working stacked-list drawer (existing `nav_controller.js` already toggles a `data-nav-target="menu"` element via `hidden` class — markup rebuilt with new links/styling, controller kept). Phase 2 upgrades to a slide-in animated drawer with focus-trap.
- Active link styling: rendered via `nav_link(label, path)` helper (see View helpers) — sets `aria-current="page"` and `font-medium text-moss` when `current_page?(path)`.

### `_site_footer.html.erb`

The dark ink footer with staff-line overlay.

Structure:
- `<footer class="bg-ink text-cream lg:px-14 px-6 pt-18 pb-10 relative">`
- Absolute-positioned div with the staff-lines repeating-gradient at opacity-6%, top-0 height-24, pointer-events-none.
- Grid `lg:grid-cols-[1.4fr_1fr_1fr_1fr] gap-10`:
  - Col 1: Coda eyebrow + Cormorant 36px heading "Stay in touch…" + newsletter form (existing `newsletter_subscribers` action).
  - Cols 2-4: `FootCol` partial: Christopher / Honor / More link groups.
- Bottom row: `flex justify-between items-center mt-14 pt-6 border-t border-cream/12 text-sm opacity-65`. Left: `© 2026 Christopher Quentin Memorial`. Right: italic Cormorant `1984 — 2020 ♪ fine.`

### `_foot_col.html.erb`

Small helper partial rendered three times by the footer. Takes `title:` and `items:` (array of `[label, path]` pairs).

### `_movement_label.html.erb`

The MVT. N — title — tempo marking row used at the top of each section on the homepage (and elsewhere).

Takes locals: `no:` (e.g. "MVT. I"), `title:` (e.g. "Honor his memory"), `marking:` (e.g. "andante con moto").

Structure: flex row, baseline aligned, gap-6. Mono eyebrow (sage 11px 0.22em), Cormorant 56px h2 (ink), italic Cormorant 22px (rose) prefixed with em-dash.

Mobile: stacks vertically, h2 scales to 36px.

### `_staff_lines.html.erb`

The faint horizontal-rule wallpaper. Takes locals: `top:` (px), `opacity:` (0–1, default 0.07), `height:` (px, default 120).

Renders an absolutely-positioned `<div>` with the repeating-linear-gradient backgroundImage. Used as a child of a `relative` parent.

Phase 1 ships this partial but the only place it renders is the style guide. Phases 2–4 layer it into hero + section dividers.

## View helpers

### `app/helpers/musical_helper.rb`

```ruby
module MusicalHelper
  # Renders the mono uppercase eyebrow label.
  # Usage: <%= musical_eyebrow("Op. 1984 — In Memoriam") %>
  def musical_eyebrow(text, with_rule: false)
    rule = with_rule ? content_tag(:span, "", class: "inline-block w-7 h-px bg-sage mr-3.5 align-middle") : ""
    content_tag(:div,
      raw(rule + ERB::Util.h(text)),
      class: "font-mono text-[11px] tracking-[0.22em] uppercase text-sage flex items-center"
    )
  end

  # Renders an italic Cormorant tempo-marking glyph.
  # Usage: <%= tempo_marking("andante con moto") %>
  def tempo_marking(text)
    content_tag(:span, "— #{text}", class: "font-serif italic text-[22px] text-rose")
  end
end
```

Auto-included in all views (Rails default for `app/helpers/`).

### `app/helpers/nav_helper.rb`

```ruby
module NavHelper
  # Wraps link_to to add aria-current="page" and a moss-medium active style
  # when the current request URL matches the target path.
  def nav_link(label, path, extra_class: "")
    active = current_page?(path)
    classes = ["text-ink hover:text-moss transition-colors", extra_class]
    classes << "font-medium text-moss" if active
    link_to label, path,
      class: classes.compact.join(" "),
      "aria-current": (active ? "page" : nil)
  end
end
```

Used by `_home_nav.html.erb` for every nav link.

### Footer link items (referenced by `_foot_col.html.erb` calls)

Three columns, fixed per handoff spec:

- **Christopher**: Biography (`chris_path`), Repertoire (`chris_path` — same page, anchor `#repertoire`), Press (`updates_path`), Discography (`updates_path` — anchor `#discography`).
- **Honor**: Plant a tree (`new_tree_path`), Share a memory (`new_memory_path`), Adopt a hive (`new_bee_hive_path`), Funds (`funds_path`).
- **More**: Submit photos (`new_photo_submission_path`), Order the book (external Fillout URL `https://christopherquentin.fillout.com/book` — already used by current footer), Share a tribute (`new_tribute_path`), Sign in (`new_user_session_path` when signed out; renders as Admin/Sign out group when signed in).

## Style guide page

`GET /style-guide` (dev/test-only — guarded by `Rails.env.development? || Rails.env.test?`).

Route: `get "style-guide", to: "pages#style_guide", as: :style_guide`.

Page proves every token, font, helper, and partial renders correctly. Sections: Palette swatches, Type specimens, Eyebrow + tempo marking, MovementLabel three variants, StaffLines preview, Button styles (moss pill, outline pill, text link), Card preview, Footer preview.

Purpose: regression catch for Phase 1, plus a reference page for Phases 2–4. Not linked publicly; you visit it directly when working on a screen.

## What gets deleted / modified

- `app/assets/tailwind/application.css` — replace `--font-title: "Josefin Sans"` with the new tokens above. Keep the existing `.map-pin` rules.
- `app/views/layouts/application.html.erb` — rewritten per "Layout shell" above.
- `app/javascript/controllers/nav_controller.js` — updated to match new mobile drawer markup (the toggle target ID changes from `menu` to `drawer`).
- Existing pages (`pages#home`, `pages#chris`, etc.) — **untouched** in Phase 1. They will look mismatched (blue/stone content inside cream chrome). That's intentional and gets fixed in Phase 2.

## Testing strategy

Per TDD discipline: write tests first, watch fail, implement.

- **Integration test:** `test/integration/site_layout_test.rb` — visits `/`, asserts the new nav renders with `Christopher Quentin` wordmark, the Share-a-memory CTA links to `new_memory_path`, the footer renders the newsletter form pointing at `newsletter_subscribers_path`, the body has `bg-cream` class.
- **Helper test:** `test/helpers/musical_helper_test.rb` — `musical_eyebrow` renders the right classes; `tempo_marking` renders italic + rose.
- **Style guide route test:** `test/integration/style_guide_test.rb` — `/style-guide` returns 200 in development/test. Returns 404 in production.
- **Visual verification:** start `bin/rails server`, view `/style-guide`, view `/` (homepage will look broken in body but nav+footer match the design).

## Open questions

None blocking Phase 1.

- Memory model schema (current model is missing handoff fields like `age`, `type`, `audio_url`, etc.) — surfaces in **Phase 3** when timeline + share are spec'd. Not relevant here.
- Whether `Order Memorial Book` external link (current footer) stays in new footer — defaulting to yes, under the "More" column.
- Whether `/style-guide` should be admin-only in production — defaulting to dev/test-only, which is simpler. Can promote later if useful.
- Handoff footer "More" column lists `Contact` as a link; the current Rails app has no contact route or address. Replaced with `Share a tribute` in this spec. If you want a real Contact entry, supply an email/address (or confirm dropping it).

## Definition of done

- All tokens in `@theme` block.
- Fonts load on every page.
- New nav + footer render on every page (visit `/` and any other page to confirm).
- `/style-guide` renders all components correctly in dev.
- 68 baseline tests still pass + ~3-5 new tests added for Phase 1.
- Manually verified at viewport widths: 1440px, 1024px, 768px, 375px.
- `bin/rails server` boots, no console errors.
