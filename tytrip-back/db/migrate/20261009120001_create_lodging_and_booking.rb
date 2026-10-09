# Tenant business data (applied to every tenant shard). Every table carries
# tenant_id: a shard can host several tenants (see TenantScoped).
class CreateLodgingAndBooking < ActiveRecord::Migration[8.0]
  def change
    enable_extension "btree_gist"

    create_table :properties do |t|
      t.bigint :tenant_id, null: false
      t.string :name, null: false
      t.string :property_type, null: false, default: "apartment"
      t.string :status, null: false, default: "active"
      t.text :description
      t.string :address_line1
      t.string :address_line2
      t.string :postal_code
      t.string :city
      t.string :country_code, limit: 2
      t.decimal :latitude, precision: 9, scale: 6
      t.decimal :longitude, precision: 9, scale: 6
      t.string :time_zone, null: false, default: "Europe/Paris"
      t.string :check_in_time, null: false, default: "16:00"
      t.string :check_out_time, null: false, default: "11:00"
      t.text :house_rules
      t.text :access_instructions
      t.string :amenities, array: true, null: false, default: []
      t.timestamps
    end
    add_index :properties, [ :tenant_id, :name ]
    add_check_constraint :properties, "status IN ('active', 'archived')", name: "properties_status_check"

    create_table :units do |t|
      t.bigint :tenant_id, null: false
      t.references :property, null: false, foreign_key: true
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.integer :max_guests, null: false, default: 2
      t.integer :bedrooms, null: false, default: 1
      t.integer :beds, null: false, default: 1
      t.decimal :bathrooms, precision: 3, scale: 1, null: false, default: 1
      t.decimal :base_rate, precision: 12, scale: 2, null: false, default: 0
      t.integer :min_stay, null: false, default: 1
      t.integer :max_stay
      t.timestamps
    end
    add_index :units, [ :tenant_id, :property_id ]
    add_check_constraint :units, "status IN ('active', 'inactive')", name: "units_status_check"
    add_check_constraint :units, "max_guests > 0 AND base_rate >= 0 AND min_stay >= 1 AND (max_stay IS NULL OR max_stay >= min_stay)",
      name: "units_values_check"

    create_table :guests do |t|
      t.bigint :tenant_id, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :email
      t.string :phone
      t.string :country_code, limit: 2
      t.string :language, limit: 5
      t.text :notes
      t.boolean :marketing_consent, null: false, default: false
      t.datetime :marketing_consent_at
      t.timestamps
    end
    add_index :guests, [ :tenant_id, :last_name ]
    add_index :guests, [ :tenant_id, :email ]

    create_table :reservations do |t|
      t.bigint :tenant_id, null: false
      t.references :unit, null: false, foreign_key: true
      t.references :guest, null: false, foreign_key: true
      t.string :reference, null: false
      t.string :status, null: false, default: "pending"
      t.string :source, null: false, default: "direct"
      t.date :check_in, null: false
      t.date :check_out, null: false
      t.integer :adults, null: false, default: 1
      t.integer :children, null: false, default: 0
      t.decimal :nightly_rate, precision: 12, scale: 2, null: false
      t.decimal :total_amount, precision: 12, scale: 2, null: false
      t.string :currency, limit: 3, null: false
      t.text :notes
      t.text :special_requests
      t.datetime :confirmed_at
      t.datetime :checked_in_at
      t.datetime :checked_out_at
      t.datetime :cancelled_at
      t.string :cancellation_reason
      t.bigint :created_by_id # catalog user (cross-database, no foreign key)
      t.timestamps
    end
    add_index :reservations, [ :tenant_id, :reference ], unique: true
    add_index :reservations, [ :tenant_id, :check_in ]
    add_index :reservations, [ :tenant_id, :check_out ]
    add_check_constraint :reservations, "check_out > check_in", name: "reservations_dates_check"
    add_check_constraint :reservations, "adults >= 1 AND children >= 0 AND total_amount >= 0 AND nightly_rate >= 0",
      name: "reservations_values_check"
    add_check_constraint :reservations,
      "status IN ('pending', 'confirmed', 'checked_in', 'checked_out', 'cancelled', 'no_show')",
      name: "reservations_status_check"

    create_table :availability_blocks do |t|
      t.bigint :tenant_id, null: false
      t.references :unit, null: false, foreign_key: true
      t.date :starts_on, null: false
      t.date :ends_on, null: false # exclusive, like a check-out date
      t.string :reason, null: false, default: "owner"
      t.string :note
      t.timestamps
    end
    add_check_constraint :availability_blocks, "ends_on > starts_on", name: "availability_blocks_dates_check"

    # Last line of defense against double bookings, safe under concurrency:
    # two live reservations (or two blocks) of a unit can never overlap.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          ALTER TABLE reservations ADD CONSTRAINT reservations_no_overlap
            EXCLUDE USING gist (unit_id WITH =, daterange(check_in, check_out, '[)') WITH &&)
            WHERE (status IN ('pending', 'confirmed', 'checked_in'));
          ALTER TABLE availability_blocks ADD CONSTRAINT availability_blocks_no_overlap
            EXCLUDE USING gist (unit_id WITH =, daterange(starts_on, ends_on, '[)') WITH &&);
        SQL
      end
    end
  end
end
