class PressItem
  attr_reader :date, :source, :title, :snippet, :kind, :url

  def initialize(attrs)
    @date    = attrs["date"]
    @source  = attrs["source"]
    @title   = attrs["title"]
    @snippet = attrs["snippet"]
    @kind    = attrs["kind"]
    @url     = attrs["url"]
  end

  def self.all
    @all ||= load_items
  end

  def self.years
    all.map(&:year).compact.uniq.sort.reverse
  end

  def self.grouped_by_year
    all.group_by(&:year).sort_by { |year, _| -(year || 0) }
  end

  def year
    date&.year
  end

  def undated?
    date.nil?
  end

  def self.reload!
    @all = nil
  end

  def self.load_items
    raw = YAML.load_file(Rails.root.join("config/press_items.yml"), permitted_classes: [ Date ])
    raw.map { |attrs| new(attrs) }
  end
end
