import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["composer"]

  toggle() {
    this.composerTarget.hidden = !this.composerTarget.hidden
  }

  close() {
    this.composerTarget.hidden = true
  }
}
