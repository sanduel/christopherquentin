# Honeypot only. The timestamp and spinner checks keep per-session state that is
# overwritten whenever any page renders a form (the newsletter footer is on every
# page, and Turbo prefetches pages on link hover), which rejects real visitors.
InvisibleCaptcha.setup do |config|
  config.timestamp_enabled = false
  config.spinner_enabled = false
end
