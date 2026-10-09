require "test_helper"

class TenantScopedTest < ActiveSupport::TestCase
  setup do
    # Both tenants on the same shard: isolation must come from tenant scoping,
    # not only from the shard switch.
    @acme = create_tenant(subdomain: "acme", shard: "shard_one")
    @globex = create_tenant(subdomain: "globex", shard: "shard_one")
    @acme_property = @acme.switch { Lodging::Property.create!(name: "Acme Villa") }
    @globex_property = @globex.switch { Lodging::Property.create!(name: "Globex Loft") }
  end

  test "tenant data is only visible to its tenant, even on a shared shard" do
    @acme.switch do
      assert_equal [ "Acme Villa" ], Lodging::Property.pluck(:name)
      assert_raises(ActiveRecord::RecordNotFound) { Lodging::Property.find(@globex_property.id) }
      assert_equal 0, Lodging::Property.where(id: @globex_property.id).update_all(name: "pwned")
    end
    assert_equal "Globex Loft", @globex.switch { Lodging::Property.find(@globex_property.id).name }
  end

  test "new records belong to the current tenant and cannot be moved" do
    @acme.switch do
      property = Lodging::Property.create!(name: "New")
      assert_equal @acme.id, property.tenant_id
      assert_raises(ActiveRecord::ReadonlyAttributeError) { property.update!(tenant_id: @globex.id) }

      forged = Lodging::Property.new(name: "Forged", tenant_id: @globex.id)
      assert_not forged.valid?
    end
  end

  test "tenant data access without tenant context fails closed" do
    assert_raises(Current::TenantMissing) { Lodging::Property.count }
    assert_raises(Current::TenantMissing) { Lodging::Property.new(name: "x") }
  end

  test "querying while connected to another shard fails closed" do
    Current.set(tenant: @acme) do
      ApplicationRecord.connected_to(shard: :shard_two) do
        assert_raises(TenantScoped::ShardMismatch) { Lodging::Property.count }
      end
    end
  end

  test "data lives on the tenant's shard" do
    tenant = create_tenant(shard: "shard_two")
    tenant.switch { Lodging::Property.create!(name: "Shard two villa") }
    rows = ApplicationRecord.connected_to(shard: :shard_two) do
      ApplicationRecord.connection.select_values("SELECT name FROM properties WHERE tenant_id = #{tenant.id}")
    end
    assert_equal [ "Shard two villa" ], rows
    rows = ApplicationRecord.connected_to(shard: :shard_one) do
      ApplicationRecord.connection.select_values("SELECT name FROM properties WHERE tenant_id = #{tenant.id}")
    end
    assert_empty rows
  end
end
