(function() {
  let pozList = []
  let pozModalInstance = null
  let customSelectInited = false
  let backdropObserver = null
  let editingPozId = null
  let draftPersistTimer = null
  let draftPersistInFlight = false
  let draftPersistQueued = false
  let lastPersistSignature = null

  function showInlineMessage(message, type) {
    const box = document.getElementById("pozInlineMessage")
    if (!box) return
    const klass = (type === "success") ? "alert-success" : "alert-danger"
    box.classList.remove("d-none", "alert-danger", "alert-success")
    box.classList.add(klass)
    box.textContent = message
  }

  function clearInlineMessage() {
    const box = document.getElementById("pozInlineMessage")
    if (!box) return
    box.classList.add("d-none")
    box.textContent = ""
  }

  function ensureProductSelectionSynced() {
    const productSelect = document.getElementById("pozProductSelect")
    if (!productSelect || productSelect.value) return

    const wrapper = document.getElementById("pozModalProductWrapper")
    if (!wrapper) return

    const active = wrapper.querySelector(".rt-custom-select-option.is-active[data-value]")
    if (active && active.dataset.value) {
      productSelect.value = active.dataset.value
      productSelect.dispatchEvent(new Event("change", { bubbles: true }))
      return
    }

    const label = wrapper.querySelector(".rt-custom-select-label")
    const labelText = label ? label.textContent.trim() : ""
    if (!labelText || labelText === "Urun Secin" || labelText === "Secin") return

    const match = Array.from(productSelect.options).find((opt) => {
      const optionText = (opt.text || "").trim()
      const optionName = (opt.dataset && opt.dataset.name ? opt.dataset.name : "").trim()
      return optionText === labelText || optionName === labelText
    })

    if (match) {
      productSelect.value = match.value
      productSelect.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  function setModalMode() {
    const titleEl = document.querySelector("#pozEntryModal .modal-title")
    const saveBtn = document.getElementById("btnPozSave")
    if (editingPozId) {
      if (titleEl) titleEl.textContent = "POZ GUNCELLE"
      if (saveBtn) saveBtn.textContent = "Guncelle"
    } else {
      if (titleEl) titleEl.textContent = "POZ GIRISI"
      if (saveBtn) saveBtn.textContent = "Kaydet"
    }
  }

  function syncCustomSelectUI() {
    const wrapper = document.getElementById("pozModalProductWrapper")
    const select = document.getElementById("pozProductSelect")
    if (!wrapper || !select) return

    const root = wrapper.querySelector("[data-rt-custom-select]")
    const label = wrapper.querySelector(".rt-custom-select-label")
    const selected = select.options[select.selectedIndex]
    const hasValue = !!(selected && selected.value)

    if (label) label.textContent = hasValue ? selected.text : "Urun Secin"
    if (root) {
      root.classList.toggle("has-value", hasValue)
      root.classList.toggle("is-empty", !hasValue)
      root.querySelectorAll(".rt-custom-select-option").forEach((opt) => {
        const active = opt.dataset.value === select.value
        opt.classList.toggle("is-active", active)
        opt.setAttribute("aria-selected", active ? "true" : "false")
      })
    }
  }

  function init() {
    document.querySelectorAll(".modal-backdrop").forEach((el) => { el.remove() })
    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("padding-right")
    document.body.style.removeProperty("overflow")
    document.querySelectorAll(".offcanvas-backdrop").forEach((el) => { el.remove() })

    const offerTypeModal = document.getElementById("offerTypeModal")
    if (offerTypeModal) {
      offerTypeModal.classList.remove("show")
      offerTypeModal.setAttribute("aria-hidden", "true")
      offerTypeModal.style.display = "none"
    }

    const modalEl = document.getElementById("pozEntryModal")
    if (!modalEl) return
    if (modalEl.dataset.pozInit === "1") return
    modalEl.dataset.pozInit = "1"

    pozModalInstance = new bootstrap.Modal(modalEl, { backdrop: false, keyboard: false })

    if (!backdropObserver) {
      backdropObserver = new MutationObserver(() => {
        document.querySelectorAll(".modal-backdrop").forEach((el) => { el.remove() })
        document.body.classList.remove("modal-open")
        document.body.style.removeProperty("padding-right")
        document.body.style.removeProperty("overflow")
      })
      backdropObserver.observe(document.body, { childList: true, subtree: true })
    }

    const btnOpen = document.getElementById("btnOpenPozModal")
    if (btnOpen) {
      btnOpen.addEventListener("click", () => {
        editingPozId = null
        resetModalForm()
        clearInlineMessage()
        setModalMode()
        pozModalInstance.show()

        if (!customSelectInited && window.rtCustomSelect) {
          setTimeout(() => {
            window.rtCustomSelect.initCustomSelects(document.getElementById("pozModalProductWrapper"))
            customSelectInited = true
          }, 100)
        }
      })
    }

    const productSelect = document.getElementById("pozProductSelect")
    if (productSelect) {
      productSelect.addEventListener("change", function() {
        clearInlineMessage()
        const selectedOpt = this.options[this.selectedIndex]
        if (selectedOpt && selectedOpt.dataset.price) {
          const price = parseFloat(selectedOpt.dataset.price)
          if (!Number.isNaN(price) && price > 0) {
            document.getElementById("pozUnitPrice").value = price
          }
        }
      })
    }

    const btnSave = document.getElementById("btnPozSave")
    if (btnSave) {
      btnSave.addEventListener("click", () => {
        ensureProductSelectionSynced()
        savePoz()
      })
    }

    const btnCancel = document.getElementById("btnPozCancel")
    if (btnCancel) {
      btnCancel.addEventListener("click", () => {
        pozModalInstance.hide()
      })
    }

    const btnHesapla = document.getElementById("btnHesapla")
    if (btnHesapla) {
      btnHesapla.addEventListener("click", () => {
        if (pozList.length === 0) {
          resetModalForm()
          clearInlineMessage()
          showInlineMessage("Lutfen en az bir poz ekleyin.", "danger")
          pozModalInstance.show()
          return
        }
        buildHiddenInputs()
        document.getElementById("pozMainForm").requestSubmit()
      })
    }

    modalEl.addEventListener("keydown", (e) => {
      if (e.key === "Enter") {
        e.preventDefault()
        savePoz()
      }
    })

    hydrateInitialPozList()
    renderList()
  }

  function hydrateInitialPozList() {
    if (pozList.length > 0) return

    const container = document.getElementById("pozListContainer")
    if (!container) return

    const raw = container.dataset.initialPozs
    if (!raw) return

    let items
    try {
      items = JSON.parse(raw)
    } catch (_e) {
      return
    }
    if (!Array.isArray(items) || items.length === 0) return

    const productSelect = document.getElementById("pozProductSelect")
    pozList = items.map((item, idx) => {
      const productId = (item && item.product_id !== undefined) ? item.product_id.toString() : ""
      const fromSelect = resolveProductName(productSelect, productId)
      const fallbackName = item && item.product_name ? item.product_name.toString() : ""

      return {
        id: item && item.id ? item.id.toString() : `db_${idx}`,
        product_id: productId,
        product_name: fromSelect || fallbackName || `Urun #${productId}`,
        quantity: parseFloat(item && item.quantity) || 0,
        unit_price: parseFloat(item && item.unit_price) || 0,
        discount_rate: parseFloat(item && item.discount_rate) || 0,
        description: item && item.description ? item.description.toString() : ""
      }
    })
  }

  function resolveProductName(productSelect, productId) {
    if (!productSelect || !productId) return ""
    const option = Array.from(productSelect.options).find((opt) => opt.value === productId)
    if (!option) return ""
    return option.dataset.name || option.text || ""
  }

  function savePoz() {
    const productSelect = document.getElementById("pozProductSelect")
    ensureProductSelectionSynced()
    const productId = productSelect.value
    const wasEditing = !!editingPozId

    if (!productId) {
      showInlineMessage("Lutfen bir urun secin.", "danger")
      return
    }

    const selectedOpt = productSelect.options[productSelect.selectedIndex]
    const productName = selectedOpt.dataset.name || selectedOpt.text
    const quantity = parseFloat(document.getElementById("pozQuantity").value) || 1
    const unitPrice = parseFloat(document.getElementById("pozUnitPrice").value) || 0
    const discount = parseFloat(document.getElementById("pozDiscount").value) || 0
    const description = document.getElementById("pozDescription").value.trim()

    const poz = {
      id: editingPozId || (Date.now() + "_" + Math.random().toString(36).substring(2, 6)),
      product_id: productId,
      product_name: productName,
      quantity: quantity,
      unit_price: unitPrice,
      discount_rate: discount,
      description: description
    }

    if (editingPozId) {
      const idx = pozList.findIndex((p) => p.id === editingPozId)
      if (idx >= 0) {
        pozList[idx] = poz
      } else {
        pozList.push(poz)
      }
    } else {
      pozList.push(poz)
    }
    editingPozId = null
    setModalMode()
    renderList()
    scheduleDraftPersist()
    clearInlineMessage()
    resetModalForm()

    if (wasEditing && pozModalInstance) {
      pozModalInstance.hide()
    }

    setTimeout(() => {
      const searchInput = document.querySelector("#pozModalProductWrapper .rt-custom-select-search")
      if (searchInput) searchInput.focus()
    }, 100)
  }

  function resetModalForm() {
    const productSelect = document.getElementById("pozProductSelect")
    productSelect.value = ""
    productSelect.dispatchEvent(new Event("change", { bubbles: true }))

    document.getElementById("pozQuantity").value = "1"
    document.getElementById("pozUnitPrice").value = ""
    document.getElementById("pozDiscount").value = "0"
    document.getElementById("pozDescription").value = ""

    const wrapper = document.getElementById("pozModalProductWrapper")
    if (wrapper) {
      const label = wrapper.querySelector(".rt-custom-select-label")
      if (label) label.textContent = "Urun Secin"
      const root = wrapper.querySelector("[data-rt-custom-select]")
      if (root) {
        root.classList.remove("has-value")
        root.classList.add("is-empty")
        root.querySelectorAll(".rt-custom-select-option").forEach((opt) => {
          opt.classList.remove("is-active")
          opt.setAttribute("aria-selected", "false")
        })
      }
      const search = wrapper.querySelector(".rt-custom-select-search")
      if (search) search.value = ""
    }
    syncCustomSelectUI()
  }

  function renderList() {
    const container = document.getElementById("pozListContainer")
    const emptyState = document.getElementById("pozEmptyState")
    const counter = document.getElementById("pozCounter")

    if (counter) counter.textContent = `${pozList.length} Poz`

    if (pozList.length === 0) {
      container.innerHTML = ""
      if (emptyState) emptyState.style.display = ""
      return
    }

    if (emptyState) emptyState.style.display = "none"

    const isAppending = container.children.length < pozList.length

    let html = ""
    pozList.forEach((poz, i) => {
      const isNew = isAppending && i === pozList.length - 1
      html += `<div class="poz-list-row border-bottom px-4 py-3${isNew ? " poz-list-row-new poz-list-row-flash" : ""}" data-poz-id="${poz.id}">`
      html += "  <div class=\"row g-2 align-items-center\">"
      html += "    <div class=\"col-md-1 text-center d-none d-md-block\">"
      html += `      <span class="badge bg-light text-dark border fw-bold" style="font-size:0.8rem; min-width:28px;">${i + 1}</span>`
      html += "    </div>"
      html += "    <div class=\"col-12 col-md-4\">"
      html += `      <div class="fw-semibold text-dark" style="font-size:0.85rem;">${escapeHtml(poz.product_name)}</div>`
      if (poz.description) {
        html += `      <div class="text-muted" style="font-size:0.75rem;">${escapeHtml(poz.description)}</div>`
      }
      html += "    </div>"
      html += "    <div class=\"col-4 col-md-2 text-end\">"
      html += `      <span class="fw-semibold" style="font-size:0.85rem;">${formatNumber(poz.quantity)}</span>`
      html += "    </div>"
      html += "    <div class=\"col-4 col-md-2 text-end\">"
      html += `      <span class="fw-semibold" style="font-size:0.85rem;">${formatNumber(poz.unit_price)}</span>`
      html += "    </div>"
      html += "    <div class=\"col-2 col-md-1 text-end\">"
      if (poz.discount_rate > 0) {
        html += `      <span class="text-danger fw-semibold" style="font-size:0.85rem;">%${formatNumber(poz.discount_rate)}</span>`
      } else {
        html += "      <span class=\"text-muted\" style=\"font-size:0.85rem;\">-</span>"
      }
      html += "    </div>"
      html += "    <div class=\"col-2 col-md-2 text-end d-flex justify-content-end align-items-center gap-1\">"
      html += `      <button type="button" class="poz-edit-btn" onclick="window.__pozEdit('${poz.id}')" title="Duzenle">`
      html += "        <span class=\"material-symbols-outlined\" style=\"font-size:18px;\">edit</span>"
      html += "      </button>"
      html += `      <button type="button" class="poz-delete-btn" onclick="window.__pozDelete('${poz.id}')" title="Sil">`
      html += "        <span class=\"material-symbols-outlined\" style=\"font-size:18px;\">delete</span>"
      html += "      </button>"
      html += "    </div>"
      html += "  </div>"
      html += "</div>"
    })

    container.innerHTML = html
  }

  window.__pozDelete = function(id) {
    pozList = pozList.filter((p) => p.id !== id)
    if (editingPozId === id) {
      editingPozId = null
      setModalMode()
    }
    renderList()
    scheduleDraftPersist()
  }

  window.__pozEdit = function(id) {
    const poz = pozList.find((p) => p.id === id)
    if (!poz) return

    editingPozId = id
    setModalMode()
    clearInlineMessage()

    const productSelect = document.getElementById("pozProductSelect")
    if (productSelect) {
      productSelect.value = poz.product_id
      productSelect.dispatchEvent(new Event("change", { bubbles: true }))
    }
    document.getElementById("pozQuantity").value = poz.quantity
    document.getElementById("pozUnitPrice").value = poz.unit_price
    document.getElementById("pozDiscount").value = poz.discount_rate
    document.getElementById("pozDescription").value = poz.description || ""
    syncCustomSelectUI()
    pozModalInstance.show()
  }

  function buildHiddenInputs() {
    const container = document.getElementById("pozHiddenInputs")
    container.innerHTML = ""
    pozList.forEach((poz) => {
      container.innerHTML +=
        `<input type="hidden" name="offer[items][][product_id]" value="${poz.product_id}">` +
        `<input type="hidden" name="offer[items][][quantity]" value="${poz.quantity}">` +
        `<input type="hidden" name="offer[items][][unit_price]" value="${poz.unit_price}">` +
        `<input type="hidden" name="offer[items][][discount_rate]" value="${poz.discount_rate}">` +
        `<input type="hidden" name="offer[items][][description]" value="${escapeHtml(poz.description)}">`
    })
  }

  function scheduleDraftPersist() {
    if (draftPersistTimer) clearTimeout(draftPersistTimer)
    setDraftStatus("saving")
    draftPersistTimer = setTimeout(() => {
      persistDraftPozs()
    }, 350)
  }

  async function persistDraftPozs() {
    const container = document.getElementById("pozListContainer")
    const syncUrl = container && container.dataset ? container.dataset.syncUrl : ""
    const offerIdInput = document.querySelector("#pozMainForm input[name='offer[id]']")
    const offerId = offerIdInput ? offerIdInput.value.toString().trim() : ""
    if (!syncUrl || !offerId) return

    const payloadItems = pozList.map((poz) => ({
      product_id: poz.product_id,
      description: poz.description || "",
      quantity: poz.quantity,
      unit_price: poz.unit_price,
      discount_rate: poz.discount_rate
    }))
    const signature = JSON.stringify({ offer_id: offerId, items: payloadItems })
    if (signature === lastPersistSignature) return

    if (draftPersistInFlight) {
      draftPersistQueued = true
      return
    }
    draftPersistInFlight = true
    draftPersistQueued = false

    try {
      const result = await sendDraftPersistRequest(syncUrl, offerId, payloadItems, 2)
      lastPersistSignature = signature
      setDraftStatus("saved", result && result.saved_at ? result.saved_at : null)
    } catch (_e) {
      setDraftStatus("error")
      showInlineMessage("Taslak otomatik kaydedilemedi. Tekrar denenecek.", "danger")
      setTimeout(() => { scheduleDraftPersist() }, 1200)
    } finally {
      draftPersistInFlight = false
      if (draftPersistQueued) {
        draftPersistQueued = false
        persistDraftPozs()
      }
    }
  }

  async function sendDraftPersistRequest(url, offerId, items, retriesLeft) {
    const csrf = document.querySelector("meta[name='csrf-token']")
    const headers = {
      "Content-Type": "application/json",
      "X-Requested-With": "XMLHttpRequest"
    }
    if (csrf && csrf.content) headers["X-CSRF-Token"] = csrf.content

    const response = await fetch(url, {
      method: "POST",
      credentials: "same-origin",
      headers: headers,
      body: JSON.stringify({ offer_id: offerId, items: items })
    })

    if (response.ok) {
      try {
        return await response.json()
      } catch (_e) {
        return {}
      }
    }

    let message = "Taslak kaydi basarisiz."
    try {
      const body = await response.json()
      if (body && body.error) message = body.error
    } catch (_e) {
      // no-op
    }

    if (retriesLeft > 0) {
      await wait(300)
      return sendDraftPersistRequest(url, offerId, items, retriesLeft - 1)
    }

    throw new Error(message)
  }

  function wait(ms) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms)
    })
  }

  function setDraftStatus(state, savedAtIso) {
    const el = document.getElementById("draftSaveStatus")
    if (!el) return

    if (state === "saving") {
      el.textContent = "Taslak kaydediliyor..."
      return
    }

    if (state === "saved") {
      let text = "Taslak kaydedildi"
      if (savedAtIso) {
        const dt = new Date(savedAtIso)
        if (!Number.isNaN(dt.getTime())) {
          text = `Taslak kaydedildi: ${dt.toLocaleTimeString("tr-TR")}`
        }
      }
      el.textContent = text
      return
    }

    if (state === "error") {
      el.textContent = "Taslak kaydedilemedi, tekrar denenecek..."
    }
  }

  function escapeHtml(str) {
    if (!str) return ""
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }

  function formatNumber(n) {
    if (n === null || n === undefined || n === "") return "-"
    const num = parseFloat(n)
    if (Number.isNaN(num)) return "-"
    return (num % 1 === 0) ? num.toString() : num.toFixed(2)
  }

  document.addEventListener("turbo:load", init)
  if (document.readyState !== "loading") init()
})()
