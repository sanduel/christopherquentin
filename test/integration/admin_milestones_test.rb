require "test_helper"

class AdminMilestonesTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "index renders for admin" do
    sign_in_admin
    Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born in Tokyo")
    get admin_milestones_path
    assert_response :success
    assert_match "Born in Tokyo", response.body
  end

  test "new form renders for admin" do
    sign_in_admin
    get new_admin_milestone_path
    assert_response :success
  end

  test "admin can create a milestone" do
    sign_in_admin
    assert_difference -> { Milestone.count }, 1 do
      post admin_milestones_path, params: {
        milestone: { date: "1984-01-01", headline: "Born in Tokyo",
                     description: "The beginning.", location: "Tokyo, Japan" }
      }
    end
    created = Milestone.order(:created_at).last
    assert_equal "Born in Tokyo", created.headline
    assert_redirected_to admin_milestones_path
  end

  test "create with missing headline re-renders with error" do
    sign_in_admin
    assert_no_difference -> { Milestone.count } do
      post admin_milestones_path, params: { milestone: { date: "1984-01-01", headline: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "admin can update a milestone" do
    sign_in_admin
    milestone = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Old")
    patch admin_milestone_path(milestone), params: { milestone: { headline: "New headline" } }
    assert_equal "New headline", milestone.reload.headline
    assert_redirected_to admin_milestones_path
  end

  test "admin can destroy a milestone" do
    sign_in_admin
    milestone = Milestone.create!(date: Date.new(1984, 1, 1), headline: "Born")
    assert_difference -> { Milestone.count }, -1 do
      delete admin_milestone_path(milestone)
    end
  end

  test "non-admin is redirected away" do
    sign_in_contributor
    get admin_milestones_path
    assert_redirected_to root_path
  end
end
