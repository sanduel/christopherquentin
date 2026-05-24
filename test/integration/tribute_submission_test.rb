require "test_helper"

class TributeSubmissionTest < ActionDispatch::IntegrationTest
  test "submitting a tribute creates a pending record" do
    assert_difference "Tribute.count", 1 do
      post tributes_path, params: {
        tribute: { name: "Jane Doe", relationship: "Friend", content: "Christopher was a light." }
      }
    end

    tribute = Tribute.last
    assert_equal "pending", tribute.status
    assert_equal "Jane Doe", tribute.name
    assert_redirected_to tributes_path
  end

  test "submitting invalid tribute shows errors" do
    assert_no_difference "Tribute.count" do
      post tributes_path, params: {
        tribute: { name: "", content: "" }
      }
    end
    assert_response :unprocessable_entity
  end

  test "only published tributes appear on index" do
    Tribute.create!(name: "Published", content: "Content", status: :published)
    Tribute.create!(name: "Pending", content: "Content", status: :pending)

    get tributes_path
    assert_response :success
    assert_match "Published", response.body
    assert_no_match "Pending", response.body
  end
end
