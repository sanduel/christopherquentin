# Phase 1: Foundation + Design System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Land the Garden redesign foundation — design tokens, fonts, layout shell, shared chrome partials, view helpers, and a dev-only style-guide page — without modifying any existing page body.

**Architecture:** Tailwind v4 `@theme` CSS-variable tokens (palette + type + spacing); plain Rails partials under `app/views/shared/` for chrome (no ViewComponent); two helper modules (`MusicalHelper`, `NavHelper`) auto-included via `app/helpers/`; replace `application.html.erb` to use the new chrome; add a guarded `/style-guide` route for component verification. All in TDD discipline — failing test first, watch fail, minimal code to pass.

**Tech Stack:** Rails 8.1.2, Tailwind v4 (via `tailwindcss-rails` 4.4.0), Stimulus 3 (via `@hotwired/stimulus` on importmap), Minitest, Google Fonts (Cormorant Garamond, DM Sans, JetBrains Mono).

**Spec:** `docs/superpowers/specs/2026-05-24-redesign-phase-1-foundation-design.md`

---

## Files touched in this phase

**Created:**
- `app/views/shared/_home_nav.html.erb` — sticky cream/blur top nav
- `app/views/shared/_site_footer.html.erb` — dark ink footer with staff-line texture
- `app/views/shared/_foot_col.html.erb` — small reusable footer column
- `app/views/shared/_movement_label.html.erb` — MVT. N — title — tempo marking row
- `app/views/shared/_staff_lines.html.erb` — faint horizontal-rule wallpaper overlay
- `app/helpers/musical_helper.rb` — `musical_eyebrow`, `tempo_marking`
- `app/helpers/nav_helper.rb` — `nav_link`
- `app/views/pages/style_guide.html.erb` — dev-only style guide
- `test/helpers/musical_helper_test.rb`
- `test/helpers/nav_helper_test.rb`
- `test/integration/site_layout_test.rb`
- `test/integration/style_guide_test.rb`

**Modified:**
- `app/assets/tailwind/application.css` — new tokens, drop `font-title`
- `app/views/layouts/application.html.erb` — rewritten layout shell
- `app/javascript/controllers/nav_controller.js` — kept; just confirm target name stays `menu`
- `config/routes.rb` — add `style-guide` route guarded by env
- `app/controllers/pages_controller.rb` — add `style_guide` action

**Not touched (deliberately):**
- Any page body (`pages#home`, `pages#chris`, `pages#projects`, etc.). They will look mismatched until Phase 2+.
- Admin layout / admin views.
- Devise views (their styling will be revisited later).
- Any model or schema.

---

## Task 1: Design tokens in Tailwind

**Files:**
- Modify: `app/assets/tailwind/application.css`

This is a CSS-only change. Not TDD-able directly (no behavior to assert) — but downstream tasks depend on the `bg-cream`, `text-ink`, `font-serif` etc. utilities working, so any failure will surface in Task 4+.

- [ ] **Step 1: Read the current file**

Already a small file. Confirm contents:

```bash
cat app/assets/tailwind/application.css
```

Expected: `@import "tailwindcss";`, `@theme { --font-title: "Josefin Sans", sans-serif; }`, and the `.map-pin` rules.

- [ ] **Step 2: Replace the file with new tokens**

Overwrite `app/assets/tailwind/application.css` with:

```css
@import "tailwindcss";

@theme {
  /* Garden palette */
  --color-cream: #faf6ee;
  --color-linen: #f1ebde;
  --color-ink:   #1c2620;
  --color-sage:  #5a7a5e;
  --color-moss:  #3a5240;
  --color-rose:  #a8584c;

  /* Type families */
  --font-serif: "Cormorant Garamond", ui-serif, Georgia, serif;
  --font-sans:  "DM Sans", system-ui, -apple-system, sans-serif;
  --font-mono:  "JetBrains Mono", ui-monospace, "SF Mono", monospace;

  /* Card shadow */
  --shadow-card: 0 1px 0 rgba(28,38,32,0.03), 0 20px 40px -28px rgba(28,38,32,0.18);
}

/* Eyebrow — small mono uppercase label used for opus numbers, movement
   markers, and metadata. Tailwind has no preset that captures the
   exact letter-spacing convention, so we define one utility. */
@utility text-eyebrow {
  font-family: var(--font-mono);
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.22em;
  color: var(--color-sage);
}

/* Faint horizontal-rule "staff lines" texture, used in hero + section
   dividers. Apply to an absolutely-positioned child element. */
@utility staff-lines-bg {
  background-image: repeating-linear-gradient(
    to bottom,
    transparent 0,
    transparent 17px,
    var(--color-moss) 17px,
    var(--color-moss) 18px,
    transparent 18px,
    transparent 35px
  );
}

/* Map pin (Leaflet divIcon) — kept from prior styles */
.map-pin-wrapper { background: transparent; border: none; }
.map-pin {
  width: 32px;
  height: 32px;
  border-radius: 50% 50% 50% 0;
  transform: rotate(-45deg);
  border: 2px solid white;
  box-shadow: 0 2px 6px rgba(0,0,0,0.3);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
}
.map-pin svg { width: 16px; height: 16px; transform: rotate(45deg); stroke: currentColor; }
```

- [ ] **Step 3: Compile and verify**

Run:

```bash
bin/rails tailwindcss:build
```

Expected output: `≈ tailwindcss v4.1.18` then `Done in ~150ms`. No errors.

- [ ] **Step 4: Confirm the build produced the expected CSS**

Run:

```bash
grep -E "(--color-cream|--font-serif|text-eyebrow|staff-lines-bg)" app/assets/builds/tailwind.css | head
```

Expected: 4+ matching lines. If any token is missing, fix the source `application.css`.

- [ ] **Step 5: Commit**

```bash
git add app/assets/tailwind/application.css
git commit -m "Phase 1: replace design tokens with Garden palette + type families"
```

---

## Task 2: MusicalHelper

**Files:**
- Create: `app/helpers/musical_helper.rb`
- Test: `test/helpers/musical_helper_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/helpers/musical_helper_test.rb`:

```ruby
require "test_helper"

class MusicalHelperTest < ActionView::TestCase
  include MusicalHelper

  test "musical_eyebrow wraps text in a div with eyebrow classes" do
    html = musical_eyebrow("Op. 1984 — In Memoriam")

    assert_match %r{<div[^>]*class="[^"]*text-eyebrow}, html
    assert_match %r{Op\. 1984}, html
  end

  test "musical_eyebrow with rule prepends a horizontal rule span" do
    html = musical_eyebrow("MVT. I", with_rule: true)

    assert_match %r{<span[^>]*class="[^"]*bg-sage}, html
    assert_match %r{MVT\. I}, html
  end

  test "musical_eyebrow without rule has no rule span" do
    html = musical_eyebrow("MVT. I")

    refute_match %r{bg-sage}, html
  end

  test "musical_eyebrow escapes HTML in the text" do
    html = musical_eyebrow("<script>alert('xss')</script>")

    refute_match %r{<script>}, html
    assert_match %r{&lt;script&gt;}, html
  end

  test "tempo_marking renders italic serif rose text" do
    html = tempo_marking("andante con moto")

    assert_match %r{font-serif italic}, html
    assert_match %r{text-rose}, html
    assert_match %r{andante con moto}, html
  end
end
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
bin/rails test test/helpers/musical_helper_test.rb -v
```

Expected: `NameError: uninitialized constant MusicalHelperTest::MusicalHelper` (or similar — module doesn't exist yet). All tests fail.

- [ ] **Step 3: Write minimal implementation**

Create `app/helpers/musical_helper.rb`:

```ruby
module MusicalHelper
  # Renders the small mono uppercase eyebrow label used for opus numbers,
  # movement markers, and section metadata.
  #
  # Pass with_rule: true to prepend a short horizontal sage rule
  # (used in the Hero "Op. 1984 — In Memoriam" position).
  def musical_eyebrow(text, with_rule: false)
    parts = []
    if with_rule
      parts << content_tag(:span, "", class: "inline-block w-7 h-px bg-sage mr-3.5 align-middle")
    end
    parts << ERB::Util.h(text)

    content_tag(:div,
      raw(parts.join),
      class: "text-eyebrow flex items-center"
    )
  end

  # Renders an italic Cormorant tempo marking in rose — used after section
  # titles ("— andante con moto").
  def tempo_marking(text)
    content_tag(:span, "— #{text}",
      class: "font-serif italic text-[22px] text-rose"
    )
  end
end
```

- [ ] **Step 4: Run test and verify it passes**

Run:

```bash
bin/rails test test/helpers/musical_helper_test.rb -v
```

Expected: 5 runs, 5 assertions, 0 failures, 0 errors.

- [ ] **Step 5: Commit**

```bash
git add app/helpers/musical_helper.rb test/helpers/musical_helper_test.rb
git commit -m "Phase 1: add MusicalHelper (musical_eyebrow, tempo_marking)"
```

---

## Task 3: NavHelper

**Files:**
- Create: `app/helpers/nav_helper.rb`
- Test: `test/helpers/nav_helper_test.rb`

- [ ] **Step 1: Write the failing test**

Create `test/helpers/nav_helper_test.rb`:

```ruby
require "test_helper"

class NavHelperTest < ActionView::TestCase
  include NavHelper

  test "nav_link renders an anchor with link classes" do
    html = nav_link("Biography", "/chris")

    assert_match %r{<a[^>]+href="/chris"}, html
    assert_match %r{Biography}, html
    assert_match %r{text-ink}, html
  end

  test "nav_link marks the current page with aria-current and moss medium" do
    # current_page? uses request env; stub it
    self.stubs(:current_page?).returns(true)

    html = nav_link("Biography", "/chris")

    assert_match %r{aria-current="page"}, html
    assert_match %r{font-medium text-moss}, html
  end

  test "nav_link omits aria-current for non-current pages" do
    self.stubs(:current_page?).returns(false)

    html = nav_link("Biography", "/chris")

    refute_match %r{aria-current}, html
    refute_match %r{font-medium text-moss}, html
  end

  test "nav_link accepts extra_class" do
    self.stubs(:current_page?).returns(false)

    html = nav_link("Biography", "/chris", extra_class: "text-xs")

    assert_match %r{text-xs}, html
  end
end
```

- [ ] **Step 2: Verify mocha is available**

Run:

```bash
bundle list | grep mocha
```

If mocha isn't listed, rewrite the stubbing approach by overriding `current_page?` in the test class. Replace the failing tests with this version (no mocha needed):

```ruby
require "test_helper"

class NavHelperTest < ActionView::TestCase
  include NavHelper

  attr_accessor :stub_current

  def current_page?(*)
    stub_current
  end

  test "nav_link renders an anchor with link classes" do
    self.stub_current = false
    html = nav_link("Biography", "/chris")

    assert_match %r{<a[^>]+href="/chris"}, html
    assert_match %r{Biography}, html
    assert_match %r{text-ink}, html
  end

  test "nav_link marks the current page with aria-current and moss medium" do
    self.stub_current = true

    html = nav_link("Biography", "/chris")

    assert_match %r{aria-current="page"}, html
    assert_match %r{font-medium text-moss}, html
  end

  test "nav_link omits aria-current for non-current pages" do
    self.stub_current = false

    html = nav_link("Biography", "/chris")

    refute_match %r{aria-current}, html
    refute_match %r{font-medium text-moss}, html
  end

  test "nav_link accepts extra_class" do
    self.stub_current = false

    html = nav_link("Biography", "/chris", extra_class: "text-xs")

    assert_match %r{text-xs}, html
  end
end
```

- [ ] **Step 3: Run test and verify it fails**

Run:

```bash
bin/rails test test/helpers/nav_helper_test.rb -v
```

Expected: `NameError: uninitialized constant NavHelperTest::NavHelper`.

- [ ] **Step 4: Write minimal implementation**

Create `app/helpers/nav_helper.rb`:

```ruby
module NavHelper
  # Wraps link_to with active-state awareness: sets aria-current="page" and
  # applies a moss-medium style when the current request URL matches `path`.
  def nav_link(label, path, extra_class: "")
    active = current_page?(path)
    classes = ["text-ink hover:text-moss transition-colors"]
    classes << "font-medium text-moss" if active
    classes << extra_class if extra_class.present?

    link_to label, path,
      class: classes.join(" "),
      "aria-current": (active ? "page" : nil)
  end
end
```

- [ ] **Step 5: Run test and verify it passes**

Run:

```bash
bin/rails test test/helpers/nav_helper_test.rb -v
```

Expected: 4 runs, 4+ assertions, 0 failures, 0 errors.

- [ ] **Step 6: Commit**

```bash
git add app/helpers/nav_helper.rb test/helpers/nav_helper_test.rb
git commit -m "Phase 1: add NavHelper (nav_link with aria-current support)"
```

---

## Task 4: _staff_lines partial

**Files:**
- Create: `app/views/shared/_staff_lines.html.erb`
- Test: rendered in Task 9's integration test on `/style-guide` and in `_home_nav` later. No isolated test — markup-only.

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_staff_lines.html.erb`:

```erb
<%#
  Faint horizontal-rule "staff lines" texture used in hero + section
  dividers. Render inside a `relative` parent.

  Locals:
    top: top offset in px (default 0)
    height: height in px (default 120)
    opacity: 0–1 (default 0.07)
%>
<% top ||= 0 %>
<% height ||= 120 %>
<% opacity ||= 0.07 %>
<div class="absolute inset-x-0 staff-lines-bg pointer-events-none"
     aria-hidden="true"
     style="top: <%= top %>px; height: <%= height %>px; opacity: <%= opacity %>;"></div>
```

- [ ] **Step 2: Smoke-render via Rails console**

Run:

```bash
bin/rails runner 'puts ApplicationController.render(partial: "shared/staff_lines", locals: {})'
```

Expected: HTML output containing `staff-lines-bg`, `pointer-events-none`, `aria-hidden="true"`, `top: 0px`, `height: 120px`, `opacity: 0.07`.

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_staff_lines.html.erb
git commit -m "Phase 1: add _staff_lines partial for faint musical texture"
```

---

## Task 5: _movement_label partial

**Files:**
- Create: `app/views/shared/_movement_label.html.erb`

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_movement_label.html.erb`:

```erb
<%#
  Movement label row used as a section heading on the homepage and
  inner pages: "MVT. I  Honor his memory  — andante con moto"

  Locals:
    no: opus/movement number, e.g. "MVT. I" or "Op. III"
    title: section title, e.g. "Honor his memory"
    marking: italic tempo marking, e.g. "andante con moto"
    id: optional DOM id for the <h2>
%>
<% id ||= nil %>
<div class="flex flex-col md:flex-row md:items-baseline md:gap-6 mb-8">
  <span class="text-eyebrow mb-2 md:mb-0"><%= no %></span>
  <h2 <%= "id=\"#{id}\"".html_safe if id %>
      class="font-serif text-4xl md:text-[56px] font-normal leading-none tracking-tight text-ink m-0">
    <%= title %>
  </h2>
  <%= tempo_marking(marking) %>
</div>
```

- [ ] **Step 2: Smoke-render**

Run:

```bash
bin/rails runner 'puts ApplicationController.render(partial: "shared/movement_label", locals: { no: "MVT. I", title: "Honor his memory", marking: "andante con moto" })'
```

Expected output contains:
- `MVT. I` inside a span with `text-eyebrow`
- `<h2 class="font-serif text-4xl md:text-[56px]` etc.
- `Honor his memory`
- `— andante con moto` inside a serif italic rose span

If the smoke render errors with `undefined method tempo_marking`, the rendering context doesn't have helpers — verify `MusicalHelper` is auto-included via `app/helpers/` (it should be by default in Rails 8).

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_movement_label.html.erb
git commit -m "Phase 1: add _movement_label partial for section headings"
```

---

## Task 6: _foot_col partial

**Files:**
- Create: `app/views/shared/_foot_col.html.erb`

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_foot_col.html.erb`:

```erb
<%#
  Footer link column. Used three times by _site_footer.

  Locals:
    title: column heading, e.g. "Christopher"
    items: array of [label, path] pairs, e.g. [["Biography", "/chris"], ...]
%>
<div>
  <div class="text-eyebrow opacity-55 mb-3.5"><%= title %></div>
  <ul class="list-none p-0 m-0 space-y-1.5">
    <% items.each do |label, path| %>
      <li class="text-sm opacity-90">
        <% if path.is_a?(String) && path.start_with?("http", "mailto") %>
          <%= link_to label, path, class: "text-cream no-underline hover:opacity-100",
              target: (path.start_with?("http") ? "_blank" : nil),
              rel: (path.start_with?("http") ? "noopener" : nil) %>
        <% else %>
          <%= link_to label, path, class: "text-cream no-underline hover:opacity-100" %>
        <% end %>
      </li>
    <% end %>
  </ul>
</div>
```

- [ ] **Step 2: Smoke-render**

Run:

```bash
bin/rails runner 'puts ApplicationController.render(partial: "shared/foot_col", locals: { title: "Christopher", items: [["Biography", "/chris"], ["Updates", "/updates"]] })'
```

Expected output contains:
- `Christopher` in a `text-eyebrow` div
- Two `<a>` tags with `text-cream` class
- `href="/chris"` and `href="/updates"`

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_foot_col.html.erb
git commit -m "Phase 1: add _foot_col partial for footer link groups"
```

---

## Task 7: _home_nav partial

**Files:**
- Create: `app/views/shared/_home_nav.html.erb`

Renders the sticky cream/blur top nav. Uses `nav_link` for active-state and renders the `Share a memory` CTA + a sign-in area.

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_home_nav.html.erb`:

```erb
<%#
  Sticky cream/blur top nav. Used by every page via application.html.erb.

  Behavior:
  - Desktop: wordmark + date + 5 nav links + Share-a-memory pill +
    sign-in/admin/sign-out group
  - Mobile: wordmark + hamburger; tap toggles a stacked menu below
%>
<nav class="sticky top-0 z-50 bg-cream/90 backdrop-blur-[10px] border-b border-ink/10 font-sans"
     data-controller="nav">
  <div class="flex items-center justify-between px-6 lg:px-14 py-5">
    <%# Left — wordmark + date %>
    <%= link_to root_path, class: "flex items-baseline gap-3 no-underline" do %>
      <span class="font-serif text-[22px] font-medium tracking-[0.02em] text-moss">
        Christopher Quentin
      </span>
      <span class="text-eyebrow hidden sm:inline">1984 — 2020</span>
    <% end %>

    <%# Right — desktop nav %>
    <div class="hidden md:flex items-center gap-7 text-[15px]">
      <%= nav_link "Biography", chris_path %>
      <%= nav_link "Memories", memories_path %>
      <%= nav_link "Trees",    trees_path %>
      <%= nav_link "Projects", projects_path %>
      <%= nav_link "Funds",    funds_path %>

      <%= link_to "Share a memory", new_memory_path,
            class: "bg-moss text-cream rounded-full px-5 py-2.5 text-sm no-underline hover:bg-ink transition-colors" %>

      <div class="text-xs text-ink/60 flex items-center gap-2 ml-2">
        <% if user_signed_in? %>
          <% if current_user.admin? %>
            <%= link_to "Admin", admin_root_path, class: "hover:text-moss" %>
            <span aria-hidden="true">·</span>
          <% end %>
          <%= link_to "Sign out", destroy_user_session_path, data: { turbo_method: :delete }, class: "hover:text-moss" %>
        <% else %>
          <%= link_to "Sign in", new_user_session_path, class: "hover:text-moss" %>
        <% end %>
      </div>
    </div>

    <%# Right — mobile hamburger %>
    <button type="button"
            data-action="nav#toggle"
            aria-label="Open menu"
            class="md:hidden text-ink hover:text-moss">
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24" aria-hidden="true">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 6h16M4 12h16M4 18h16"/>
      </svg>
    </button>
  </div>

  <%# Mobile menu (Phase 1: simple stacked list; Phase 2 upgrades to drawer) %>
  <div class="hidden md:hidden px-6 pb-5 space-y-2.5 text-[15px]" data-nav-target="menu">
    <%= nav_link "Biography", chris_path, extra_class: "block py-1" %>
    <%= nav_link "Memories", memories_path, extra_class: "block py-1" %>
    <%= nav_link "Trees",    trees_path, extra_class: "block py-1" %>
    <%= nav_link "Projects", projects_path, extra_class: "block py-1" %>
    <%= nav_link "Funds",    funds_path, extra_class: "block py-1" %>
    <%= link_to "Share a memory", new_memory_path,
          class: "block bg-moss text-cream rounded-full px-5 py-2.5 text-sm no-underline text-center mt-3" %>
    <div class="text-xs text-ink/60 pt-3 border-t border-ink/10 mt-3">
      <% if user_signed_in? %>
        <% if current_user.admin? %>
          <%= link_to "Admin", admin_root_path, class: "block py-1 hover:text-moss" %>
        <% end %>
        <%= link_to "Sign out", destroy_user_session_path, data: { turbo_method: :delete }, class: "block py-1 hover:text-moss" %>
      <% else %>
        <%= link_to "Sign in", new_user_session_path, class: "block py-1 hover:text-moss" %>
      <% end %>
    </div>
  </div>
</nav>
```

- [ ] **Step 2: Smoke-render**

The partial uses route helpers and `user_signed_in?` — those require a request cycle, so don't try to render via `bin/rails runner`. Instead, smoke-test via the layout in Task 9.

For now, just verify the file parses with no syntax errors:

```bash
bin/rails runner 'ActionView::Template.new(File.read("app/views/shared/_home_nav.html.erb"), "app/views/shared/_home_nav.html.erb", ActionView::Template.handler_for_extension("erb"), locals: [], format: :html).source; puts "OK"'
```

Expected: `OK`. If error: fix the syntax.

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_home_nav.html.erb
git commit -m "Phase 1: add _home_nav partial with sticky cream/blur nav"
```

---

## Task 8: _site_footer partial

**Files:**
- Create: `app/views/shared/_site_footer.html.erb`

- [ ] **Step 1: Create the partial**

Create `app/views/shared/_site_footer.html.erb`:

```erb
<%#
  Dark ink footer with faint staff-line overlay at the top edge,
  newsletter signup, three link columns, and a "1984 — 2020 ♪ fine."
  coda line. Used by every page via application.html.erb.
%>
<footer class="bg-ink text-cream relative px-6 lg:px-14 pt-18 pb-10">
  <%= render "shared/staff_lines", top: 0, height: 90, opacity: 0.06 %>

  <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-[1.4fr_1fr_1fr_1fr] gap-10 relative">
    <%# Newsletter %>
    <div>
      <div class="text-eyebrow opacity-60 mb-3.5" style="color: var(--color-cream);">Coda</div>
      <h3 class="font-serif text-[36px] font-normal leading-tight max-w-[340px] m-0">
        Stay in touch — we send updates a few times a year.
      </h3>
      <%= form_with url: newsletter_subscribers_path,
            class: "flex gap-2 max-w-[460px] mt-5",
            local: true do |f| %>
        <%= f.email_field :email,
              placeholder: "your email",
              required: true,
              "aria-label": "Email address",
              class: "flex-1 bg-cream/8 border border-cream/20 rounded-full px-4 py-3 text-sm text-cream placeholder:text-cream/55 outline-none focus:border-cream/60" %>
        <%= f.submit "Subscribe",
              class: "bg-cream text-ink rounded-full px-5 py-3 text-sm font-medium cursor-pointer hover:bg-linen transition-colors" %>
      <% end %>
    </div>

    <%# Christopher %>
    <%= render "shared/foot_col",
          title: "Christopher",
          items: [
            ["Biography",  chris_path],
            ["Memories",   memories_path],
            ["Press",      updates_path],
            ["Photos",     new_photo_submission_path],
          ] %>

    <%# Honor %>
    <%= render "shared/foot_col",
          title: "Honor",
          items: [
            ["Plant a tree",    new_tree_path],
            ["Share a memory",  new_memory_path],
            ["Adopt a hive",    new_bee_hive_path],
            ["Funds",           funds_path],
          ] %>

    <%# More %>
    <%= render "shared/foot_col",
          title: "More",
          items: [
            ["Submit photos",   new_photo_submission_path],
            ["Order the book", "https://christopherquentin.fillout.com/book"],
            ["Share a tribute", new_tribute_path],
            (user_signed_in? ? ["Sign out", destroy_user_session_path] : ["Sign in", new_user_session_path]),
          ] %>
  </div>

  <div class="mt-14 pt-6 border-t border-cream/15 flex justify-between items-center text-[13px] opacity-70">
    <span>&copy; <%= Date.current.year %> Christopher Quentin Memorial</span>
    <span class="font-serif italic">1984 — 2020 &nbsp; ♪ &nbsp; fine.</span>
  </div>
</footer>
```

- [ ] **Step 2: Verify it parses**

Run:

```bash
bin/rails runner 'ActionView::Template.new(File.read("app/views/shared/_site_footer.html.erb"), "app/views/shared/_site_footer.html.erb", ActionView::Template.handler_for_extension("erb"), locals: [], format: :html).source; puts "OK"'
```

Expected: `OK`.

- [ ] **Step 3: Commit**

```bash
git add app/views/shared/_site_footer.html.erb
git commit -m "Phase 1: add _site_footer partial with Coda + Honor + More + newsletter"
```

---

## Task 9: New application.html.erb layout + Google Fonts

**Files:**
- Modify: `app/views/layouts/application.html.erb`
- Modify: `app/javascript/controllers/nav_controller.js` (verify no change needed)
- Create: `test/integration/site_layout_test.rb`

- [ ] **Step 1: Write the failing integration test**

Create `test/integration/site_layout_test.rb`:

```ruby
require "test_helper"

class SiteLayoutTest < ActionDispatch::IntegrationTest
  test "layout uses cream background and ink text" do
    get root_path
    assert_response :success
    assert_select "body.bg-cream.text-ink.font-sans"
  end

  test "layout includes Google Fonts for Cormorant Garamond, DM Sans, JetBrains Mono" do
    get root_path
    assert_select "link[rel='stylesheet'][href*='fonts.googleapis.com']" do |links|
      hrefs = links.map { |l| l["href"] }
      assert hrefs.any? { |h| h.include?("Cormorant+Garamond") }, "Expected Cormorant Garamond font"
      assert hrefs.any? { |h| h.include?("DM+Sans") }, "Expected DM Sans font"
      assert hrefs.any? { |h| h.include?("JetBrains+Mono") }, "Expected JetBrains Mono font"
    end
  end

  test "layout does NOT load Josefin Sans" do
    get root_path
    assert_select "link[rel='stylesheet'][href*='Josefin']", 0
  end

  test "home_nav renders with wordmark and Share a memory CTA" do
    get root_path
    assert_select "nav[data-controller='nav']" do
      assert_select "span", /Christopher Quentin/
      assert_select "a[href=?]", new_memory_path, /Share a memory/
    end
  end

  test "home_nav shows Sign in for signed-out users" do
    get root_path
    assert_select "nav a[href=?]", new_user_session_path, /Sign in/
  end

  test "home_nav shows Sign out for signed-in users" do
    user = User.create!(name: "Test", email: "test-layout@test.com", password: "password123", role: :contributor)
    post user_session_path, params: { user: { email: user.email, password: "password123" } }
    get root_path

    assert_select "nav a", text: /Sign out/
  end

  test "footer renders newsletter form pointing at newsletter_subscribers_path" do
    get root_path
    assert_select "footer form[action=?]", newsletter_subscribers_path do
      assert_select "input[type='email'][name='email']"
      assert_select "input[type='submit'][value='Subscribe']"
    end
  end

  test "footer renders all three column titles" do
    get root_path
    assert_select "footer" do
      assert_select "div", text: "Christopher"
      assert_select "div", text: "Honor"
      assert_select "div", text: "More"
    end
  end

  test "footer renders coda line" do
    get root_path
    assert_select "footer span", text: /1984 — 2020.+fine\./
  end

  test "layout removes old utility bar dark-stone top strip" do
    get root_path
    # The old layout had bg-stone-800 in a top utility bar; new layout must not.
    refute_match %r{bg-stone-800}, response.body
  end
end
```

- [ ] **Step 2: Run test and verify it fails**

Run:

```bash
bin/rails test test/integration/site_layout_test.rb -v
```

Expected: multiple failures — body classes don't match, no Google Fonts, etc.

- [ ] **Step 3: Replace the layout**

Overwrite `app/views/layouts/application.html.erb` with:

```erb
<!DOCTYPE html>
<html lang="en" class="h-full">
  <head>
    <title><%= content_for(:title) || "Christopher Quentin McMullen-Laird" %></title>
    <meta name="viewport" content="width=device-width,initial-scale=1">
    <meta name="description" content="<%= content_for(:description) || "A memorial celebrating the life and legacy of Christopher Quentin McMullen-Laird, conductor (1984-2020)." %>">
    <meta name="apple-mobile-web-app-capable" content="yes">
    <meta name="application-name" content="Christopher Quentin">
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>

    <%= yield :head %>

    <link rel="icon" href="/icon.png" type="image/png">
    <link rel="icon" href="/icon.svg" type="image/svg+xml">
    <link rel="apple-touch-icon" href="/icon.png">

    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Cormorant+Garamond:ital,wght@0,400;0,500;1,400;1,500&family=DM+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;500&display=swap"
          rel="stylesheet">

    <%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="bg-cream text-ink font-sans flex flex-col min-h-full">
    <%= render "shared/home_nav" %>

    <% if notice %>
      <div class="bg-linen border-l-2 border-moss text-moss px-6 lg:px-14 py-3 text-sm">
        <%= notice %>
      </div>
    <% end %>
    <% if alert %>
      <div class="bg-linen border-l-2 border-rose text-rose px-6 lg:px-14 py-3 text-sm">
        <%= alert %>
      </div>
    <% end %>

    <main class="flex-1 w-full">
      <%= yield %>
    </main>

    <%= render "shared/site_footer" %>
  </body>
</html>
```

- [ ] **Step 4: Verify nav_controller.js still works**

Confirm `app/javascript/controllers/nav_controller.js` still has:

```js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }
}
```

No change needed — the partial uses `data-nav-target="menu"`. If the file diverges, restore it to the above.

- [ ] **Step 5: Run the layout integration test and verify pass**

Run:

```bash
bin/rails test test/integration/site_layout_test.rb -v
```

Expected: 10 runs, 10+ assertions, 0 failures, 0 errors.

- [ ] **Step 6: Run the full test suite to catch regressions**

Run:

```bash
bin/rails test 2>&1 | tail -10
```

Expected: previously-green tests still green. Total runs increased by ~14 (5 musical_helper + 4 nav_helper + 10 site_layout, minus collisions). Note any failing test — most likely culprits are the pre-existing tests that asserted against old layout markup (none expected per the earlier grep, but verify).

If `public_pages_test` "home page loads" or "chris page loads" fail, they assert on `h1` content inside the page body. Layout changes shouldn't affect those — fix only if the page body actually broke.

- [ ] **Step 7: Visual check at multiple breakpoints**

Start the server:

```bash
bin/rails server &
SERVER_PID=$!
sleep 3
```

Open `http://localhost:3000` in a browser. Resize to 1440 / 1024 / 768 / 375. At each width, verify:
- Nav background is cream with subtle blur on scroll.
- Wordmark is moss-green Cormorant Garamond.
- Right-side links visible on ≥768px; hamburger replaces them below.
- Footer is dark ink, with newsletter form + 3 link columns on ≥1024px.
- Footer coda line "1984 — 2020 ♪ fine." in italic Cormorant.
- Body background is cream throughout.

Then stop the server: `kill $SERVER_PID`.

The page body content (home page) will still look mismatched — Blue/Stone styling inside Cream/Moss chrome. **That is expected for Phase 1.**

- [ ] **Step 8: Commit**

```bash
git add app/views/layouts/application.html.erb test/integration/site_layout_test.rb
git commit -m "Phase 1: replace layout shell with Garden chrome + Google Fonts"
```

---

## Task 10: /style-guide page

**Files:**
- Modify: `config/routes.rb`
- Modify: `app/controllers/pages_controller.rb`
- Create: `app/views/pages/style_guide.html.erb`
- Create: `test/integration/style_guide_test.rb`

- [ ] **Step 1: Write failing integration test**

Create `test/integration/style_guide_test.rb`:

```ruby
require "test_helper"

class StyleGuideTest < ActionDispatch::IntegrationTest
  test "style guide is reachable in test environment" do
    get "/style-guide"
    assert_response :success
    assert_select "h1", /Style Guide/
  end

  test "style guide renders all palette swatches" do
    get "/style-guide"
    %w[cream linen ink sage moss rose].each do |color|
      assert_select "[data-swatch=?]", color
    end
  end

  test "style guide renders the three type specimens" do
    get "/style-guide"
    assert_select ".font-serif", /Cormorant Garamond/
    assert_select ".font-sans", /DM Sans/
    assert_select ".font-mono", /JetBrains Mono/
  end

  test "style guide renders a movement label" do
    get "/style-guide"
    assert_select "h2", /Honor his memory/
    assert_select "span", /andante con moto/
  end

  test "style guide renders eyebrows, both plain and with-rule" do
    get "/style-guide"
    assert_select ".text-eyebrow", count: 2..100
    assert_select "span.bg-sage"
  end
end
```

- [ ] **Step 2: Run the test and verify it fails**

Run:

```bash
bin/rails test test/integration/style_guide_test.rb -v
```

Expected: `ActionController::RoutingError` (no route matches /style-guide) on all tests.

- [ ] **Step 3: Add the route, dev/test-guarded**

Find `config/routes.rb` and add right above the `get "up" => "rails/health#show"` line:

```ruby
  if Rails.env.development? || Rails.env.test?
    get "style-guide", to: "pages#style_guide", as: :style_guide
  end
```

- [ ] **Step 4: Add the controller action**

`PagesController` has no `before_action` filters and `ApplicationController` does not require authentication — just add the action. Edit `app/controllers/pages_controller.rb`, append after the `news` action:

```ruby
  def style_guide
    # View exercises all design tokens + shared partials.
  end
```

The route guard in `routes.rb` (Step 3) already prevents production exposure.

- [ ] **Step 5: Create the style guide view**

Create `app/views/pages/style_guide.html.erb`:

```erb
<% content_for :title, "Style Guide" %>

<div class="px-6 lg:px-14 py-16 max-w-[1100px] mx-auto space-y-20">
  <header>
    <%= musical_eyebrow("Phase 1 · Garden direction", with_rule: true) %>
    <h1 class="font-serif text-5xl md:text-6xl font-normal text-ink mt-3">Style Guide</h1>
    <p class="font-serif italic text-xl text-sage mt-3">
      A working reference for every token, font, partial, and helper in the redesigned chrome.
    </p>
  </header>

  <%# Palette %>
  <section>
    <%= render "shared/movement_label", no: "I", title: "Palette", marking: "sostenuto" %>
    <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
      <% [
        ["cream", "#faf6ee", "page background"],
        ["linen", "#f1ebde", "section bg, chips"],
        ["ink",   "#1c2620", "body text"],
        ["sage",  "#5a7a5e", "metadata"],
        ["moss",  "#3a5240", "primary CTA"],
        ["rose",  "#a8584c", "musical accent"],
      ].each do |name, hex, role| %>
        <div class="flex flex-col gap-2" data-swatch="<%= name %>">
          <div class="aspect-square rounded-md shadow-card border border-ink/8"
               style="background: <%= hex %>;"></div>
          <div>
            <div class="font-medium text-sm capitalize"><%= name %></div>
            <div class="font-mono text-xs text-sage"><%= hex %></div>
            <div class="text-xs text-ink/60"><%= role %></div>
          </div>
        </div>
      <% end %>
    </div>
  </section>

  <%# Type %>
  <section>
    <%= render "shared/movement_label", no: "II", title: "Type", marking: "cantabile" %>
    <div class="space-y-10">
      <div>
        <%= musical_eyebrow("Display · Cormorant Garamond 96") %>
        <div class="font-serif text-[96px] leading-none mt-3">
          Christopher <em class="text-moss">Quentin</em>
        </div>
      </div>
      <div>
        <%= musical_eyebrow("Section · Cormorant Garamond 56") %>
        <div class="font-serif text-[56px] leading-none mt-3">A life, kept by many hands.</div>
      </div>
      <div>
        <%= musical_eyebrow("Body · DM Sans 17") %>
        <p class="font-sans text-[17px] leading-relaxed max-w-[640px] mt-3">
          The new design intentionally moves to Cormorant + DM Sans for legibility
          and warmth — paired with JetBrains Mono for tiny musical metadata.
        </p>
      </div>
      <div>
        <%= musical_eyebrow("Meta · JetBrains Mono 11") %>
        <div class="font-mono text-[11px] tracking-[0.22em] uppercase text-sage mt-3">
          Op. 1984 — In Memoriam · MVT. III — adagio
        </div>
      </div>
    </div>
  </section>

  <%# Eyebrows + Tempo %>
  <section>
    <%= render "shared/movement_label", no: "III", title: "Eyebrow + Tempo", marking: "parlando" %>
    <div class="space-y-6">
      <%= musical_eyebrow("Plain eyebrow") %>
      <%= musical_eyebrow("With rule", with_rule: true) %>
      <div class="font-serif text-3xl">
        Honor his memory <%= tempo_marking("andante con moto") %>
      </div>
    </div>
  </section>

  <%# Movement label %>
  <section>
    <%= render "shared/movement_label", no: "MVT. IV", title: "Honor his memory", marking: "andante con moto" %>
    <p class="text-sm text-ink/60">↑ That is the movement label partial in action.</p>
  </section>

  <%# Buttons %>
  <section>
    <%= render "shared/movement_label", no: "V", title: "Buttons", marking: "con brio" %>
    <div class="flex flex-wrap gap-4 items-center">
      <button class="bg-moss text-cream rounded-full px-6 py-3.5 text-sm font-medium hover:bg-ink">Read his story →</button>
      <button class="bg-transparent text-ink border border-ink/20 rounded-full px-6 py-3.5 text-sm hover:border-moss hover:text-moss">+ Share a memory</button>
      <a href="#" class="text-moss text-sm font-medium hover:underline">View full timeline →</a>
    </div>
  </section>

  <%# Card preview %>
  <section>
    <%= render "shared/movement_label", no: "VI", title: "Card", marking: "dolce" %>
    <div class="max-w-[360px] bg-white rounded-md border border-ink/8 shadow-card p-7">
      <div class="font-serif text-[32px] text-moss leading-none mb-1.5">❦</div>
      <%= musical_eyebrow("I. Plant") %>
      <h3 class="font-serif text-3xl mt-2.5">Plant a Tree</h3>
      <p class="text-sm leading-relaxed text-ink/70 mt-3">
        Add a tree to the living map of saplings planted in his memory.
      </p>
      <a href="#" class="text-moss text-sm font-medium mt-4 inline-block">Plant a tree →</a>
    </div>
  </section>

  <%# Staff lines %>
  <section>
    <%= render "shared/movement_label", no: "VII", title: "Staff lines", marking: "lento" %>
    <div class="relative h-32 bg-cream border border-ink/8 rounded-md">
      <%= render "shared/staff_lines", top: 0, height: 128, opacity: 0.18 %>
      <div class="absolute inset-0 flex items-center justify-center text-sage font-mono text-xs">
        Faint musical wallpaper, rendered at 18% opacity to show.
      </div>
    </div>
  </section>
</div>
```

- [ ] **Step 6: Run the test and verify it passes**

Run:

```bash
bin/rails test test/integration/style_guide_test.rb -v
```

Expected: 5 runs, 5+ assertions, 0 failures, 0 errors.

- [ ] **Step 7: Visual check in browser**

Start the server and visit `http://localhost:3000/style-guide`. Confirm:
- All six palette swatches render with their hex values.
- Type specimens render in the correct font (you can tell Cormorant from DM Sans visually).
- Movement labels render with rose italic tempo markings.
- Card preview shows the moss `❦` glyph, eyebrow, title, and CTA link.
- Staff lines render as faint horizontal stripes inside the bordered box.

Stop the server.

- [ ] **Step 8: Commit**

```bash
git add config/routes.rb app/controllers/pages_controller.rb app/views/pages/style_guide.html.erb test/integration/style_guide_test.rb
git commit -m "Phase 1: add dev/test-only /style-guide page exercising every token + partial"
```

---

## Task 11: Final verification

**Files:** none

- [ ] **Step 1: Run the full test suite**

```bash
bin/rails test 2>&1 | tail -15
```

Expected: 80+ runs, 220+ assertions, 0 failures, 0 errors, 0 skips (was 68 / 205 before Phase 1).

If any new failure: stop. Investigate root cause per CLAUDE.md ("Never just fix the symptom").

- [ ] **Step 2: Browser regression check**

Start the server. Visit:
- `/` (home) — page body looks mismatched (Blue/Stone), nav and footer look Garden. Expected.
- `/chris` — same.
- `/timeline` (memories index) — same.
- `/users/sign_in` — Devise form looks unchanged but inside Garden chrome. Expected.
- `/style-guide` — everything renders correctly.

Stop the server.

- [ ] **Step 3: Confirm production environment still hides /style-guide**

This is a smoke test for the route guard. Run:

```bash
RAILS_ENV=production bin/rails runner 'p Rails.application.routes.url_helpers.respond_to?(:style_guide_path)'
```

Expected: `false`.

(Skip this step if production deps/secrets aren't set up — the test environment guard test already proves the inverse direction.)

- [ ] **Step 4: Final commit (only if anything changed during verification)**

If anything had to be fixed during verification:

```bash
git add -A
git commit -m "Phase 1: verification fixups"
```

If nothing changed: skip.

- [ ] **Step 5: Mark Phase 1 done**

Phase 1 is complete. The redesigned chrome wraps every page; existing page bodies still render with their old (Stone/Blue) styling. Phase 2 picks up the homepage rebuild.

---

## Self-review notes (post-write)

- ✓ Every spec section is covered by a task: tokens (T1), helpers (T2-3), partials (T4-8), layout + fonts (T9), style guide (T10), verification (T11).
- ✓ Spec's "Definition of done" maps to T11's checks.
- ✓ No "TODO", "TBD", "implement later", "add error handling" placeholders.
- ✓ Type/name consistency: `musical_eyebrow`, `tempo_marking`, `nav_link`, `data-nav-target="menu"`, all consistent across tasks.
- ✓ Footer link items match the spec (Christopher / Honor / More columns; Contact replaced by Share a tribute).
- ✓ Mobile drawer keeps the existing `nav_controller.js` `menu` target — no JS change needed in Phase 1.
- ✓ Style guide route uses `pages#style_guide`, env-guarded.

One known limitation: Task 6's `_foot_col` helper uses `link_to` for items but does not specially handle `mailto:` links (only `http`). If a future column adds a mailto link, the partial works — just doesn't add `target=_blank`. Acceptable for Phase 1.
