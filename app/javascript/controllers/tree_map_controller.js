import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { trees: String }

  connect() {
    this.loadLeaflet()
  }

  async loadLeaflet() {
    const L = await import("https://unpkg.com/leaflet@1.9.4/dist/leaflet-src.esm.js")

    const map = L.map(this.element).setView([30, 0], 2)
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
      maxZoom: 18
    }).addTo(map)

    const trees = JSON.parse(this.treesValue)
    if (trees.length === 0) return

    const bounds = []
    trees.forEach(tree => {
      if (tree.latitude && tree.longitude) {
        const marker = L.marker([tree.latitude, tree.longitude]).addTo(map)
        marker.bindPopup(`
          <strong>${tree.name}</strong><br>
          ${tree.tree_count} tree${tree.tree_count > 1 ? 's' : ''} planted<br>
          ${tree.story ? `<em>${tree.story.substring(0, 100)}${tree.story.length > 100 ? '...' : ''}</em>` : ''}
        `)
        bounds.push([tree.latitude, tree.longitude])
      }
    })

    if (bounds.length > 0) {
      map.fitBounds(bounds, { padding: [50, 50], maxZoom: 10 })
    }
  }
}
