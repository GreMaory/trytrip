require "test_helper"

class Identity::TenantTest < ActiveSupport::TestCase
  test "normalizes and validates the subdomain" do
    tenant = Identity::Tenant.new(name: "Acme", subdomain: "  ACME-Stays ")
    assert tenant.valid?, tenant.errors.full_messages.inspect
    assert_equal "acme-stays", tenant.subdomain

    %w[app admin www a -bad bad- bad_sub].each do |subdomain|
      assert_not Identity::Tenant.new(name: "x", subdomain: subdomain).valid?, "#{subdomain} should be rejected"
    end
  end

  test "assigns new tenants to the least populated configured shard" do
    first = create_tenant
    second = create_tenant
    assert_includes Identity::Tenant.shard_keys, first.shard
    assert_not_equal first.shard, second.shard
    assert_not Identity::Tenant.new(name: "x", subdomain: "xyz", shard: "nope").valid?
  end

  test "the shard of an existing tenant cannot be changed by an update" do
    tenant = create_tenant
    assert_raises(ActiveRecord::ReadonlyAttributeError) do
      tenant.update(shard: (Identity::Tenant.shard_keys - [ tenant.shard ]).first)
    end
  end

  test "provision! creates the default roles and the owner membership" do
    owner = create_user
    tenant = Identity::Tenant.provision!(owner: owner, name: "Acme", subdomain: "acme")

    assert_equal Identity::Permissions::DEFAULT_ROLES.keys.sort, tenant.roles.pluck(:key).sort
    membership = owner.membership_for(tenant)
    assert membership.owner?
    assert_equal Identity::Permissions::KEYS.sort, membership.permissions.sort
  end

  test "switch sets the tenant context and the shard, then restores them" do
    tenant = create_tenant
    assert_nil Current.tenant

    tenant.switch do
      assert_equal tenant, Current.tenant
      assert_equal tenant.shard.to_sym, ApplicationRecord.current_shard
    end

    assert_nil Current.tenant
  end

  test "switch forbids nested shard switches" do
    tenant, other = create_tenant, create_tenant
    tenant.switch do
      assert_raises(ArgumentError) { other.switch { } }
    end
  end
end
