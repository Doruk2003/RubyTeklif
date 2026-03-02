(function() {
  window.rtShowLightbox = function(src) {
    const lightbox = document.getElementById("rt_photo_lightbox")
    const lightboxImg = document.getElementById("rt_lightbox_img")
    if (lightbox && lightboxImg) {
      lightboxImg.src = src
      lightbox.classList.remove("d-none")
      lightbox.classList.add("d-flex")
      document.body.style.overflow = "hidden"
    }
  }

  window.closeRtLightbox = function() {
    const lightbox = document.getElementById("rt_photo_lightbox")
    if (lightbox) {
      lightbox.classList.add("d-none")
      lightbox.classList.remove("d-flex")
      document.body.style.overflow = ""
    }
  }

  let selectedFiles = []

  function setupPhotoUpload() {
    const photoUpload = document.getElementById("photo_upload")
    const container = document.getElementById("image_previews_container")
    const badge = document.getElementById("photo_count_badge")

    if (!photoUpload || !container) return
    if (photoUpload.dataset.photoInit === "true") return
    photoUpload.dataset.photoInit = "true"

    const existingPhotoCount = parseInt(photoUpload.dataset.existingPhotoCount || "0", 10) || 0
    selectedFiles = []
    updateDisplay()

    photoUpload.addEventListener("change", (e) => {
      const newFiles = Array.from(e.target.files)
      newFiles.forEach((file) => {
        const isDuplicate = selectedFiles.some((f) => f.name === file.name && f.size === file.size)
        if (!isDuplicate && (selectedFiles.length + existingPhotoCount) < 6) {
          selectedFiles.push(file)
        }
      })
      e.target.value = ""
      updateDisplay()
    })

    function updateDisplay() {
      container.innerHTML = ""
      if (selectedFiles.length > 0) container.classList.remove("d-none")
      else container.classList.add("d-none")

      selectedFiles.forEach((file, index) => {
        const wrapper = document.createElement("div")
        wrapper.className = "preview-image-wrapper"

        const img = document.createElement("img")
        const removeBtn = document.createElement("button")
        removeBtn.type = "button"
        removeBtn.className = "btn-remove-photo"
        removeBtn.innerHTML = "x"
        removeBtn.onclick = (ev) => {
          ev.preventDefault()
          ev.stopPropagation()
          removeFile(index)
        }

        wrapper.appendChild(img)
        wrapper.appendChild(removeBtn)
        container.appendChild(wrapper)

        const reader = new FileReader()
        reader.onload = (evt) => { img.src = evt.target.result }
        reader.readAsDataURL(file)
      })

      const dt = new DataTransfer()
      selectedFiles.forEach((file) => dt.items.add(file))
      photoUpload.files = dt.files

      if (badge) {
        const total = selectedFiles.length + existingPhotoCount
        badge.textContent = `${total} / 6`
        badge.className = total >= 6 ? "badge bg-danger text-white border" : "badge bg-light text-secondary border fw-normal"
      }
    }

    function removeFile(index) {
      selectedFiles.splice(index, 1)
      updateDisplay()
    }
  }

  function bindProductFormDelegates() {
    if (document.body.dataset.productFormDelegateInit === "1") return
    document.body.dataset.productFormDelegateInit = "1"

    document.addEventListener("click", (e) => {
      const wrapper = e.target.closest(".preview-image-wrapper")
      const isDeleteBtn = e.target.closest(".rt-delete-confirm-btn") || e.target.closest(".btn-remove-photo")

      if (wrapper && !isDeleteBtn) {
        const img = wrapper.querySelector("img")
        if (img && img.src) window.rtShowLightbox(img.src)
      }

      const delBtn = e.target.closest(".rt-delete-confirm-btn")
      if (delBtn) {
        e.preventDefault()
        e.stopPropagation()
        if (confirm(delBtn.dataset.confirm)) {
          const form = document.createElement("form")
          form.method = "POST"
          form.action = delBtn.dataset.deleteUrl
          const m = document.createElement("input")
          m.type = "hidden"
          m.name = "_method"
          m.value = "DELETE"
          const t = document.createElement("input")
          t.type = "hidden"
          t.name = "authenticity_token"
          t.value = document.querySelector("meta[name='csrf-token']")?.content
          form.appendChild(m)
          form.appendChild(t)
          document.body.appendChild(form)
          form.submit()
        }
      }
    })
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", setupPhotoUpload)
  } else {
    setupPhotoUpload()
  }
  document.addEventListener("turbo:load", setupPhotoUpload)
  document.addEventListener("turbo:load", bindProductFormDelegates)
  if (document.readyState !== "loading") bindProductFormDelegates()
})()
