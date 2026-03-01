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
  if (select.dataset.nativeSelect === "true") return

  const existingRoot = select.closest(`[${ROOT_ATTR}]`)
  if (existingRoot) {
    // We must move the select OUT of the wrapper before removing the wrapper
    existingRoot.parentNode.insertBefore(select, existingRoot)
    existingRoot.remove()
  }

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

  // Add search
  const searchUrl = select.dataset.searchUrl
  if (select.dataset.search === "true" || select.options.length > 5 || searchUrl) {
    const searchContainer = document.createElement("div")
    searchContainer.className = "rt-custom-select-search-container p-2 border-bottom sticky-top bg-white"
    const searchInput = document.createElement("input")
    searchInput.type = "text"
    searchInput.className = "form-control form-control-sm rt-custom-select-search"
    searchInput.placeholder = "Ara..."
    searchInput.autocomplete = "off"

    let debounceTimer
    searchInput.addEventListener("click", (e) => e.stopPropagation())
    searchInput.addEventListener("input", (e) => {
      const term = e.target.value.toLocaleLowerCase("tr-TR")

      if (searchUrl) {
        clearTimeout(debounceTimer)
        debounceTimer = setTimeout(async () => {
          try {
            const resp = await fetch(`${searchUrl}${searchUrl.includes('?') ? '&' : '?'}q=${encodeURIComponent(term)}`)
            const data = await resp.json()
            renderRemoteOptions(data, select, root, trigger, menu, optionsContainer)
          } catch (err) {
            console.error("Remote search error:", err)
          }
        }, 300)
      } else {
        menu.querySelectorAll(".rt-custom-select-option").forEach((opt) => {
          const text = opt.textContent.toLocaleLowerCase("tr-TR")
          opt.style.display = text.includes(term) ? "" : "none"
        })
      }
    })

    searchContainer.appendChild(searchInput)
    menu.appendChild(searchContainer)
  }

  const optionsContainer = document.createElement("div")
  optionsContainer.className = "rt-custom-select-options-list"
  optionsContainer.style.maxHeight = "300px"
  optionsContainer.style.overflowY = "auto"

  function renderRemoteOptions(data, nativeSelect, root, trigger, menu, container) {
    // Sync native select options
    nativeSelect.innerHTML = termToOptions(data, nativeSelect.value)

    // Re-render custom options
    container.innerHTML = ""
    data.forEach(item => {
      const btn = createOptionButton(item.id, item.name, nativeSelect, root, trigger, menu)
      container.appendChild(btn)
    })
  }

  function termToOptions(data, currentValue) {
    let html = '<option value="">Seçin</option>'
    data.forEach(item => {
      html += `<option value="${item.id}" ${item.id == currentValue ? 'selected' : ''}>${item.name}</option>`
    })
    return html
  }

  function createOptionButton(val, text, nativeSelect, root, trigger, menu) {
    const item = document.createElement("button")
    item.type = "button"
    item.className = "rt-custom-select-option rt-arrow-hover"
    item.dataset.value = val
    item.textContent = text
    item.setAttribute("role", "option")

    item.addEventListener("click", (e) => {
      e.stopPropagation()
      nativeSelect.value = val
      nativeSelect.dispatchEvent(new Event("change", { bubbles: true }))
      syncState(root, nativeSelect, trigger, menu)
      root.classList.remove("is-open")
      trigger.setAttribute("aria-expanded", "false")
    })
    return item
  }

  Array.from(select.options).forEach((option) => {
    if (option.hidden) return
    const item = createOptionButton(option.value, option.text, select, root, trigger, menu)
    if (option.disabled) {
      item.disabled = true
      item.classList.add("is-disabled")
    }
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

export function initCustomSelects(root = document) {
  root.querySelectorAll("select").forEach(buildCustomSelect)
}

window.rtCustomSelect = { initCustomSelects };

document.addEventListener("turbo:load", initCustomSelects)
document.addEventListener("click", () => closeAllCustomSelects())
document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeAllCustomSelects() })
