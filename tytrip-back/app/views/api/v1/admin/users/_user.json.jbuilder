json.extract! user, :id, :name, :email, :status, :platform_role, :last_sign_in_at, :created_at
json.email_verified user.email_verified?
json.mfa_enabled user.mfa_enabled?
json.locked user.locked?
