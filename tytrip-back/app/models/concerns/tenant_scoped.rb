# Isolation for tenant business data stored on the shards.
#
# Shards may host several tenants, so the shard switch alone is not enough:
# every query is constrained to the current tenant and fails closed (raises)
# when there is no tenant context or when the connection is on another shard.
# Do not use `unscoped` on these models outside of platform maintenance code.
module TenantScoped
  extend ActiveSupport::Concern

  class ShardMismatch < StandardError; end

  included do
    default_scope { where(tenant_id: TenantScoped.current_tenant_id!) }

    attr_readonly :tenant_id
    validates :tenant_id, presence: true
    validate :tenant_must_be_current, on: :create
  end

  def self.current_tenant_id!
    tenant = Current.tenant!
    unless ApplicationRecord.current_shard == tenant.shard.to_sym
      raise ShardMismatch, "Connected to #{ApplicationRecord.current_shard}, tenant lives on #{tenant.shard}"
    end
    tenant.id
  end

  private
    def tenant_must_be_current
      errors.add(:tenant_id, :invalid) unless tenant_id == Current.tenant&.id
    end
end
