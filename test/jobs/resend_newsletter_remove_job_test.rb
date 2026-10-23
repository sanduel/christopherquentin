require "test_helper"

class ResendNewsletterRemoveJobTest < ActiveJob::TestCase
  include NewsletterHelper

  test "removing a contact Resend doesn't have finishes quietly" do
    stub_request(:delete, resend_segment_membership_url("gone@test.com"))
      .to_return(status: 404, body: { statusCode: 404, name: "not_found", message: "Contact not found" }.to_json,
                 headers: { "Content-Type" => "application/json" })

    assert_nothing_raised { ResendNewsletterRemoveJob.perform_now("gone@test.com") }
    assert_no_enqueued_jobs
  end
end
