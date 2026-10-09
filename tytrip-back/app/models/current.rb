# Per-request / per-job context. Reset automatically by the Rails executor at
# the end of every request and job.
class Current < ActiveSupport::CurrentAttributes
  class TenantMissing < StandardError; end

  attribute :tenant, :session, :membership
  attribute :request_id, :ip_address, :user_agent

  delegate :user, to: :session, allow_nil: true

  def tenant!
    tenant || raise(TenantMissing, "No tenant context: wrap tenant data access in Identity::Tenant#switch")
  end
end
