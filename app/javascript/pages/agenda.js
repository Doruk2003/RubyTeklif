(function() {
  let agendaCalendar = null
  let agendaCalendarInitPending = false
  const fullCalendarCdnUrl = "https://cdn.jsdelivr.net/npm/fullcalendar@6.1.19/index.global.min.js"

  function ensureAgendaCalendarLibrary(onReady) {
    if (window.FullCalendar) {
      onReady()
      return
    }

    const existingScript = document.querySelector("script[data-agenda-fullcalendar='1']")
    if (existingScript) {
      if (existingScript.dataset.loaded === "1") {
        onReady()
        return
      }
      existingScript.addEventListener("load", onReady, { once: true })
      existingScript.addEventListener("error", () => { agendaCalendarInitPending = false }, { once: true })
      return
    }

    const script = document.createElement("script")
    script.src = fullCalendarCdnUrl
    script.async = true
    script.dataset.agendaFullcalendar = "1"
    script.addEventListener("load", () => {
      script.dataset.loaded = "1"
      onReady()
    }, { once: true })
    script.addEventListener("error", () => {
      agendaCalendarInitPending = false
    }, { once: true })
    document.head.appendChild(script)
  }

  function decodeEvents(calendarEl) {
    const encoded = calendarEl.dataset.eventsEncoded || ""
    if (!encoded) return []
    try {
      const decoded = decodeURIComponent(encoded)
      const parsed = JSON.parse(decoded)
      return Array.isArray(parsed) ? parsed : []
    } catch (_error) {
      return []
    }
  }

  function initAgendaCalendar() {
    const calendarEl = document.getElementById("agenda-calendar")
    if (!calendarEl) return

    if (!window.FullCalendar) {
      if (!agendaCalendarInitPending) {
        agendaCalendarInitPending = true
        ensureAgendaCalendarLibrary(() => {
          agendaCalendarInitPending = false
          initAgendaCalendar()
        })
      }
      return
    }

    const defaultDate = calendarEl.dataset.defaultDate || new Date().toISOString().slice(0, 10)
    const createPath = calendarEl.dataset.createPath || "/calendar_events"
    const modal = document.getElementById("agenda-event-modal")
    const openBtn = document.getElementById("agenda-open-modal")
    const closeBtn = document.getElementById("agenda-close-modal")
    const form = document.getElementById("agenda-event-form")
    const formMethod = document.getElementById("agenda-event-form-method")
    const submitLabel = document.getElementById("agenda-event-submit-label")
    const inputDate = document.getElementById("agenda-event-date")
    const inputTime = document.getElementById("agenda-event-time")
    const inputTitle = document.getElementById("agenda-event-title-input")
    const inputDescription = document.getElementById("agenda-event-description")
    const inputColor = document.getElementById("agenda-event-color")
    const inputRemind = document.getElementById("agenda-event-remind")

    const resetModalForm = () => {
      if (!form) return
      form.action = createPath
      if (formMethod) formMethod.value = "post"
      if (submitLabel) submitLabel.textContent = "Add"
      if (inputDate) inputDate.value = defaultDate
      if (inputTime) inputTime.value = "09:00"
      if (inputTitle) inputTitle.value = ""
      if (inputDescription) inputDescription.value = ""
      if (inputColor) inputColor.value = "#38bdf8"
      if (inputRemind) inputRemind.value = "10"
    }

    const openModalForCreate = () => {
      resetModalForm()
      if (!modal) return
      modal.classList.add("is-open")
      modal.setAttribute("aria-hidden", "false")
    }

    const openModalForEdit = (payload) => {
      if (!form || !payload || !payload.id) return

      form.action = `/calendar_events/${payload.id}`
      if (formMethod) formMethod.value = "patch"
      if (submitLabel) submitLabel.textContent = "Update"
      if (inputDate) inputDate.value = payload.eventDate || defaultDate
      if (inputTime) inputTime.value = payload.eventTime || "09:00"
      if (inputTitle) inputTitle.value = payload.title || ""
      if (inputDescription) inputDescription.value = payload.description || ""
      if (inputColor) inputColor.value = payload.color || "#38bdf8"
      if (inputRemind) inputRemind.value = String(payload.remind || 0)

      if (!modal) return
      modal.classList.add("is-open")
      modal.setAttribute("aria-hidden", "false")
    }

    if (modal && openBtn && closeBtn && modal.dataset.bindReady !== "1") {
      const closeModal = () => {
        modal.classList.remove("is-open")
        modal.setAttribute("aria-hidden", "true")
      }

      modal.dataset.bindReady = "1"
      openBtn.addEventListener("click", openModalForCreate)
      closeBtn.addEventListener("click", closeModal)
      modal.addEventListener("click", (event) => {
        if (event.target === modal) closeModal()
      })
      document.addEventListener("keydown", (event) => {
        if (event.key === "Escape") closeModal()
      })
    }

    if (modal && !modal.dataset.editBindReady) {
      document.querySelectorAll("[data-agenda-edit-event='1']").forEach((btn) => {
        btn.addEventListener("click", () => {
          openModalForEdit({
            id: btn.dataset.eventId,
            eventDate: btn.dataset.eventDate,
            eventTime: btn.dataset.eventTime,
            title: btn.dataset.eventTitle,
            description: btn.dataset.eventDescription,
            color: btn.dataset.eventColor,
            remind: btn.dataset.eventRemind
          })
        })
      })
      modal.dataset.editBindReady = "1"
    }

    if (agendaCalendar) {
      agendaCalendar.destroy()
      agendaCalendar = null
    }

    const events = decodeEvents(calendarEl)

    agendaCalendar = new FullCalendar.Calendar(calendarEl, {
      initialView: "dayGridMonth",
      aspectRatio: 2.35,
      height: "auto",
      contentHeight: "auto",
      expandRows: true,
      displayEventTime: true,
      eventTimeFormat: { hour: "2-digit", minute: "2-digit", hour12: false },
      headerToolbar: {
        left: "prev,next today",
        center: "title",
        right: "dayGridMonth,timeGridWeek,timeGridDay,listWeek"
      },
      buttonText: {
        today: "today",
        month: "month",
        week: "week",
        day: "day",
        list: "list"
      },
      firstDay: 1,
      fixedWeekCount: true,
      dayMaxEvents: 2,
      events: events,
      eventClick: (info) => {
        const start = info.event.start
        if (!start) return

        const yyyy = start.getFullYear()
        const mm = String(start.getMonth() + 1).padStart(2, "0")
        const dd = String(start.getDate()).padStart(2, "0")
        const hh = String(start.getHours()).padStart(2, "0")
        const mi = String(start.getMinutes()).padStart(2, "0")

        openModalForEdit({
          id: info.event.id,
          eventDate: `${yyyy}-${mm}-${dd}`,
          eventTime: `${hh}:${mi}`,
          title: info.event.title,
          description: info.event.extendedProps.description || "",
          color: info.event.backgroundColor || "#38bdf8",
          remind: info.event.extendedProps.remindMinutesBefore || 0
        })
      }
    })

    agendaCalendar.render()
    setTimeout(() => {
      if (agendaCalendar) agendaCalendar.updateSize()
    }, 0)
  }

  document.addEventListener("turbo:load", initAgendaCalendar)
  document.addEventListener("turbo:render", initAgendaCalendar)
  document.addEventListener("turbo:before-cache", () => {
    if (agendaCalendar) {
      agendaCalendar.destroy()
      agendaCalendar = null
    }
  })
})()
