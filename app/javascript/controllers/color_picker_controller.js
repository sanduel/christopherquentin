import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "useDefault"]

  toggle() {
    this.inputTarget.disabled = this.useDefaultTarget.checked
  }
}
