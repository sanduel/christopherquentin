namespace :tributes do
  desc "Reject all pending tributes (hides them from the public site; reversible)"
  task reject_pending: :environment do
    n = Tribute.pending.update_all(status: Tribute.statuses[:rejected], updated_at: Time.current)
    puts "Rejected #{n} pending tribute(s). They are hidden but kept in the database."
  end
end
