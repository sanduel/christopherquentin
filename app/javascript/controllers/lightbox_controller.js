import { Controller } from "@hotwired/stimulus"

// Click any [data-lightbox-target="item"] to open an enlarged, navigable view
// of the photo set. Each item carries data-lightbox-src (the full-size image
// URL) and data-lightbox-caption. Prev/next buttons and the ←/→ keys page
// through the set; Escape and a backdrop click close it (native <dialog>).
export default class extends Controller {
  static targets = ["item", "dialog", "image", "caption"]

  open(event) {
    event.preventDefault()
    this.index = this.itemTargets.indexOf(event.currentTarget)
    this.show()
    this.dialogTarget.showModal()
  }

  next() {
    this.index = (this.index + 1) % this.itemTargets.length
    this.show()
  }

  prev() {
    this.index = (this.index - 1 + this.itemTargets.length) % this.itemTargets.length
    this.show()
  }

  key(event) {
    if (event.key === "ArrowRight") {
      event.preventDefault()
      this.next()
    } else if (event.key === "ArrowLeft") {
      event.preventDefault()
      this.prev()
    }
  }

  close() {
    this.dialogTarget.close()
  }

  // The dialog fills the screen, so a click rarely lands on the <dialog> element
  // itself. Close on any click outside the image and the control buttons.
  backdrop(event) {
    if (event.target === this.imageTarget) return
    if (event.target.closest("button")) return
    this.dialogTarget.close()
  }

  show() {
    const item = this.itemTargets[this.index]
    const caption = item.dataset.lightboxCaption || ""
    this.imageTarget.src = item.dataset.lightboxSrc
    this.imageTarget.alt = caption
    if (this.hasCaptionTarget) {
      this.captionTarget.textContent = caption
      this.captionTarget.classList.toggle("hidden", caption === "")
    }
  }
}
