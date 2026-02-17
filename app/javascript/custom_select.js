const ROOT_ATTR = "data-rt-custom-select"

function closeAllCustomSelects(except = null) {
  document.querySelectorAll(`[${ROOT_ATTR}]`).forEach((root) => {
    if (except && root === except) return
    root.classList.remove("is-open")
  })
}

function syncState(root, select, trigger, menu) {
  const selectedOption = select.options[select.selectedIndex]
  trigger.querySelector(".rt-custom-select-label").textContent = selectedOption ? selectedOption.text : ""

  menu.querySelectorAll(".rt-custom-select-option").forEach((optionButton) => {
    const active = optionButton.dataset.value === select.value
    optionButton.classList.toggle("is-active", active)
    optionButton.setAttribute("aria-selected", active ? "true" : "false")
  })
}

function buildCustomSelect(select) {
  if (!select.classList.contains("form-input")) return
  if (select.multiple) return
  if (select.closest(`[${ROOT_ATTR}]`)) return
  if (select.dataset.nativeSelect === "true") return

  const root = document.createElement("div")
  root.setAttribute(ROOT_ATTR, "true")
  root.className = "rt-custom-select"

  const trigger = document.createElement("button")
  trigger.type = "button"
  trigger.className = "rt-custom-select-trigger"
  trigger.setAttribute("aria-haspopup", "listbox")
  trigger.setAttribute("aria-expanded", "false")
  trigger.innerHTML = '<span class="rt-custom-select-label"></span><span class="rt-custom-select-arrow">▾</span>'

  const menu = document.createElement("div")
  menu.className = "rt-custom-select-menu"
  menu.setAttribute("role", "listbox")

  Array.from(select.options).forEach((option) => {
    const item = document.createElement("button")
    item.type = "button"
    item.className = "rt-custom-select-option"
    item.dataset.value = option.value
    item.textContent = option.text
    item.setAttribute("role", "option")
    item.setAttribute("aria-selected", "false")

    if (option.disabled) {
      item.disabled = true
      item.classList.add("is-disabled")
    }

    item.addEventListener("click", () => {
      if (item.disabled) return
      select.value = item.dataset.value
      select.dispatchEvent(new Event("change", { bubbles: true }))
      syncState(root, select, trigger, menu)
      root.classList.remove("is-open")
      trigger.setAttribute("aria-expanded", "false")
    })

    menu.appendChild(item)
  })

  select.classList.add("rt-native-select-hidden")
  select.parentNode.insertBefore(root, select)
  root.appendChild(select)
  root.appendChild(trigger)
  root.appendChild(menu)

  trigger.addEventListener("click", () => {
    const isOpen = root.classList.contains("is-open")
    if (isOpen) {
      root.classList.remove("is-open")
      trigger.setAttribute("aria-expanded", "false")
      return
    }
    closeAllCustomSelects(root)
    root.classList.add("is-open")
    trigger.setAttribute("aria-expanded", "true")
  })

  select.addEventListener("change", () => {
    syncState(root, select, trigger, menu)
  })

  syncState(root, select, trigger, menu)
}

export function initCustomSelects() {
  document.querySelectorAll("select.form-input").forEach((select) => {
    buildCustomSelect(select)
  })
}

document.addEventListener("click", (event) => {
  if (event.target.closest(`[${ROOT_ATTR}]`)) return
  closeAllCustomSelects()
})

document.addEventListener("keydown", (event) => {
  if (event.key !== "Escape") return
  closeAllCustomSelects()
})
