module MusicalHelper
  # Renders the small mono uppercase eyebrow label used for opus numbers,
  # movement markers, and section metadata.
  #
  # Pass with_rule: true to prepend a short horizontal sage rule
  # (used in the Hero "Op. 1984 — In Memoriam" position).
  def musical_eyebrow(text, with_rule: false)
    parts = []
    if with_rule
      parts << content_tag(:span, "", class: "inline-block w-7 h-px bg-sage mr-3.5 align-middle")
    end
    parts << text

    content_tag(:div,
      safe_join(parts),
      class: "text-eyebrow text-sage flex items-center"
    )
  end

  # Renders an italic Cormorant tempo marking in rose — used after section
  # titles ("— andante con moto").
  def tempo_marking(text)
    content_tag(:span, "— #{text}",
      class: "font-serif italic text-[22px] text-rose"
    )
  end

  def chip_class(active:)
    base = "rounded-full px-4 py-1.5 text-sm whitespace-nowrap no-underline border transition-colors inline-block"
    if active
      "#{base} bg-moss text-cream border-moss"
    else
      "#{base} bg-transparent text-ink border-ink/20 hover:border-moss hover:text-moss"
    end
  end
end
