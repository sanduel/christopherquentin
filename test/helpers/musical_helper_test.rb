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

    assert_match %r{<span[^>]*class="[^"]*bg-accent}, html
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

  test "tempo_marking returns empty string in Memorial direction" do
    html = tempo_marking("andante con moto")

    assert_equal "", html
  end

  test "tempo_marking accepts any text without raising" do
    assert_nothing_raised { tempo_marking("<script>alert('xss')</script>") }
  end
end
