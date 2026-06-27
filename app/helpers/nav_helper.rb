module NavHelper
  # Wraps link_to with active-state awareness: sets aria-current="page" and
  # applies accent blue when the current request URL matches `path`.
  def nav_link(label, path, extra_class: "")
    active = current_page?(path)
    classes = ["text-ink hover:text-accent transition-colors"]
    classes << "font-medium text-accent" if active
    classes << extra_class if extra_class.present?

    link_to label, path,
      class: classes.join(" "),
      "aria-current": (active ? "page" : nil)
  end
end
