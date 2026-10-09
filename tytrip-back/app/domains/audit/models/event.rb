# Append-only audit trail (security events, administrative actions,
# sensitive business changes). Metadata is scrubbed of secrets.
module Audit
  class Event < CatalogRecord
    self.table_name = "audit_events"

    SENSITIVE_KEY = /pass|token|secret|otp|code|digest|card|iban/i

    belongs_to :tenant, class_name: "Identity::Tenant", optional: true
    belongs_to :actor, class_name: "Identity::User", optional: true

    validates :action, presence: true, format: { with: /\A[a-z_]+(\.[a-z_]+)+\z/ }

    scope :recent_first, -> { order(created_at: :desc, id: :desc) }

    def self.record!(action, subject: nil, actor: Current.user, tenant: Current.tenant, metadata: {})
      create!(
        action: action,
        subject_type: subject&.class&.name,
        subject_id: subject&.id,
        actor: actor,
        tenant: tenant,
        metadata: scrub(metadata),
        ip_address: Current.ip_address,
        user_agent: Current.user_agent.to_s.truncate(255).presence,
        request_id: Current.request_id
      )
    end

    def self.scrub(value)
      case value
      when Hash then value.to_h { |key, item| [ key.to_s, key.to_s.match?(SENSITIVE_KEY) ? "[FILTERED]" : scrub(item) ] }
      when Array then value.map { |item| scrub(item) }
      else value
      end
    end

    def readonly?
      persisted?
    end
  end
end
