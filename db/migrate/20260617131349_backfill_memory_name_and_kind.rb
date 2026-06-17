class BackfillMemoryNameAndKind < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE memories
      SET name = COALESCE(name,
        (SELECT users.name FROM users WHERE users.id = memories.user_id),
        'Anonymous')
      WHERE name IS NULL;
    SQL

    execute <<~SQL
      UPDATE memories
      SET kind = 1
      WHERE id IN (
        SELECT DISTINCT record_id
        FROM active_storage_attachments
        WHERE record_type = 'Memory' AND name = 'photos'
      ) AND kind = 0;
    SQL
  end

  def down
    # forward-only
  end
end
