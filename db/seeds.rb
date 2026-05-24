admin = User.find_or_create_by!(email: "admin@christopherquentin.com") do |u|
  u.name = "Samuel"
  u.password = "password123"
  u.role = :admin
end
puts "Admin user: #{admin.email} (password: password123)"

# Sample data for development
if Rails.env.development?
  Tribute.find_or_create_by!(name: "Sample Tribute") do |t|
    t.relationship = "Friend"
    t.content = "Christopher was an extraordinary person who touched everyone he met with his warmth, humor, and incredible talent."
    t.status = :published
  end

  Memory.find_or_create_by!(date: Date.new(2015, 6, 1), title: "Munich concert") do |m|
    m.content = "I'll never forget the evening Christopher conducted Beethoven's 7th in Munich. The energy in the room was electric."
    m.user = admin
    m.status = :published
  end

  Tree.find_or_create_by!(name: "McMullen Family") do |t|
    t.email = "family@example.com"
    t.address = "Ann Arbor, Michigan"
    t.latitude = 42.2808
    t.longitude = -83.7430
    t.tree_count = 1
    t.story = "The first Chris tree, planted by his parents."
    t.status = :published
  end

  Recipe.find_or_create_by!(title: "Feta-Watermelon Salad") do |r|
    r.submitter_name = "Samuel"
    r.ingredients = "Watermelon, cubed\nFeta cheese, crumbled\nFresh mint\nOlive oil\nLime juice"
    r.instructions = "Cube the watermelon. Crumble feta over top. Tear mint leaves and scatter. Drizzle with olive oil and lime juice."
    r.status = :published
  end

  puts "Sample data created."
end
