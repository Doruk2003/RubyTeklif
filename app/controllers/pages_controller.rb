class PagesController < ApplicationController
  def home
    service = DashboardService.new(client: supabase_user_client, actor_id: current_user.id)
    @kpis = service.kpis
    @recent_offers = service.recent_offers
    @flow_stats = service.flow_stats
    @reminders = service.reminders
  rescue StandardError
    @kpis = []
    @recent_offers = []
    @flow_stats = []
    @reminders = []
  end

  def theme_preview
    @themes = [
      {
        name: "Nordic Minimal",
        desc: "Soğuk gri‑mavi palet, sakin ve kurumsal.",
        bg: "bg-slate-100",
        card: "bg-white",
        accent: "text-slate-800",
        accent_bg: "bg-slate-200",
        button: "bg-slate-800 text-white",
        chip: "bg-slate-200 text-slate-800"
      },
      {
        name: "Graphite Pro",
        desc: "Koyu grafik taban, yüksek kontrast.",
        bg: "bg-zinc-200",
        card: "bg-white",
        accent: "text-zinc-900",
        accent_bg: "bg-zinc-300",
        button: "bg-zinc-900 text-white",
        chip: "bg-zinc-300 text-zinc-900"
      },
      {
        name: "Cloud Soft",
        desc: "Yumuşak pastel, friendly SaaS.",
        bg: "bg-sky-100",
        card: "bg-white",
        accent: "text-slate-800",
        accent_bg: "bg-sky-200",
        button: "bg-sky-600 text-white",
        chip: "bg-sky-200 text-sky-800"
      },
      {
        name: "Industrial Blue",
        desc: "Mavi ana renk, ERP hissi.",
        bg: "bg-blue-100",
        card: "bg-white",
        accent: "text-slate-900",
        accent_bg: "bg-blue-200",
        button: "bg-blue-700 text-white",
        chip: "bg-blue-200 text-blue-800"
      },
      {
        name: "Olive & Sand",
        desc: "Toprak tonları, sıcak kurumsal.",
        bg: "bg-amber-100",
        card: "bg-white",
        accent: "text-amber-900",
        accent_bg: "bg-amber-200",
        button: "bg-amber-700 text-white",
        chip: "bg-amber-200 text-amber-900"
      },
      {
        name: "Teal Tech",
        desc: "Teal + koyu gri, modern SaaS.",
        bg: "bg-teal-100",
        card: "bg-white",
        accent: "text-slate-900",
        accent_bg: "bg-teal-200",
        button: "bg-teal-700 text-white",
        chip: "bg-teal-200 text-teal-900"
      }
    ]
  end
end
