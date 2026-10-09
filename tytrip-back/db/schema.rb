# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_10_09_120001) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "btree_gist"
  enable_extension "pg_catalog.plpgsql"

  create_table "availability_blocks", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "unit_id", null: false
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.string "reason", default: "owner", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["unit_id"], name: "index_availability_blocks_on_unit_id"
    t.check_constraint "ends_on > starts_on", name: "availability_blocks_dates_check"
    t.exclusion_constraint "unit_id WITH =, daterange(starts_on, ends_on, '[)'::text) WITH &&", using: :gist, name: "availability_blocks_no_overlap"
  end

  create_table "guests", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "first_name", null: false
    t.string "last_name", null: false
    t.string "email"
    t.string "phone"
    t.string "country_code", limit: 2
    t.string "language", limit: 5
    t.text "notes"
    t.boolean "marketing_consent", default: false, null: false
    t.datetime "marketing_consent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "email"], name: "index_guests_on_tenant_id_and_email"
    t.index ["tenant_id", "last_name"], name: "index_guests_on_tenant_id_and_last_name"
  end

  create_table "properties", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.string "property_type", default: "apartment", null: false
    t.string "status", default: "active", null: false
    t.text "description"
    t.string "address_line1"
    t.string "address_line2"
    t.string "postal_code"
    t.string "city"
    t.string "country_code", limit: 2
    t.decimal "latitude", precision: 9, scale: 6
    t.decimal "longitude", precision: 9, scale: 6
    t.string "time_zone", default: "Europe/Paris", null: false
    t.string "check_in_time", default: "16:00", null: false
    t.string "check_out_time", default: "11:00", null: false
    t.text "house_rules"
    t.text "access_instructions"
    t.string "amenities", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "name"], name: "index_properties_on_tenant_id_and_name"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'archived'::character varying]::text[])", name: "properties_status_check"
  end

  create_table "reservations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "unit_id", null: false
    t.bigint "guest_id", null: false
    t.string "reference", null: false
    t.string "status", default: "pending", null: false
    t.string "source", default: "direct", null: false
    t.date "check_in", null: false
    t.date "check_out", null: false
    t.integer "adults", default: 1, null: false
    t.integer "children", default: 0, null: false
    t.decimal "nightly_rate", precision: 12, scale: 2, null: false
    t.decimal "total_amount", precision: 12, scale: 2, null: false
    t.string "currency", limit: 3, null: false
    t.text "notes"
    t.text "special_requests"
    t.datetime "confirmed_at"
    t.datetime "checked_in_at"
    t.datetime "checked_out_at"
    t.datetime "cancelled_at"
    t.string "cancellation_reason"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["guest_id"], name: "index_reservations_on_guest_id"
    t.index ["tenant_id", "check_in"], name: "index_reservations_on_tenant_id_and_check_in"
    t.index ["tenant_id", "check_out"], name: "index_reservations_on_tenant_id_and_check_out"
    t.index ["tenant_id", "reference"], name: "index_reservations_on_tenant_id_and_reference", unique: true
    t.index ["unit_id"], name: "index_reservations_on_unit_id"
    t.check_constraint "adults >= 1 AND children >= 0 AND total_amount >= 0::numeric AND nightly_rate >= 0::numeric", name: "reservations_values_check"
    t.check_constraint "check_out > check_in", name: "reservations_dates_check"
    t.check_constraint "status::text = ANY (ARRAY['pending'::character varying, 'confirmed'::character varying, 'checked_in'::character varying, 'checked_out'::character varying, 'cancelled'::character varying, 'no_show'::character varying]::text[])", name: "reservations_status_check"
    t.exclusion_constraint "unit_id WITH =, daterange(check_in, check_out, '[)'::text) WITH &&", where: "(status)::text = ANY ((ARRAY['pending'::character varying, 'confirmed'::character varying, 'checked_in'::character varying])::text[])", using: :gist, name: "reservations_no_overlap"
  end

  create_table "units", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "property_id", null: false
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.integer "max_guests", default: 2, null: false
    t.integer "bedrooms", default: 1, null: false
    t.integer "beds", default: 1, null: false
    t.decimal "bathrooms", precision: 3, scale: 1, default: "1.0", null: false
    t.decimal "base_rate", precision: 12, scale: 2, default: "0.0", null: false
    t.integer "min_stay", default: 1, null: false
    t.integer "max_stay"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_units_on_property_id"
    t.index ["tenant_id", "property_id"], name: "index_units_on_tenant_id_and_property_id"
    t.check_constraint "max_guests > 0 AND base_rate >= 0::numeric AND min_stay >= 1 AND (max_stay IS NULL OR max_stay >= min_stay)", name: "units_values_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'inactive'::character varying]::text[])", name: "units_status_check"
  end

  add_foreign_key "availability_blocks", "units"
  add_foreign_key "reservations", "guests"
  add_foreign_key "reservations", "units"
  add_foreign_key "units", "properties"
end
