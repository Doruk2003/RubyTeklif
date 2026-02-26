const ROOT_ATTR = "data-rt-custom-select"

function closeAllCustomSelects(except = null) {
  document.querySelectorAll(`[${ROOT_ATTR}]`).forEach((root) => {
    if (except && root === except) return
    root.classList.remove("is-open")
    const searchInput = root.querySelector(".rt-custom-select-search")
    if (searchInput) searchInput.value = ""
    // Reset visibility of all options
    root.querySelectorAll(".rt-custom-select-option").forEach(opt => opt.style.display = "")
  })
}

function syncState(root, select, trigger, menu) {
  const selectedOption = select.options[select.selectedIndex]
  const hasValue = !!(selectedOption && selectedOption.value !== "")
  trigger.querySelector(".rt-custom-select-label").textContent = hasValue ? selectedOption.text : (select.dataset.placeholder || "")
  root.classList.toggle("has-value", hasValue)
  root.classList.toggle("is-empty", !hasValue)

  menu.querySelectorAll(".rt-custom-select-option").forEach((optionButton) => {
    const active = optionButton.dataset.value === select.value
    optionButton.classList.toggle("is-active", active)
    optionButton.setAttribute("aria-selected", active ? "true" : "false")
  })
}

function buildCustomSelect(select) {
  if (select.multiple) return
  if (select.closest(`[${ROOT_ATTR}]`)) return
  if (select.dataset.nativeSelect === "true") return

  const root = document.createElement("div")
  root.setAttribute(ROOT_ATTR, "true")
  root.className = "rt-custom-select"

  const trigger = document.createElement("button")
  trigger.type = "button"
  const classesToKeep = Array.from(select.classList).filter(c => c.startsWith("form-select") || c === "w-100" || c === "form-input")
  trigger.className = `rt-custom-select-trigger ${classesToKeep.join(" ")}`
  trigger.setAttribute("aria-haspopup", "listbox")
  trigger.setAttribute("aria-expanded", "false")
  trigger.innerHTML = '<span class="rt-custom-select-label"></span><span class="rt-custom-select-arrow">▾</span>'

  const menu = document.createElement("div")
  menu.className = "rt-custom-select-menu"
  menu.setAttribute("role", "listbox")

  // Add search if options > 5
  if (select.options.length > 5) {
    const searchContainer = document.createElement("div")
    searchContainer.className = "rt-custom-select-search-container p-2 border-bottom sticky-top bg-white"
    const searchInput = document.createElement("input")
    searchInput.type = "text"
    searchInput.className = "form-control form-control-sm rt-custom-select-search"
    searchInput.placeholder = "Ara..."
    searchInput.autocomplete = "off"
    
    searchInput.addEventListener("click", (e) => e.stopPropagation())
    searchInput.addEventListener("input", (e) => {
      const term = e.target.value.toLocaleLowerCase("tr-TR")
      menu.querySelectorAll(".rt-custom-select-option").forEach((opt) => {
        const text = opt.textContent.toLocaleLowerCase("tr-TR")
        opt.style.display = text.includes(term) ? "" : "none"
      })
    })

    searchContainer.appendChild(searchInput)
    menu.appendChild(searchContainer)
  }

  const optionsContainer = document.createElement("div")
  optionsContainer.className = "rt-custom-select-options-list"
  optionsContainer.style.maxHeight = "300px"
  optionsContainer.style.overflowY = "auto"

  Array.from(select.options).forEach((option) => {
    if (option.hidden) return
    const item = document.createElement("button")
    item.type = "button"
    item.className = "rt-custom-select-option rt-arrow-hover"
    item.dataset.value = option.value
    item.textContent = option.text
    item.setAttribute("role", "option")

    if (option.disabled) {
      item.disabled = true
      item.classList.add("is-disabled")
    }

    item.addEventListener("click", (e) => {
      e.stopPropagation()
      if (item.disabled) return
      select.value = item.dataset.value
      select.dispatchEvent(new Event("change", { bubbles: true }))
      syncState(root, select, trigger, menu)
      root.classList.remove("is-open")
      trigger.setAttribute("aria-expanded", "false")
    })

    optionsContainer.appendChild(item)
  })

  menu.appendChild(optionsContainer)
  select.classList.add("rt-native-select-hidden")
  select.parentNode.insertBefore(root, select)
  root.appendChild(select)
  root.appendChild(trigger)
  root.appendChild(menu)

  trigger.addEventListener("click", (e) => {
    e.stopPropagation()
    const isOpen = root.classList.contains("is-open")
    if (isOpen) {
      root.classList.remove("is-open")
      trigger.setAttribute("aria-expanded", "false")
      return
    }
    closeAllCustomSelects(root)
    root.classList.add("is-open")
    trigger.setAttribute("aria-expanded", "true")
    
    // Auto focus search
    const searchInput = menu.querySelector(".rt-custom-select-search")
    if (searchInput) setTimeout(() => searchInput.focus(), 50)
  })

  select.addEventListener("change", () => syncState(root, select, trigger, menu))
  syncState(root, select, trigger, menu)
}

export function initCustomSelects() {
  document.querySelectorAll("select").forEach(buildCustomSelect)
}

document.addEventListener("turbo:load", initCustomSelects)
document.addEventListener("click", () => closeAllCustomSelects())
document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeAllCustomSelects() })
