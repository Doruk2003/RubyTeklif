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
end
