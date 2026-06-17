require "test_helper"

class MemoriesControllerTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "GET /timeline works for anonymous users" do
    get memories_path
    assert_response :success
  end

  test "GET /timeline/new works for anonymous users" do
    get new_memory_path
    assert_response :success
  end

  test "anonymous POST /timeline creates a pending memory" do
    assert_difference "Memory.count", 1 do
      post memories_path, params: {
        memory: {
          date: Date.today.to_s,
          content: "An anonymous remembrance.",
          name: "Stranger",
          email: "stranger@example.com",
          kind: "text"
        }
      }
    end
    memory = Memory.last
    assert_equal "pending", memory.status
    assert_nil memory.user
  end

  test "signed-in POST /timeline creates a published memory" do
    user = sign_in_contributor

    assert_difference "Memory.count", 1 do
      post memories_path, params: {
        memory: {
          date: Date.today.to_s,
          content: "A signed-in memory.",
          kind: "text"
        }
      }
    end
    memory = Memory.last
    assert_equal "published", memory.status
    assert_equal user, memory.user
  end

  test "GET /timeline filters by year" do
    Memory.create!(date: Date.new(2010, 1, 1), content: "Old", name: "A", email: "a@b.com", status: :published)
    Memory.create!(date: Date.new(2020, 1, 1), content: "Recent", name: "B", email: "b@c.com", status: :published)

    get memories_path, params: { year: 2010 }

    assert_match "Old", response.body
    assert_no_match "Recent", response.body
  end

  test "year filter exposes available years" do
    Memory.delete_all
    Memory.create!(date: Date.new(2010, 1, 1), content: "x", name: "A", email: "a@b.com", status: :published)
    Memory.create!(date: Date.new(2020, 1, 1), content: "y", name: "B", email: "b@c.com", status: :published)

    get memories_path

    assert_match "2010", response.body
    assert_match "2020", response.body
  end

  test "validation failure renders timeline with flash alert (no crash)" do
    post memories_path, params: {
      memory: {
        date: nil,  # required field missing
        content: "",
        name: "Tester",
        email: "t@t.com",
        kind: "text"
      }
    }
    assert_response :unprocessable_entity
    # Flash alert rendered inline; apostrophe is HTML-encoded as &#39;
    assert_match /can&#39;t be blank/i, response.body
  end
end
