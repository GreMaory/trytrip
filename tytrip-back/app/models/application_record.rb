# Base class for tenant business data. Every subclass lives on one of the
# tenant shards declared in config/shards.yml; the shard is selected per
# request/job by Identity::Tenant#switch, never by client input.
class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class

  connects_to shards: Rails.application.config.x.tenant_shards.to_h { |shard, database|
    [ shard, { writing: database.to_sym } ]
  }

  # Rails 8.0 does not map PostgreSQL exclusion constraint violations
  # (SQLSTATE 23P01) to a dedicated error class.
  def self.exclusion_violation?(error)
    error.is_a?(ActiveRecord::StatementInvalid) && error.cause.is_a?(PG::ExclusionViolation)
  end
end
