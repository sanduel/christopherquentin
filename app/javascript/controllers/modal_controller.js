import { Controller } from "@hotwired/stimulus"

// Generic <dialog> modal. Put data-controller="modal" on a wrapper that
// contains a [data-modal-target="dialog"] <dialog> and any number of
// data-action="modal#open" / "modal#close" buttons.
export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
  }

  close() {
    this.dialogTarget.close()
  }

  // Close when the backdrop (the dialog element itself) is clicked.
  backdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
