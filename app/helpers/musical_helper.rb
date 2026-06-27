module MusicalHelper
  # Renders a Memorial mono uppercase eyebrow label.
  # Degrades gracefully from the Garden musical_eyebrow call signature:
  # with_rule: true prepends a short blue accent rule.
  def musical_eyebrow(text, with_rule: false)
    parts = []
    if with_rule
      parts << content_tag(:span, "", class: "inline-block w-7 h-px bg-accent mr-3.5 align-middle")
    end
    parts << text

    content_tag(:div,
      safe_join(parts),
      class: "text-eyebrow"
    )
  end

  # Tempo markings have no equivalent in the Memorial direction.
  # Returns empty string so existing view calls do not error.
  def tempo_marking(_text)
    ""
  end

  def chip_class(active:)
    base = "rounded-full px-4 py-1.5 text-sm whitespace-nowrap no-underline border transition-colors inline-block"
    if active
      "#{base} bg-ink text-white-bg border-ink"
    else
      "#{base} bg-transparent text-ink border-ink/22 hover:border-ink hover:text-accent"
    end
  end
end
