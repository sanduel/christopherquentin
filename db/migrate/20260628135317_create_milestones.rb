class CreateMilestones < ActiveRecord::Migration[8.1]
  def change
    create_table :milestones do |t|
      t.date    :date,        null: false
      t.string  :headline,    null: false
      t.text    :description
      t.string  :icon
      t.string  :location

      t.timestamps
    end

    add_index :milestones, :date
  end
end
