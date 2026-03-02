(function() {
  function initPasswordToggle() {
    const button = document.getElementById("toggle-password")
    const input = document.getElementById("login-password")
    const openIcon = document.getElementById("eye-open")
    const closedIcon = document.getElementById("eye-closed")
    if (!button || !input || !openIcon || !closedIcon) return
    if (button.dataset.bound === "1") return
    button.dataset.bound = "1"

    button.addEventListener("click", () => {
      const isPassword = input.type === "password"
      input.type = isPassword ? "text" : "password"
      button.setAttribute("aria-pressed", isPassword ? "true" : "false")
      button.setAttribute("aria-label", isPassword ? "Sifreyi gizle" : "Sifreyi goster")
      openIcon.classList.toggle("hidden", isPassword)
      closedIcon.classList.toggle("hidden", !isPassword)
    })
  }

  document.addEventListener("turbo:load", initPasswordToggle)
  if (document.readyState !== "loading") initPasswordToggle()
})()
