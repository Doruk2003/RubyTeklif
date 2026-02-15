module Admin
  module ActivityLogs
    # Normalizes export filters for activity logs.
    class ExportForm
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :event_action, :string
      attribute :actor, :string
      attribute :target, :string
      attribute :target_type, :string
      attribute :from, :string
      attribute :to, :string

      def to_h
        {
          event_action: event_action.to_s.presence,
          actor: actor.to_s.presence,
          target: target.to_s.presence,
          target_type: target_type.to_s.presence,
          from: from.to_s.presence,
          to: to.to_s.presence
        }.compact
      end
    end
  end
end
