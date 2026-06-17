import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "step1", "step2", "stepLabel", "progress",
                    "backButton", "nextButton", "submitButton",
                    "photoInput", "audioInput", "kindInput", "attachments"]
  static values  = { currentStep: Number }

  connect() {
    this.photoInputTarget.addEventListener("change", () => this.handlePhotoSelect())
    this.audioInputTarget.addEventListener("change", () => this.handleAudioSelect())
    this.boundOpen = () => this.open()
    document.addEventListener("share-modal:open", this.boundOpen)
  }

  disconnect() {
    document.removeEventListener("share-modal:open", this.boundOpen)
  }

  open() {
    this.element.showModal()
    this.currentStepValue = 1
  }

  close() {
    if (this.isDirty() && !confirm("Discard this memory?")) return
    this.element.close()
    this.formTarget.reset()
    this.attachmentsTarget.textContent = ""
    this.currentStepValue = 1
  }

  next() {
    if (!this.validateStep1()) return
    this.currentStepValue = 2
  }

  back() {
    this.currentStepValue = 1
  }

  handlePhotoSelect() {
    if (this.photoInputTarget.files.length > 0) this.kindInputTarget.value = "photo"
    this.renderAttachments()
  }

  handleAudioSelect() {
    if (this.audioInputTarget.files.length > 0) this.kindInputTarget.value = "audio"
    this.renderAttachments()
  }

  renderAttachments() {
    const photoNames = Array.from(this.photoInputTarget.files).map(f => f.name)
    const audioName  = this.audioInputTarget.files[0]?.name
    const parts = []
    if (photoNames.length) parts.push(`Photos: ${photoNames.join(", ")}`)
    if (audioName)         parts.push(`Audio: ${audioName}`)
    this.attachmentsTarget.textContent = parts.join(" · ")
  }

  validateStep1() {
    const content = this.formTarget.querySelector("textarea[name='memory[content]']")
    const date    = this.formTarget.querySelector("input[name='memory[date]']")
    const hasAttachment = this.photoInputTarget.files.length > 0 || this.audioInputTarget.files.length > 0
    if (!hasAttachment && !content.value.trim()) {
      content.focus()
      return false
    }
    if (!date.value) {
      date.focus()
      return false
    }
    return true
  }

  isDirty() {
    // Inspect visible inputs/textareas; ignore hidden fields (kind, csrf, etc.).
    const inputs = this.formTarget.querySelectorAll("input:not([type='hidden']), textarea")
    for (const input of inputs) {
      if (input.type === "file") {
        if (input.files.length > 0) return true
      } else if (input.value && input.value.trim()) {
        return true
      }
    }
    return false
  }

  currentStepValueChanged() {
    const step = this.currentStepValue
    this.step1Target.hidden = step !== 1
    this.step2Target.hidden = step !== 2
    this.stepLabelTarget.textContent = `Step ${step} of 2 · ${step === 1 ? "The memory" : "About you"}`
    this.progressTarget.style.width = `${step * 50}%`
    this.backButtonTarget.hidden    = step !== 2
    this.nextButtonTarget.hidden    = step === 2
    this.submitButtonTarget.hidden  = step !== 2
  }
}
