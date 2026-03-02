(function() {
  const WRAPPERS = [
    ".rt-categories-table-wrap",
    ".rt-products-table-wrap",
    ".rt-currencies-table-wrap",
    ".rt-companies-table-wrap",
    ".rt-offers-table-wrap"
  ]

  function initActionDetailsMenus() {
    WRAPPERS.forEach((selector) => {
      document.querySelectorAll(selector).forEach((tableWrap) => {
        if (!tableWrap || tableWrap.dataset.menuInit === "1") return
        tableWrap.dataset.menuInit = "1"

        const actionMenus = () => Array.from(tableWrap.querySelectorAll("details.rt-action-details"))

        tableWrap.addEventListener("click", (event) => {
          const clickedMenu = event.target.closest("details.rt-action-details")
          const clickedSummary = event.target.closest("details.rt-action-details > summary")

          if (!clickedMenu) {
            actionMenus().forEach((menu) => { menu.open = false })
            return
          }

          if (clickedSummary) {
            actionMenus().forEach((menu) => {
              if (menu !== clickedMenu) menu.open = false
            })
          }
        })

        document.addEventListener("click", (event) => {
          if (tableWrap.contains(event.target)) return
          actionMenus().forEach((menu) => { menu.open = false })
        })

        document.addEventListener("keydown", (event) => {
          if (event.key !== "Escape") return
          actionMenus().forEach((menu) => { menu.open = false })
        })
      })
    })
  }

  document.addEventListener("turbo:load", initActionDetailsMenus)
  if (document.readyState !== "loading") initActionDetailsMenus()
})()
