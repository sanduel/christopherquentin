require "test_helper"

class RepliesControllerTest < ActionDispatch::IntegrationTest
  include SignInHelper

  def setup
    @memory = Memory.create!(
      date: Date.today, content: "x",
      name: "Author", email: "author@test.com", status: :published
    )
  end

  test "anonymous POST creates a pending reply" do
    assert_difference "Reply.count", 1 do
      post memory_replies_path(@memory), params: {
        reply: { name: "Visitor", body: "Beautiful.", email: "v@test.com" }
      }
    end
    reply = Reply.last
    assert_equal "pending", reply.status
    assert_nil reply.user
    assert_redirected_to memories_path
  end

  test "signed-in POST creates a published reply" do
    user = sign_in_contributor

    assert_difference "Reply.count", 1 do
      post memory_replies_path(@memory), params: {
        reply: { name: "Visitor", body: "Yes." }
      }
    end
    reply = Reply.last
    assert_equal "published", reply.status
    assert_equal user, reply.user
  end

  test "invalid reply redirects with errors" do
    post memory_replies_path(@memory), params: {
      reply: { name: "Visitor" }  # missing body and email
    }
    assert_redirected_to memories_path
    assert_match(/can't be blank/i, flash[:alert])
  end
end
