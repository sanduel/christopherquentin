admin = User.find_or_create_by!(email: "admin@christopherquentin.com") do |u|
  u.name = "Samuel"
  u.password = "password123"
  u.role = :admin
end
puts "Admin user: #{admin.email} (password: password123)"

# Sample data for development
if Rails.env.development?
  # ---- Memories ----
  memories_data = [
    { date: Date.new(2002, 9, 1), title: "Mass Row, Dartmouth", kind: "text",
      content: "Sept 2002, Mass Row dorm. Two weeks into freshman year and Chris already had a chamber group meeting in his common room every Thursday. He'd score the parts by hand, then pass them out before dinner.",
      location: "Hanover, NH" },
    { date: Date.new(2014, 6, 15), title: "Munich concert", kind: "text",
      content: "I'll never forget the evening Christopher conducted Beethoven's 7th in Munich. The energy in the room was electric — and after the second movement he caught my eye in the balcony and grinned.",
      location: "Munich, Germany" },
    { date: Date.new(2019, 5, 12), title: "Stavanger rehearsal", kind: "text",
      content: "Watching Chris rehearse Mahler with the Jæren Symfoniorkester. He stopped after eight bars to make a joke about the violas. Everyone laughed. Then the next phrase was perfect.",
      location: "Stavanger, Norway" },
  ]

  memories_data.each do |attrs|
    Memory.find_or_create_by!(date: attrs[:date], title: attrs[:title]) do |m|
      m.content = attrs[:content]
      m.location = attrs[:location]
      m.user = admin
      m.name = admin.name
      m.kind = attrs[:kind]
      m.status = :published
    end
  end

  # ---- Events ----
  events_data = [
    { title: "Chris's Memorial Call — five years on",
      event_type: :webinar,
      starts_at: Time.zone.local(2026, 8, 14, 10, 0),
      location: "Zoom (link emailed after RSVP)" },
    { title: "Jæren Symfoniorkester — Memorial Concert",
      event_type: :concert,
      starts_at: Time.zone.local(2026, 9, 12, 19, 30),
      location: "Jæren kulturhus, Bryne, Norway" },
    { title: "Dartmouth Conducting Endowment — annual recital",
      event_type: :service,
      starts_at: Time.zone.local(2026, 10, 23, 19, 0),
      location: "Spaulding Auditorium, Hanover, NH" },
  ]

  events_data.each do |attrs|
    Event.find_or_create_by!(title: attrs[:title]) do |e|
      e.event_type = attrs[:event_type]
      e.starts_at = attrs[:starts_at]
      e.location = attrs[:location]
      e.published = true
    end
  end

  # ---- Tributes ----
  tributes_data = [
    { name: "Margaret Thompson", relationship: "Family friend", category: "family",
      content: "Christopher was an extraordinary person who touched everyone he met with his warmth, humor, and incredible talent. His memory is a blessing." },
    { name: "James Anderson", relationship: "Dartmouth classmate", category: "students",
      content: "We shared a dorm room our sophomore year and I learned what it meant to truly love what you do. Chris would conduct in his sleep — literally, hands moving above the blankets." },
    { name: "Sigrid Olsen", relationship: "Colleague, Jæren Symfoniorkester", category: "musicians",
      content: "Chris's scintillating charisma and smiling authority inspired singers and musicians alike to surpass themselves. We carry his phrasings with us into every performance." },
    { name: "Anna Lee", relationship: "Student", category: "students",
      content: "He'd write notes in the margins of my scores that were half pedagogy, half love letters to the music. I still have them all." },
  ]

  tributes_data.each do |attrs|
    Tribute.find_or_create_by!(name: attrs[:name]) do |t|
      t.relationship = attrs[:relationship]
      t.content = attrs[:content]
      t.category = attrs[:category]
      t.status = :published
    end
  end

  # ---- Tree (existing) ----
  Tree.find_or_create_by!(name: "McMullen Family") do |t|
    t.email = "family@example.com"
    t.address = "Ann Arbor, Michigan"
    t.latitude = 42.2808
    t.longitude = -83.7430
    t.tree_count = 1
    t.story = "The first Chris tree, planted by his parents."
    t.status = :published
  end

  puts "Sample data created (#{Memory.count} memories, #{Event.count} events, #{Tribute.count} tributes, #{Tree.count} trees)."
end
