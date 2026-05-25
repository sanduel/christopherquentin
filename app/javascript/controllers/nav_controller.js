import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "toggle"]

  toggle() {
    const isOpen = !this.menuTarget.classList.contains("hidden")
    this.menuTarget.classList.toggle("hidden")
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", String(!isOpen))
      this.toggleTarget.setAttribute("aria-label", isOpen ? "Open menu" : "Close menu")
    }
  }
}
