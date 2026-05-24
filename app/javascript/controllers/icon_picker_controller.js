import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "search", "grid", "option", "preview", "label"]
  static values = { default: String }

  connect() {
    this.refreshPreview()
  }

  filter(event) {
    const q = event.target.value.trim().toLowerCase()
    this.optionTargets.forEach(btn => {
      const name = btn.dataset.iconName
      btn.style.display = (q === "" || name.includes(q)) ? "" : "none"
    })
  }

  select(event) {
    const btn = event.currentTarget
    this.inputTarget.value = btn.dataset.iconName
    this.refreshPreview()
  }

  reset() {
    this.inputTarget.value = ""
    this.refreshPreview()
  }

  refreshPreview() {
    const current = this.inputTarget.value || this.defaultValue
    const source = this.optionTargets.find(b => b.dataset.iconName === current)
    while (this.previewTarget.firstChild) {
      this.previewTarget.removeChild(this.previewTarget.firstChild)
    }
    if (source) {
      const sourceSvg = source.querySelector("svg")
      if (sourceSvg) this.previewTarget.appendChild(sourceSvg.cloneNode(true))
    }
    this.labelTarget.textContent = this.inputTarget.value
      ? `${current} (override)`
      : `${current} (default)`

    this.optionTargets.forEach(btn => {
      btn.classList.toggle("bg-blue-100", btn.dataset.iconName === current)
      btn.classList.toggle("border-blue-300", btn.dataset.iconName === current)
    })
  }
}
