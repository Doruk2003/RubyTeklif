class CalendarEventsController < ApplicationController
  before_action :authorize_calendar_events!

  def index
    events = AgendaService.new(client: supabase_user_client, actor_id: current_user.id).calendar_events
    render json: events
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "calendar_events#index")
    render json: { error: e.user_message }, status: :unprocessable_entity
  rescue Supabase::Client::ConfigurationError
    render json: { error: "Etkinlik servisine baglanilamadi." }, status: :service_unavailable
  end

  def create
    CalendarEvents::Create.new(client: supabase_user_client).call(
      form_payload: calendar_event_params.to_h,
      user_id: current_user.id
    )
    QueryCacheInvalidator.new.invalidate_agenda!(user_id: current_user.id)
    redirect_to ajanda_path, notice: "Etkinlik olusturuldu."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "calendar_events#create")
    redirect_to ajanda_path, alert: "Etkinlik olusturulamadi: #{e.user_message}"
  rescue Supabase::Client::ConfigurationError
    redirect_to ajanda_path, alert: "Etkinlik servisine baglanilamadi."
  end

  def update
    CalendarEvents::Update.new(client: supabase_user_client).call(
      form_payload: calendar_event_params.to_h,
      user_id: current_user.id,
      id: params[:id]
    )
    QueryCacheInvalidator.new.invalidate_agenda!(user_id: current_user.id)
    redirect_to ajanda_path, notice: "Etkinlik guncellendi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "calendar_events#update")
    redirect_to ajanda_path, alert: "Etkinlik guncellenemedi: #{e.user_message}"
  rescue Supabase::Client::ConfigurationError
    redirect_to ajanda_path, alert: "Etkinlik servisine baglanilamadi."
  end

  def destroy
    CalendarEvents::Destroy.new(client: supabase_user_client).call(
      id: params[:id],
      user_id: current_user.id
    )
    QueryCacheInvalidator.new.invalidate_agenda!(user_id: current_user.id)
    redirect_to ajanda_path, notice: "Etkinlik silindi."
  rescue ServiceErrors::Base => e
    report_handled_error(e, source: "calendar_events#destroy")
    redirect_to ajanda_path, alert: "Etkinlik silinemedi: #{e.user_message}"
  rescue Supabase::Client::ConfigurationError
    redirect_to ajanda_path, alert: "Etkinlik servisine baglanilamadi."
  end

  private

  def calendar_event_params
    params.require(:calendar_event).permit(:event_date, :event_time, :title, :description, :color, :remind_minutes_before)
  end

  def authorize_calendar_events!
    authorize_with_policy!(CalendarEventsPolicy)
  end
end
