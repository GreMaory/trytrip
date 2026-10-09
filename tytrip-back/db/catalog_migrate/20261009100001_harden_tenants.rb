# Tenants become the organizations: they get a display name, a shard key
# (see config/shards.yml) instead of a numeric shard id, and NOT NULL
# constraints on the routing columns.
class HardenTenants < ActiveRecord::Migration[8.0]
  SHARD_KEYS = { 1 => "shard_one", 2 => "shard_two" }.freeze

  def up
    add_column :tenants, :name, :string
    add_column :tenants, :shard, :string
    add_column :tenants, :suspended_at, :datetime
    add_column :tenants, :time_zone, :string, null: false, default: "Europe/Paris"
    add_column :tenants, :locale, :string, null: false, default: "fr"
    add_column :tenants, :currency, :string, null: false, default: "EUR", limit: 3
    add_column :tenants, :settings, :jsonb, null: false, default: {}

    execute <<~SQL
      UPDATE tenants SET
        name = COALESCE(name, subdomain),
        status = COALESCE(status, 'active'),
        shard = CASE shard_id #{SHARD_KEYS.map { |id, key| "WHEN #{id} THEN '#{key}'" }.join(" ")} ELSE 'shard_one' END
    SQL

    change_column_null :tenants, :name, false
    change_column_null :tenants, :shard, false
    change_column_null :tenants, :subdomain, false
    change_column_null :tenants, :status, false
    change_column_default :tenants, :status, from: nil, to: "active"
    remove_column :tenants, :shard_id
    add_index :tenants, :shard
    add_check_constraint :tenants, "status IN ('active', 'suspended')", name: "tenants_status_check"
  end

  def down
    remove_check_constraint :tenants, name: "tenants_status_check"
    add_column :tenants, :shard_id, :integer
    execute <<~SQL
      UPDATE tenants SET shard_id = CASE shard #{SHARD_KEYS.map { |id, key| "WHEN '#{key}' THEN #{id}" }.join(" ")} END
    SQL
    remove_index :tenants, :shard
    remove_columns :tenants, :name, :shard, :suspended_at, :time_zone, :locale, :currency, :settings
    change_column_null :tenants, :subdomain, true
    change_column_null :tenants, :status, true
    change_column_default :tenants, :status, from: "active", to: nil
  end
end
