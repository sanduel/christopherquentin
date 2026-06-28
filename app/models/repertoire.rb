class Repertoire
  Group = Struct.new(:composer, :works)

  def self.conducted
    load_data[:conducted]
  end

  def self.assisted
    load_data[:assisted]
  end

  def self.reload!
    @load_data = nil
  end

  def self.load_data
    @load_data ||= begin
      raw = YAML.load_file(Rails.root.join("config/repertoire.yml"))
      {
        conducted: raw["conducted"].map { |g| Group.new(g["composer"], g["works"]) },
        assisted:  raw["assisted"].map { |g| Group.new(g["composer"], g["works"]) }
      }
    end
  end
end
