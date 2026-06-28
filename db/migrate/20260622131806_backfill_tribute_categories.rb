class BackfillTributeCategories < ActiveRecord::Migration[8.1]
  def up
    {
      "Margaret Thompson" => 0,  # family
      "James Anderson"    => 3,  # students
      "Sigrid Olsen"      => 2,  # musicians
      "Anna Lee"          => 3  # students
    }.each do |name, category|
      execute "UPDATE tributes SET category = #{category} WHERE name = '#{name}'"
    end
  end

  def down
    # No-op
  end
end
