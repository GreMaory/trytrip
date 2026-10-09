class CreateIdentityTables < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name, null: false
      t.string :password_digest, null: false
      t.string :status, null: false, default: "active"
      t.string :platform_role
      t.datetime :email_verified_at
      t.string :locale, null: false, default: "fr"
      t.string :time_zone, null: false, default: "Europe/Paris"
      t.jsonb :preferences, null: false, default: {}

      t.integer :failed_login_attempts, null: false, default: 0
      t.datetime :locked_until
      t.datetime :last_sign_in_at
      t.datetime :password_changed_at

      # Two-factor authentication (TOTP). otp_secret is encrypted by Active Record.
      t.text :otp_secret
      t.datetime :otp_enabled_at
      t.datetime :otp_last_used_at # anti-replay: codes at or before this time are rejected
      t.string :otp_recovery_code_digests, array: true, null: false, default: []

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_check_constraint :users, "status IN ('active', 'suspended')", name: "users_status_check"
    add_check_constraint :users, "platform_role IS NULL OR platform_role IN ('super_admin')", name: "users_platform_role_check"

    create_table :sessions do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token_digest, null: false
      t.string :ip_address
      t.string :user_agent
      t.datetime :last_seen_at
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :sessions, :token_digest, unique: true

    create_table :roles do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :key
      t.string :name, null: false
      t.string :description
      t.string :permissions, array: true, null: false, default: []
      t.boolean :system, null: false, default: false
      t.timestamps
    end
    add_index :roles, [ :tenant_id, :name ], unique: true
    add_index :roles, [ :tenant_id, :key ], unique: true, where: "key IS NOT NULL"

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :tenant, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.string :status, null: false, default: "active"
      t.timestamps
    end
    add_index :memberships, [ :user_id, :tenant_id ], unique: true
    add_check_constraint :memberships, "status IN ('active', 'suspended')", name: "memberships_status_check"

    create_table :invitations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.references :invited_by, null: false, foreign_key: { to_table: :users }
      t.string :email, null: false
      t.string :token_digest, null: false
      t.datetime :expires_at, null: false
      t.datetime :accepted_at
      t.datetime :revoked_at
      t.timestamps
    end
    add_index :invitations, :token_digest, unique: true
    add_index :invitations, [ :tenant_id, :email ], unique: true,
      where: "accepted_at IS NULL AND revoked_at IS NULL", name: "index_invitations_pending_unique"

    # Append-only security / business audit trail. Never store secrets here.
    create_table :audit_events do |t|
      t.references :tenant, foreign_key: true
      t.references :actor, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type
      t.bigint :subject_id
      t.jsonb :metadata, null: false, default: {}
      t.string :ip_address
      t.string :user_agent
      t.string :request_id
      t.datetime :created_at, null: false
    end
    add_index :audit_events, [ :tenant_id, :created_at ]
    add_index :audit_events, [ :subject_type, :subject_id ]
    add_index :audit_events, :action
  end
end
