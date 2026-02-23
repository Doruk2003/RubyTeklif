class PagesController < ApplicationController
  def home
    service = DashboardService.new(client: supabase_user_client, actor_id: current_user.id)
    @kpis = service.kpis
    @recent_offers = service.recent_offers
    @flow_stats = service.flow_stats
    @reminders = service.reminders
  rescue ServiceErrors::System => e
    report_handled_error(e, source: "pages#home", severity: :error)
    flash.now[:alert] = e.user_message
    @kpis = []
    @recent_offers = []
    @flow_stats = []
    @reminders = []
  rescue StandardError
    @kpis = []
    @recent_offers = []
    @flow_stats = []
    @reminders = []
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
end
