module CalendarEvents
  class Repository
    def initialize(client:)
      @client = client
    end

    def create!(payload:)
      response = @client.post("calendar_events", body: payload, headers: { "Prefer" => "return=representation" })
      return response unless missing_new_columns_error?(response)

      legacy_payload = payload.except(:start_at, :remind_minutes_before)
      @client.post("calendar_events", body: legacy_payload, headers: { "Prefer" => "return=representation" })
    end

    def update!(id:, user_id:, payload:)
      @client.patch(
        "calendar_events?id=eq.#{Supabase::FilterValue.eq(id)}" \
        "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
        "&deleted_at=is.null",
        body: payload,
        headers: { "Prefer" => "return=representation" }
      )
    end

    def soft_delete!(id:, user_id:)
      @client.patch(
        "calendar_events?id=eq.#{Supabase::FilterValue.eq(id)}" \
        "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
        "&deleted_at=is.null",
        body: {
          deleted_at: Time.now.utc.iso8601,
          updated_at: Time.now.utc.iso8601
        },
        headers: { "Prefer" => "return=representation" }
      )
    end

    def list_active(user_id:, limit: 300)
      response = @client.get(
        "calendar_events?select=id,event_date,start_at,title,description,color,remind_minutes_before,created_at" \
        "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
        "&deleted_at=is.null" \
        "&order=start_at.asc.nullslast,event_date.asc,created_at.asc" \
        "&limit=#{limit.to_i}"
      )
      return response unless missing_new_columns_error?(response)

      @client.get(
        "calendar_events?select=id,event_date,title,description,color,created_at" \
        "&user_id=eq.#{Supabase::FilterValue.eq(user_id)}" \
        "&deleted_at=is.null" \
        "&order=event_date.asc,created_at.asc" \
        "&limit=#{limit.to_i}"
      )
    end

    private

    def missing_new_columns_error?(response)
      return false unless response.is_a?(Hash)

      code = response["code"].to_s
      message = [response["message"], response["details"], response["hint"]].compact.join(" ").downcase
      return true if code == "42703"

      message.include?("start_at") || message.include?("remind_minutes_before")
    end
  end
end
