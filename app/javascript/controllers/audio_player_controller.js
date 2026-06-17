import WaveSurfer from "wavesurfer.js"
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["waveform", "playButton", "duration"]
  static values  = { url: String }

  connect() {
    this.ws = WaveSurfer.create({
      container: this.waveformTarget,
      waveColor: "rgba(250,246,238,0.4)",
      progressColor: "rgba(250,246,238,1)",
      cursorColor: "transparent",
      barWidth: 2,
      barGap: 2,
      barRadius: 0,
      height: 16,
      url: this.urlValue,
    })
    this.ws.on("finish", () => this.playButtonTarget.textContent = "▶")
  }

  toggle() {
    if (!this.ws) return
    if (this.ws.isPlaying()) {
      this.ws.pause()
      this.playButtonTarget.textContent = "▶"
    } else {
      this.ws.play()
      this.playButtonTarget.textContent = "⏸"
    }
  }

  disconnect() {
    this.ws?.destroy()
  }
}
