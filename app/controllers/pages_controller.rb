class PagesController < ApplicationController
  def home
    service = DashboardService.new(client: supabase_user_client, actor_id: current_user.id)
    @kpis = safe_dashboard_section(default: [], source: "pages#home.kpis") { service.kpis }
    @recent_offers = safe_dashboard_section(default: [], source: "pages#home.recent_offers") { service.recent_offers }
    @flow_stats = safe_dashboard_section(default: [], source: "pages#home.flow_stats") { service.flow_stats }
    @reminders = safe_dashboard_section(default: [], source: "pages#home.reminders") { service.reminders }
  end

  def ajanda
    service = AgendaService.new(client: supabase_user_client, actor_id: current_user.id)
    @calendar_events = service.calendar_events
    @agenda_items = service.side_items
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "pages#ajanda", severity: :error)
    flash.now[:alert] = e.user_message
    @calendar_events = []
    @agenda_items = []
  rescue StandardError
    @calendar_events = []
    @agenda_items = []
  end

  private

  def safe_dashboard_section(default:, source:)
    yield
  rescue ServiceErrors::System => e
    report_handled_error(e, source: source, severity: :error)
    flash.now[:alert] ||= e.user_message
    default
  rescue StandardError
    default
  end
end
