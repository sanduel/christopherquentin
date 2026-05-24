module EventsHelper
  def event_zone_lines(time)
    return [] if time.blank?

    Event::DISPLAY_ZONES.map do |zone_name, label|
      zoned = time.in_time_zone(zone_name)
      formatted = zoned.strftime("%a %b %-d, %Y · %-l:%M %p %Z")
      "#{label}: #{formatted}"
    end
  end

  def event_type_label(event)
    event.event_type.titleize
  end

  def event_type_badge_classes(event)
    case event.event_type
    when "concert"
      "bg-blue-100 text-blue-900"
    when "webinar"
      "bg-stone-200 text-stone-700"
    end
  end
end
