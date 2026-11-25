# Proof that a submission came from a form this site rendered. The token is signed
# and carries its own render time, so it needs no session state (the footer form is
# on every page and Turbo prefetches pages, which would overwrite session state).
class FormRenderToken
  PARAM = "cq_ft".freeze
  # Faster than a person can reach the form, type an address and submit.
  MIN_AGE = 3.seconds
  MAX_AGE = 1.day

  def self.generate
    verifier.generate({ "rendered_at" => Time.current.to_f, "nonce" => SecureRandom.hex(12) }, expires_in: MAX_AGE)
  end

  # True at most once per token, and only between MIN_AGE and MAX_AGE after rendering.
  def self.redeem(token)
    payload = verifier.verified(token.to_s)
    return false unless payload.is_a?(Hash)
    return false if Time.current.to_f - payload["rendered_at"].to_f < MIN_AGE

    Rails.cache.write("form_render_token/#{payload["nonce"]}", true, expires_in: MAX_AGE, unless_exist: true)
  end

  def self.verifier
    Rails.application.message_verifier(:form_render_token)
  end
end
