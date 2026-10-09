# Carries the tenant from the enqueuing context to the job execution.
#
# The tenant id is stored in the job payload at enqueue time; at execution
# the whole job (including argument deserialization, which may load tenant
# records) runs inside Identity::Tenant#switch. Jobs enqueued outside a
# tenant context run without one.
module TenantContextJob
  extend ActiveSupport::Concern

  included do
    attr_accessor :tenant_id
  end

  def serialize
    super.merge("tenant_id" => tenant_id || Current.tenant&.id)
  end

  def deserialize(job_data)
    super
    self.tenant_id = job_data["tenant_id"]
  end

  def perform_now
    return super unless tenant_id

    Identity::Tenant.find(tenant_id).switch { super }
  end
end
