import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["map", "filter"]
  static values  = { pins: String }

  async connect() {
    const L = await import("https://unpkg.com/leaflet@1.9.4/dist/leaflet-src.esm.js")
    this.L = L

    this.map = L.map(this.mapTarget).setView([20, 0], 2)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 18
    }).addTo(this.map)

    const pins = JSON.parse(this.pinsValue || "[]")
    this.layers = { tree: L.layerGroup(), event: L.layerGroup(), memory: L.layerGroup(), bee_hive: L.layerGroup() }
    Object.values(this.layers).forEach(layer => layer.addTo(this.map))

    const bounds = []
    pins.forEach(pin => {
      if (pin.latitude == null || pin.longitude == null) return
      const marker = L.marker([pin.latitude, pin.longitude], { icon: this.buildDivIcon(pin) })
      marker.bindPopup(this.popupHtml(pin))
      this.layers[pin.category]?.addLayer(marker)
      bounds.push([pin.latitude, pin.longitude])
    })

    if (bounds.length > 0) {
      this.map.fitBounds(bounds, { padding: [50, 50], maxZoom: 8 })
    }
  }

  toggleCategory(event) {
    const cat = event.currentTarget.dataset.category
    const layer = this.layers?.[cat]
    if (!layer) return
    if (event.currentTarget.checked) {
      layer.addTo(this.map)
    } else {
      this.map.removeLayer(layer)
    }
  }

  buildDivIcon(pin) {
    const html = `
      <div class="map-pin" style="background-color:${pin.color}">
        ${pin.icon_svg}
      </div>`
    return this.L.divIcon({
      html,
      className: "map-pin-wrapper",
      iconSize: [32, 32],
      iconAnchor: [16, 32],
      popupAnchor: [0, -28]
    })
  }

  popupHtml(pin) {
    const safe = (s) => (s == null ? "" : String(s).replace(/[<>&"']/g, c =>
      ({ "<": "&lt;", ">": "&gt;", "&": "&amp;", "\"": "&quot;", "'": "&#39;" }[c])))
    return `
      <strong>${safe(pin.title)}</strong>
      <div class="text-xs uppercase opacity-70 mb-1">${safe(pin.category.replace("_", " "))}</div>
      ${pin.snippet ? `<p>${safe(pin.snippet)}</p>` : ""}
      ${pin.url ? `<p><a href="${safe(pin.url)}" class="underline">View</a></p>` : ""}
    `
  }
}
