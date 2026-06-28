import { Controller } from "@hotwired/stimulus"

// Re-formats event date/time elements into a visitor-chosen timezone.
// Each datetime target carries `data-utc` (ISO) and `data-format` ("date"|"time").
// The select offers the curated display zones plus a "local" option resolved
// to the browser's own timezone. The choice persists in localStorage.
export default class extends Controller {
  static targets = ["select", "datetime"]

  static STORAGE_KEY = "preferredEventZone"

  connect() {
    this.labelLocalOption()
    this.restoreSelection()
    this.render()
  }

  change() {
    if (this.hasSelectTarget) this.writeStored(this.selectTarget.value)
    this.render()
  }

  // Resolve the active IANA zone: "local" maps to the browser's timezone.
  get zone() {
    const value = this.hasSelectTarget ? this.selectTarget.value : "local"
    return value === "local" ? this.browserZone : value
  }

  get browserZone() {
    try {
      return Intl.DateTimeFormat().resolvedOptions().timeZone
    } catch {
      return "America/New_York"
    }
  }

  // The friendly zone label shown alongside the time. For a curated display
  // zone this is the dropdown's own label (ET / London / Berlin); for the local
  // option it's the browser's short zone name (e.g. GMT+9), which Intl provides
  // reliably even where it won't give a curated abbreviation.
  get activeLabel() {
    const option = this.hasSelectTarget ? this.selectTarget.selectedOptions[0] : null
    if (option && option.value !== "local") return option.textContent.trim()
    return this.localAbbrev()
  }

  localAbbrev() {
    const fmt = new Intl.DateTimeFormat("en-US", {
      timeZone: this.browserZone,
      hour: "numeric",
      timeZoneName: "short",
    })
    return partsOf(fmt, new Date()).timeZoneName || this.browserZone
  }

  render() {
    const zone = this.zone
    const label = this.activeLabel
    // Build one formatter per shape and reuse it across every element, rather
    // than constructing a fresh (expensive) Intl.DateTimeFormat per element.
    const dateFmt = new Intl.DateTimeFormat("en-US", {
      timeZone: zone,
      weekday: "long",
      month: "short",
      day: "numeric",
      year: "numeric",
    })
    const timeFmt = new Intl.DateTimeFormat("en-US", {
      timeZone: zone,
      hour: "numeric",
      minute: "2-digit",
      hour12: true,
    })

    this.datetimeTargets.forEach((el) => {
      const iso = el.dataset.utc
      if (!iso) return
      const date = new Date(iso)
      if (isNaN(date)) return
      el.textContent =
        el.dataset.format === "time"
          ? formatTime(timeFmt, date, label)
          : formatDate(dateFmt, date)
    })
  }

  labelLocalOption() {
    if (!this.hasSelectTarget) return
    const local = Array.from(this.selectTarget.options).find((o) => o.value === "local")
    if (local) local.textContent = `Your time (${this.browserZone})`
  }

  restoreSelection() {
    if (!this.hasSelectTarget) return
    const saved = this.readStored()
    if (!saved) return
    const exists = Array.from(this.selectTarget.options).some((o) => o.value === saved)
    if (exists) this.selectTarget.value = saved
  }

  // localStorage access can throw (Safari private mode, blocked cookies), not
  // just return null — so guard reads and writes; persistence is best-effort.
  readStored() {
    try {
      return window.localStorage?.getItem(this.constructor.STORAGE_KEY)
    } catch {
      return null
    }
  }

  writeStored(value) {
    try {
      window.localStorage?.setItem(this.constructor.STORAGE_KEY, value)
    } catch {
      // Storage unavailable — the dropdown still works for this page view.
    }
  }
}

function formatDate(formatter, date) {
  const p = partsOf(formatter, date)
  return `${p.weekday} ${p.month} ${p.day}, ${p.year}`
}

function formatTime(formatter, date, label) {
  const p = partsOf(formatter, date)
  return `${p.hour}:${p.minute} ${p.dayPeriod} ${label}`
}

function partsOf(formatter, date) {
  return formatter.formatToParts(date).reduce((acc, part) => {
    acc[part.type] = part.value
    return acc
  }, {})
}
