module EventsHelper
  def event_zone_lines(time)
    return [] if time.blank?

    Event::DISPLAY_ZONES.map do |zone_name, label|
      zoned = time.in_time_zone(zone_name)
      formatted = zoned.strftime("%a %b %-d, %Y · %-l:%M %p %Z")
      "#{label}: #{formatted}"
    end
  end

  # Zone used for the server-rendered (no-JS) default; the timezone Stimulus
  # controller re-formats these in the visitor's chosen zone on the client.
  DEFAULT_DISPLAY_ZONE = Event::DISPLAY_ZONES.first[0]
  DEFAULT_DISPLAY_LABEL = Event::DISPLAY_ZONES.first[1]

  def event_date_tag(time, classes: nil)
    return "" if time.blank?

    timezone_datetime_tag(
      time, kind: "date", classes: classes,
      text: l(time.in_time_zone(DEFAULT_DISPLAY_ZONE), format: :event_date)
    )
  end

  def event_time_tag(time, classes: nil)
    return "" if time.blank?

    # Match the client: bare time plus the friendly zone label, so the displayed
    # zone doesn't flicker (e.g. "EDT" -> "ET") when the controller takes over.
    bare = l(time.in_time_zone(DEFAULT_DISPLAY_ZONE), format: :event_time_bare)
    timezone_datetime_tag(
      time, kind: "time", classes: classes, text: "#{bare} #{DEFAULT_DISPLAY_LABEL}"
    )
  end

  # Dropdown that lets the visitor pick which timezone the event times display
  # in. The "local" option is resolved to the browser's zone client-side.
  def event_timezone_select(classes: nil)
    options = Event::DISPLAY_ZONES.map { |zone, label| tag.option(label, value: zone) }
    options << tag.option("Your time", value: "local")

    tag.select(
      safe_join(options),
      class: classes,
      data: { timezone_target: "select", action: "timezone#change" }
    )
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

  private

  def timezone_datetime_tag(time, kind:, classes:, text:)
    tag.span(
      text,
      class: classes,
      data: { timezone_target: "datetime", format: kind, utc: time.utc.iso8601 }
    )
  end
end
