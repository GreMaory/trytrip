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

ActiveRecord::Schema[8.0].define(version: 2026_10_09_100002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "audit_events", force: :cascade do |t|
    t.bigint "tenant_id"
    t.bigint "actor_id"
    t.string "action", null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.jsonb "metadata", default: {}, null: false
    t.string "ip_address"
    t.string "user_agent"
    t.string "request_id"
    t.datetime "created_at", null: false
    t.index ["action"], name: "index_audit_events_on_action"
    t.index ["actor_id"], name: "index_audit_events_on_actor_id"
    t.index ["subject_type", "subject_id"], name: "index_audit_events_on_subject_type_and_subject_id"
    t.index ["tenant_id", "created_at"], name: "index_audit_events_on_tenant_id_and_created_at"
    t.index ["tenant_id"], name: "index_audit_events_on_tenant_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "role_id", null: false
    t.bigint "invited_by_id", null: false
    t.string "email", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["role_id"], name: "index_invitations_on_role_id"
    t.index ["tenant_id", "email"], name: "index_invitations_pending_unique", unique: true, where: "((accepted_at IS NULL) AND (revoked_at IS NULL))"
    t.index ["tenant_id"], name: "index_invitations_on_tenant_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "tenant_id", null: false
    t.bigint "role_id", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["role_id"], name: "index_memberships_on_role_id"
    t.index ["tenant_id"], name: "index_memberships_on_tenant_id"
    t.index ["user_id", "tenant_id"], name: "index_memberships_on_user_id_and_tenant_id", unique: true
    t.index ["user_id"], name: "index_memberships_on_user_id"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "memberships_status_check"
  end

  create_table "roles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "key"
    t.string "name", null: false
    t.string "description"
    t.string "permissions", default: [], null: false, array: true
    t.boolean "system", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "key"], name: "index_roles_on_tenant_id_and_key", unique: true, where: "(key IS NOT NULL)"
    t.index ["tenant_id", "name"], name: "index_roles_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_roles_on_tenant_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "token_digest", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "last_seen_at"
    t.datetime "expires_at", null: false
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["token_digest"], name: "index_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "subdomain", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", null: false
    t.string "shard", null: false
    t.datetime "suspended_at"
    t.string "time_zone", default: "Europe/Paris", null: false
    t.string "locale", default: "fr", null: false
    t.string "currency", limit: 3, default: "EUR", null: false
    t.jsonb "settings", default: {}, null: false
    t.index ["shard"], name: "index_tenants_on_shard"
    t.index ["subdomain"], name: "index_tenants_on_subdomain", unique: true
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "tenants_status_check"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "status", default: "active", null: false
    t.string "platform_role"
    t.datetime "email_verified_at"
    t.string "locale", default: "fr", null: false
    t.string "time_zone", default: "Europe/Paris", null: false
    t.jsonb "preferences", default: {}, null: false
    t.integer "failed_login_attempts", default: 0, null: false
    t.datetime "locked_until"
    t.datetime "last_sign_in_at"
    t.datetime "password_changed_at"
    t.text "otp_secret"
    t.datetime "otp_enabled_at"
    t.datetime "otp_last_used_at"
    t.string "otp_recovery_code_digests", default: [], null: false, array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.check_constraint "platform_role IS NULL OR platform_role::text = 'super_admin'::text", name: "users_platform_role_check"
    t.check_constraint "status::text = ANY (ARRAY['active'::character varying, 'suspended'::character varying]::text[])", name: "users_status_check"
  end

  add_foreign_key "audit_events", "tenants"
  add_foreign_key "audit_events", "users", column: "actor_id"
  add_foreign_key "invitations", "roles"
  add_foreign_key "invitations", "tenants"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "roles"
  add_foreign_key "memberships", "tenants"
  add_foreign_key "memberships", "users"
  add_foreign_key "roles", "tenants"
  add_foreign_key "sessions", "users"
end
