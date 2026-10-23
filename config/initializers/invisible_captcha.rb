# Honeypot only. The timestamp and spinner checks keep per-session state that is
# overwritten whenever any page renders a form (the newsletter footer is on every
# page, and Turbo prefetches pages on link hover), which rejects real visitors.
InvisibleCaptcha.setup do |config|
  # Fixed names: the gem's default is random per process, so forms rendered before a
  # deploy or restart would no longer be checked. Kept meaningless so browser
  # autofill never fills them in for a real visitor.
  config.honeypots = %w[cq_hp_7f3a cq_hp_b91e]
  config.timestamp_enabled = false
  config.spinner_enabled = false
end
