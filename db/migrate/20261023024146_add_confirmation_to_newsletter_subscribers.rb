class AddConfirmationToNewsletterSubscribers < ActiveRecord::Migration[8.1]
  def up
    add_column :newsletter_subscribers, :confirmed_at, :datetime
    add_column :newsletter_subscribers, :confirmation_sent_at, :datetime
    # Emails are now normalized on save; bring existing rows in line. Fails on the
    # unique index if two rows differ only by case, rather than silently merging them.
    execute "UPDATE newsletter_subscribers SET email = LOWER(TRIM(email))"
  end

  def down
    remove_column :newsletter_subscribers, :confirmation_sent_at
    remove_column :newsletter_subscribers, :confirmed_at
  end
end
