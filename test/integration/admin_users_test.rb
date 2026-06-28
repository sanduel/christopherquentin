require "test_helper"

class AdminUsersTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "non-admin cannot access users index" do
    sign_in_contributor
    get admin_users_path
    assert_redirected_to root_path
  end

  test "admin can view users index" do
    admin = sign_in_admin
    contributor = User.create!(name: "Jane Doe", email: "jane@test.com", password: "password123", role: :contributor)

    get admin_users_path
    assert_response :success
    assert_select "body", text: /jane@test\.com/
    assert_select "body", text: /#{admin.email}/
    assert_not_nil contributor
  end

  test "admin can promote a contributor to admin" do
    sign_in_admin
    user = User.create!(name: "Jane Doe", email: "jane@test.com", password: "password123", role: :contributor)

    patch admin_user_path(user), params: { role: "admin" }
    assert_redirected_to admin_users_path
    assert_equal "admin", user.reload.role
  end

  test "admin can demote another admin to contributor" do
    sign_in_admin
    other = User.create!(name: "Bob Smith", email: "bob@test.com", password: "password123", role: :admin)

    patch admin_user_path(other), params: { role: "contributor" }
    assert_redirected_to admin_users_path
    assert_equal "contributor", other.reload.role
  end

  test "admin cannot demote themselves" do
    admin = sign_in_admin

    patch admin_user_path(admin), params: { role: "contributor" }
    assert_redirected_to admin_users_path
    assert_equal "admin", admin.reload.role
  end

  test "invalid role value is rejected" do
    sign_in_admin
    user = User.create!(name: "Jane Doe", email: "jane@test.com", password: "password123", role: :contributor)

    patch admin_user_path(user), params: { role: "superuser" }
    assert_equal "contributor", user.reload.role
  end
end
