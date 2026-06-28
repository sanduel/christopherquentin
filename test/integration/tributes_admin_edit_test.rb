require "test_helper"

class TributesAdminEditTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def setup
    @tribute = Tribute.create!(name: "Original", relationship: "Friend",
      content: "Original content.", category: :friends, status: :pending)
  end

  test "anonymous user is sent to sign in, not the edit form" do
    get edit_tribute_path(@tribute)
    assert_redirected_to new_user_session_path
  end

  test "contributor (non-admin) cannot access the edit form" do
    sign_in_contributor
    get edit_tribute_path(@tribute)
    assert_redirected_to root_path
  end

  test "contributor (non-admin) cannot update a tribute" do
    sign_in_contributor
    patch tribute_path(@tribute), params: { tribute: { content: "Hacked" } }
    assert_redirected_to root_path
    assert_equal "Original content.", @tribute.reload.content
  end

  test "admin can open the edit form" do
    sign_in_admin
    get edit_tribute_path(@tribute)
    assert_response :success
    assert_select "form"
  end

  test "admin can update a tribute including moderation status" do
    sign_in_admin
    patch tribute_path(@tribute), params: { tribute: {
      name: "Edited", content: "Edited content.", status: "published" } }
    assert_redirected_to tribute_path(@tribute)
    @tribute.reload
    assert_equal "Edited", @tribute.name
    assert_equal "Edited content.", @tribute.content
    assert_equal "published", @tribute.status
  end

  test "after setting status to pending, admin can still view the tribute" do
    sign_in_admin
    patch tribute_path(@tribute), params: { tribute: { status: "pending" } }
    assert_redirected_to tribute_path(@tribute)
    follow_redirect!
    assert_response :success
  end

  test "non-admin gets 404 for an unpublished tribute show" do
    @tribute.update!(status: :pending)
    get tribute_path(@tribute)
    assert_response :not_found
  end

  test "invalid update re-renders the edit form" do
    sign_in_admin
    patch tribute_path(@tribute), params: { tribute: { name: "", content: "" } }
    assert_response :unprocessable_entity
    assert_equal "Original", @tribute.reload.name
  end

  test "admin sees an Edit link in the tribute modal on the index" do
    @tribute.update!(status: :published)
    sign_in_admin
    get tributes_path
    assert_select "a[href=?]", edit_tribute_path(@tribute), text: /Edit/i
  end

  test "anonymous visitor does not see an Edit link" do
    @tribute.update!(status: :published)
    get tributes_path
    assert_select "a[href=?]", edit_tribute_path(@tribute), count: 0
  end
end
