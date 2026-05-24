class MapController < ApplicationController
  CATEGORIES = {
    tree:     ->(_) { Tree.published.mapped },
    event:    ->(_) { Event.published.mapped },
    memory:   ->(_) { Memory.published.mapped },
    bee_hive: ->(_) { BeeHive.published.mapped }
  }.freeze

  def index
    @pins = collect_pins
    @category_meta = CATEGORIES.keys.map do |key|
      klass = key.to_s.classify.constantize
      {
        key: key,
        label: key.to_s.humanize.pluralize,
        default_color: klass.default_pin_color,
        default_icon: klass.default_pin_icon
      }
    end
  end

  private

  def collect_pins
    pins = []
    CATEGORIES.each do |category, scope|
      scope.call(self).each do |record|
        pins << pin_payload(category, record)
      end
    end
    pins
  end

  def pin_payload(category, record)
    {
      category: category,
      id: record.id,
      title: pin_title(record),
      snippet: pin_snippet(record),
      latitude: record.latitude,
      longitude: record.longitude,
      color: record.effective_pin_color,
      icon_svg: render_icon_svg(record.effective_pin_icon),
      url: pin_url(category, record)
    }
  end

  def pin_title(record)
    return record.title if record.respond_to?(:title) && record.title.present?
    return record.name if record.respond_to?(:name) && record.name.present?
    "Memory"
  end

  def pin_snippet(record)
    if record.is_a?(Memory)
      record.content.to_s.truncate(140)
    elsif record.is_a?(Event)
      record.location.to_s
    else
      record.try(:story).to_s.truncate(140)
    end
  end

  def pin_url(category, record)
    case category
    when :tree     then tree_path(record)
    when :event    then event_path(record)
    when :memory   then chris_path(anchor: "memory-#{record.id}")
    when :bee_hive then bee_hive_path(record)
    end
  end

  def render_icon_svg(icon_name)
    helpers.icon(icon_name, library: "lucide", class: "w-5 h-5")
  rescue StandardError
    helpers.icon("map-pin", library: "lucide", class: "w-5 h-5")
  end
end
