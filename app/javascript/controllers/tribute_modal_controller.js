import { Controller } from "@hotwired/stimulus"

// Opens a tribute's full text/video in a <dialog>. The card is a real link to
// the tribute's page, so without JS the click still navigates there.
// For video tributes the iframe src is set on open and cleared on close, so the
// player only loads when viewed and stops playing when the dialog is dismissed.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  open(event) {
    event.preventDefault()
    if (this.hasFrameTarget && this.frameTarget.dataset.src) {
      this.frameTarget.src = this.frameTarget.dataset.src
    }
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  backdropClose(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  // Bound to the dialog's native "close" event (button, backdrop, or Escape).
  reset() {
    if (this.hasFrameTarget) this.frameTarget.src = ""
  }
}
