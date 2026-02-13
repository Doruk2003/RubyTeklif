import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]
  static values = { prices: Object }

  connect() {
    this.applyInitialPrices()
  }

  add() {
    const fragment = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(fragment)
  }

  remove(event) {
    const row = event.currentTarget.closest("[data-offer-items-row]")
    if (!row) return

    const rows = this.listTarget.querySelectorAll("[data-offer-items-row]")
    if (rows.length <= 1) {
      this.clearRow(row)
      return
    }

    row.remove()
  }

  clearRow(row) {
    row.querySelectorAll("input, select").forEach((element) => {
      if (element.tagName === "SELECT") {
        element.selectedIndex = 0
      } else {
        element.value = ""
      }
    })

    const quantityInput = row.querySelector('input[name="offer[items][][quantity]"]')
    if (quantityInput) quantityInput.value = "1"
  }

  productChanged(event) {
    const select = event.currentTarget
    const row = select.closest("[data-offer-items-row]")
    if (!row) return

    const priceInput = row.querySelector('input[name="offer[items][][unit_price]"]')
    if (!priceInput) return

    const selectedProductId = select.value.toString()
    if (selectedProductId.length === 0) return

    const mappedPrice = this.pricesValue[selectedProductId]
    if (mappedPrice === undefined || mappedPrice === null || mappedPrice === "") return

    priceInput.value = mappedPrice
  }

  applyInitialPrices() {
    this.listTarget.querySelectorAll('select[name="offer[items][][product_id]"]').forEach((select) => {
      const row = select.closest("[data-offer-items-row]")
      if (!row) return

      const priceInput = row.querySelector('input[name="offer[items][][unit_price]"]')
      if (!priceInput || priceInput.value.toString().length > 0) return

      const selectedProductId = select.value.toString()
      if (selectedProductId.length === 0) return

      const mappedPrice = this.pricesValue[selectedProductId]
      if (mappedPrice === undefined || mappedPrice === null || mappedPrice === "") return

      priceInput.value = mappedPrice
    })
  }
}
