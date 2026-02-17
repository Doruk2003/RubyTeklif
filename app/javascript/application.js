// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import { Turbo } from "@hotwired/turbo-rails"
import "controllers"
import { initCustomSelects } from "custom_select"

function showAppConfirm(message, opts = {}) {
  const title = opts.title || "Onay"
  const okText = opts.okText || "Evet"
  const cancelText = opts.cancelText || "Hayır"

  return new Promise((resolve) => {
    const overlay = document.createElement("div")
    overlay.className = "app-confirm-overlay"
    overlay.innerHTML = `
      <div class="app-confirm-dialog" role="dialog" aria-modal="true" aria-labelledby="app-confirm-title" aria-describedby="app-confirm-message">
        <div class="app-confirm-title" id="app-confirm-title"></div>
        <div class="app-confirm-message" id="app-confirm-message"></div>
        <div class="app-confirm-actions">
          <button type="button" class="btn-secondary app-confirm-cancel"></button>
          <button type="button" class="btn-primary app-confirm-ok"></button>
        </div>
      </div>
    `

    const titleEl = overlay.querySelector("#app-confirm-title")
    const messageEl = overlay.querySelector("#app-confirm-message")
    const okBtn = overlay.querySelector(".app-confirm-ok")
    const cancelBtn = overlay.querySelector(".app-confirm-cancel")

    titleEl.textContent = title
    messageEl.textContent = message
    okBtn.textContent = okText
    cancelBtn.textContent = cancelText

    const close = (accepted) => {
      document.removeEventListener("keydown", onKeyDown)
      overlay.remove()
      resolve(accepted)
    }

    const onKeyDown = (event) => {
      if (event.key === "Escape") close(false)
      if (event.key === "Enter") close(true)
    }

    okBtn.addEventListener("click", () => close(true))
    cancelBtn.addEventListener("click", () => close(false))
    overlay.addEventListener("click", (event) => {
      if (event.target === overlay) close(false)
    })

    document.addEventListener("keydown", onKeyDown)
    document.body.appendChild(overlay)
    okBtn.focus()
  })
}

Turbo.setConfirmMethod((message, element) => {
  const title = element?.dataset?.confirmTitle || "Onay"
  const okText = element?.dataset?.confirmOk || "Evet"
  const cancelText = element?.dataset?.confirmCancel || "Hayır"
  return showAppConfirm(message, { title, okText, cancelText })
})

function defaultConfirmMessageFor(label) {
  const text = (label || "").toLocaleLowerCase("tr-TR")

  if (/arşiv|arsiv|sil|kaldır|kaldir|kapat/.test(text)) {
    return "Bu işlemi onaylıyor musunuz?"
  }

  if (/geri yükle|geri yukle|restore|aktif et|pasif et/.test(text)) {
    return "Bu kaydı geri yüklemek istiyor musunuz?"
  }

  if (/kaydet|güncelle|guncelle|oluştur|olustur|update|create/.test(text)) {
    return "Değişiklikleri kaydetmek istiyor musunuz?"
  }

  return null
}

function elementLabel(element) {
  if (!element) return ""

  const tip = element.dataset?.tip
  const aria = element.getAttribute("aria-label")
  const title = element.getAttribute("title")
  const value = element.value
  const text = element.textContent

  return [tip, aria, title, value, text].find((v) => typeof v === "string" && v.trim().length > 0)?.trim() || ""
}

function applyAutoConfirmDefaults(root = document) {
  const candidates = root.querySelectorAll("a, button, input[type='submit']")

  candidates.forEach((el) => {
    if (el.dataset?.turboConfirm) return
    if (el.closest("body.auth-page")) return

    const method = (el.dataset?.turboMethod || "").toLowerCase()
    const isMutatingMethod = method === "delete" || method === "patch" || method === "post" || method === "put"
    const isPrimarySubmit = el.matches("button[type='submit'].btn-primary, input[type='submit'].btn-primary")
    if (!isMutatingMethod && !isPrimarySubmit) return

    const label = elementLabel(el)
    const message = defaultConfirmMessageFor(label)
    if (!message) return

    el.dataset.turboConfirm = message
  })
}

function initFilterPanelToggles(root = document) {
  const toggles = root.querySelectorAll("[data-filter-panel-toggle]")

  toggles.forEach((toggle) => {
    if (toggle.dataset.filterInit === "1") return

    const panelSelector = toggle.dataset.filterPanelTarget
    const panel = panelSelector
      ? document.querySelector(panelSelector)
      : (toggle.closest(".min-h-screen, main, body") || document).querySelector("[data-filter-panel]")

    if (!panel) return

    const icon = toggle.querySelector("[data-filter-panel-icon]")
    toggle.dataset.filterInit = "1"

    const setPanelState = (open) => {
      panel.classList.toggle("hidden", !open)
      toggle.setAttribute("aria-expanded", open ? "true" : "false")
      toggle.dataset.tip = open ? "Filtreleri Kapat" : "Filtreleri Aç"
      toggle.setAttribute("aria-label", open ? "Filtreleri Kapat" : "Filtreleri Aç")
      if (icon) {
        icon.textContent = "filter_list"
        icon.classList.toggle("is-open", open)
      }
    }

    setPanelState(!panel.classList.contains("hidden"))
    toggle.addEventListener("click", () => {
      setPanelState(panel.classList.contains("hidden"))
    })
  })
}

document.addEventListener("turbo:load", () => {
  initCustomSelects()
  applyAutoConfirmDefaults()
  initFilterPanelToggles()
})
