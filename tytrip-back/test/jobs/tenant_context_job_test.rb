require "test_helper"

class TenantContextJobTest < ActiveJob::TestCase
  class ProbeJob < ApplicationJob
    cattr_accessor :seen

    def perform
      self.class.seen = [ Current.tenant&.id, ApplicationRecord.current_shard ]
    end
  end

  test "jobs enqueued in a tenant context run in that tenant's context and shard" do
    tenant = create_tenant
    other_shard_tenant = create_tenant
    target = [ tenant, other_shard_tenant ].find { |t| t.shard != "shard_one" }

    target.switch { ProbeJob.perform_later }
    assert_nil Current.tenant
    perform_enqueued_jobs

    assert_equal [ target.id, target.shard.to_sym ], ProbeJob.seen
  end

  test "jobs enqueued without tenant run without tenant" do
    ProbeJob.perform_later
    perform_enqueued_jobs
    assert_nil ProbeJob.seen.first
  end
end
