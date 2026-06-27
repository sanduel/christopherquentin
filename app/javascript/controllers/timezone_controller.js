import { Controller } from "@hotwired/stimulus"

// Re-formats event date/time elements into a visitor-chosen timezone.
// Each datetime target carries `data-utc` (ISO) and `data-format` ("date"|"time").
// The select offers the curated display zones plus a "local" option resolved
// to the browser's own timezone. Choice persists in localStorage.
export default class extends Controller {
  static targets = ["select", "datetime"]

  static STORAGE_KEY = "preferredEventZone"

  connect() {
    this.labelLocalOption()
    this.restoreSelection()
    this.render()
  }

  change() {
    if (this.hasSelectTarget) {
      window.localStorage?.setItem(this.constructor.STORAGE_KEY, this.selectTarget.value)
    }
    this.render()
  }

  // Resolve the active IANA zone: "local" maps to the browser's timezone.
  get zone() {
    const value = this.hasSelectTarget ? this.selectTarget.value : "local"
    if (value === "local") return this.browserZone
    return value
  }

  get browserZone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone
    } catch {
      return "America/New_York"
    }
  }

  labelLocalOption() {
    if (!this.hasSelectTarget) return
    const local = Array.from(this.selectTarget.options).find((o) => o.value === "local")
    if (local) local.textContent = `Your time (${this.browserZone})`
  }

  restoreSelection() {
    if (!this.hasSelectTarget) return
    const saved = window.localStorage?.getItem(this.constructor.STORAGE_KEY)
    if (!saved) return
    const exists = Array.from(this.selectTarget.options).some((o) => o.value === saved)
    if (exists) this.selectTarget.value = saved
  }

  render() {
    const zone = this.zone
    const label = this.activeLabel
    this.datetimeTargets.forEach((el) => {
      const iso = el.dataset.utc
      if (!iso) return
      const date = new Date(iso)
      if (isNaN(date)) return
      el.textContent =
        el.dataset.format === "time"
          ? this.formatTime(date, zone, label)
          : this.formatDate(date, zone)
    })
  }

  // The friendly zone label to show alongside the time. For a curated display
  // zone this is the dropdown's own label (ET / London / Berlin); for the local
  // option it's the browser's short zone name (e.g. GMT+9), which Intl provides
  // reliably even where it won't give a curated abbreviation.
  get activeLabel() {
    if (!this.hasSelectTarget) return this.localAbbrev()
    const option = this.selectTarget.selectedOptions[0]
    if (!option) return this.localAbbrev()
    if (option.value === "local") return this.localAbbrev()
    return option.textContent.trim()
  }

  localAbbrev() {
    const parts = this.parts(new Date(), {
      timeZone: this.browserZone,
      hour: "numeric",
      timeZoneName: "short",
    })
    return parts.timeZoneName || this.browserZone
  }

  formatDate(date, timeZone) {
    const parts = this.parts(date, {
      timeZone,
      weekday: "long",
      month: "short",
      day: "numeric",
      year: "numeric",
    })
    return `${parts.weekday} ${parts.month} ${parts.day}, ${parts.year}`
  }

  formatTime(date, timeZone, label) {
    const parts = this.parts(date, {
      timeZone,
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    })
    return `${parts.hour}:${parts.minute} ${parts.dayPeriod} ${label}`
  }

  parts(date, options) {
    return new Intl.DateTimeFormat("en-US", options)
      .formatToParts(date)
      .reduce((acc, part) => {
        acc[part.type] = part.value
        return acc
      }, {})
  }
}
