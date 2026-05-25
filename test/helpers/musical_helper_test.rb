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
