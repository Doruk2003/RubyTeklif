(function() {
  let customerSelectInitialized = false

  function showOfferTypeMessage(message, type = "danger") {
    const box = document.getElementById("offerTypeInlineMessage")
    if (!box) return
    box.classList.remove("d-none", "alert-danger", "alert-success")
    box.classList.add(type === "success" ? "alert-success" : "alert-danger")
    box.textContent = message
  }

  function clearOfferTypeMessage() {
    const box = document.getElementById("offerTypeInlineMessage")
    if (!box) return
    box.classList.add("d-none")
    box.textContent = ""
  }

  function ensureCustomerSelectionSynced() {
    const customerSelect = document.getElementById("modalCustomerSelect")
    if (!customerSelect || customerSelect.value) return

    const wrapper = document.getElementById("customerSelectWrapper")
    if (!wrapper) return

    const active = wrapper.querySelector(".rt-custom-select-option.is-active[data-value]")
    if (active && active.dataset.value) {
      customerSelect.value = active.dataset.value
      customerSelect.dispatchEvent(new Event("change", { bubbles: true }))
      return
    }

    const label = wrapper.querySelector(".rt-custom-select-label")
    const labelText = label ? label.textContent.trim() : ""
    if (!labelText || labelText === "Secin") return

    const match = Array.from(customerSelect.options).find((opt) => (opt.text || "").trim() === labelText)
    if (match) {
      customerSelect.value = match.value
      customerSelect.dispatchEvent(new Event("change", { bubbles: true }))
    }
  }

  function cleanupModalArtifacts() {
    document.querySelectorAll(".modal-backdrop").forEach((el) => el.remove())
    document.body.classList.remove("modal-open")
    document.body.style.removeProperty("padding-right")
    document.body.style.removeProperty("overflow")
  }

  function closeAndVisit(modalEl, url) {
    const modal = bootstrap.Modal.getInstance(modalEl)
    if (modal) modal.hide()
    cleanupModalArtifacts()
    window.location.assign(url)
  }

  function offerBasePath(type) {
    return (type === "standart") ? "/offers/standart" : `/offers/${type}`
  }

  function initCustomerSelectOnce() {
    if (customerSelectInitialized) return
    if (window.rtCustomSelect) {
      window.rtCustomSelect.initCustomSelects(document.getElementById("customerSelectWrapper"))
    }
    customerSelectInitialized = true
  }

  function initOfferModalLogic() {
    const modalEl = document.getElementById("offerTypeModal")
    if (!modalEl || modalEl.dataset.logicInit === "1") return
    modalEl.dataset.logicInit = "1"

    const typeSelect = document.getElementById("offerTypeSelect")
    const projectInput = document.getElementById("modalProjectInput")
    const confirmBtn = document.getElementById("confirmOfferCreation")
    const customerSelect = document.getElementById("modalCustomerSelect")

    modalEl.addEventListener("show.bs.modal", (event) => {
      const trigger = event.relatedTarget
      const source = (trigger && trigger.closest)
        ? trigger.closest("[data-offer-type], [data-offer_type]")
        : trigger
      const sourceData = source && source.dataset ? source.dataset : {}
      const offerTypeFromTrigger = sourceData.offerType || sourceData.offer_type || ""

      if (offerTypeFromTrigger) typeSelect.value = offerTypeFromTrigger

      projectInput.value = ""
      clearOfferTypeMessage()
      initCustomerSelectOnce()
    })

    if (confirmBtn) {
      confirmBtn.addEventListener("click", () => {
        const type = typeSelect.value
        ensureCustomerSelectionSynced()
        const customerId = customerSelect.value
        const project = projectInput.value

        if (!customerId) {
          showOfferTypeMessage("Lutfen bir musteri secin.")
          return
        }

        const basePath = offerBasePath(type)
        const url = `${basePath}/new?company_id=${customerId}&project=${encodeURIComponent(project)}`
        closeAndVisit(modalEl, url)
      })
    }

    if (customerSelect) customerSelect.addEventListener("change", clearOfferTypeMessage)
    if (projectInput) projectInput.addEventListener("input", clearOfferTypeMessage)
  }

  document.addEventListener("turbo:load", initOfferModalLogic)
  if (document.readyState !== "loading") initOfferModalLogic()
})()
