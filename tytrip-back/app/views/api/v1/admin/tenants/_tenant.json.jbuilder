json.partial! "api/v1/shared/tenant", tenant: tenant
json.extract! tenant, :shard, :suspended_at
json.members_count member_counts.fetch(tenant.id, 0)
