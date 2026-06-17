require "test_helper"

class ShareModalTest < ActionDispatch::IntegrationTest
  include SignInHelper

  test "share modal is present in the application layout on the homepage" do
    get root_path
    assert_select "dialog#share-modal[data-controller='share-modal']"
  end

  test "share modal is present on the timeline page" do
    get memories_path
    assert_select "dialog#share-modal"
  end

  test "homepage Share a memory button is wired to open the modal" do
    get root_path
    assert_select "button[data-controller~='share-modal-trigger']", minimum: 1
  end

  test "GET /timeline/new renders timeline with auto-open controller" do
    get new_memory_path
    assert_response :success
    assert_select "[data-controller~='auto-open-share-modal']"
  end

  test "modal has step 1 form fields visible by default" do
    get root_path
    assert_select "[data-share-modal-target='step1']" do
      assert_select "textarea[name='memory[content]']"
      assert_select "input[name='memory[date]']"
      assert_select "input[name='memory[location]']"
    end
  end

  test "modal has step 2 form fields hidden by default" do
    get root_path
    assert_select "[data-share-modal-target='step2'][hidden]" do
      assert_select "input[name='memory[name]']"
      assert_select "input[name='memory[relationship]']"
    end
  end

  test "anonymous modal shows email field on step 2" do
    get root_path
    assert_select "[data-share-modal-target='step2'] input[name='memory[email]']"
  end

  test "signed-in modal hides email field on step 2" do
    user = sign_in_contributor
    get root_path
    assert_select "[data-share-modal-target='step2'] input[name='memory[email]']", 0
  end

  test "modal form posts to memories_path with multipart" do
    get root_path
    assert_select "dialog#share-modal form[action=?][enctype='multipart/form-data']", memories_path
  end
end
