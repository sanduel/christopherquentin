module ApplicationHelper
  def form_render_token_tag
    hidden_field_tag FormRenderToken::PARAM, FormRenderToken.generate, id: nil
  end
end
