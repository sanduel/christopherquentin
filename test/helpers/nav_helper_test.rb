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

  test "nav_link marks the current page with aria-current and accent medium" do
    self.stub_current = true

    html = nav_link("Biography", "/chris")

    assert_match %r{aria-current="page"}, html
    assert_match %r{font-medium text-accent}, html
  end

  test "nav_link omits aria-current for non-current pages" do
    self.stub_current = false

    html = nav_link("Biography", "/chris")

    refute_match %r{aria-current}, html
    refute_match %r{font-medium text-accent}, html
  end

  test "nav_link accepts extra_class" do
    self.stub_current = false

    html = nav_link("Biography", "/chris", extra_class: "text-xs")

    assert_match %r{text-xs}, html
  end
end
