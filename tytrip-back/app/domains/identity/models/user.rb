# A person who can sign in. Users are global (catalog) and access
# organizations through memberships.
module Identity
  class User < CatalogRecord
    MAX_FAILED_LOGINS = 10
    LOCK_DURATION = 15.minutes
    RECOVERY_CODES_COUNT = 10

    has_secure_password
    encrypts :otp_secret

    enum :status, { active: "active", suspended: "suspended" }, default: "active", validate: true
    enum :platform_role, { super_admin: "super_admin" }, prefix: :platform, validate: { allow_nil: true }

    has_many :sessions, dependent: :delete_all
    has_many :memberships, dependent: :destroy
    has_many :tenants, through: :memberships

    normalizes :email, with: ->(email) { email.strip.downcase }
    normalizes :name, with: ->(name) { name.squish }

    validates :email, presence: true, uniqueness: true, length: { maximum: 254 },
      format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :name, presence: true, length: { maximum: 100 }
    validates :password, length: { minimum: 12 }, allow_nil: true
    validates :locale, inclusion: { in: %w[fr en] }
    validate :password_must_not_contain_email
    validate :time_zone_must_exist

    # Reset links are single use: changing the password changes the salt,
    # which invalidates every token generated before.
    generates_token_for :password_reset, expires_in: 30.minutes do
      password_salt.last(10)
    end

    generates_token_for :email_verification, expires_in: 2.days do
      [ email, email_verified_at ]
    end

    before_save -> { self.password_changed_at = Time.current }, if: :password_digest_changed?

    def email_verified?
      email_verified_at.present?
    end

    def verify_email!
      update!(email_verified_at: Time.current) unless email_verified?
    end

    def locked?
      locked_until&.future? || false
    end

    def register_failed_login!
      attempts = failed_login_attempts + 1
      if attempts >= MAX_FAILED_LOGINS
        update_columns(failed_login_attempts: 0, locked_until: LOCK_DURATION.from_now)
      else
        update_columns(failed_login_attempts: attempts)
      end
    end

    def register_successful_login!
      update_columns(failed_login_attempts: 0, locked_until: nil, last_sign_in_at: Time.current)
    end

    def membership_for(tenant)
      memberships.active.find_by(tenant: tenant) if tenant
    end

    # --- Two-factor authentication (TOTP, RFC 6238) ---

    def mfa_enabled?
      otp_enabled_at.present?
    end

    def otp_provisioning_uri
      ROTP::TOTP.new(otp_secret, issuer: "TyTrip").provisioning_uri(email)
    end

    def start_mfa_setup!
      raise ArgumentError, "MFA already enabled" if mfa_enabled?
      update!(otp_secret: ROTP::Base32.random)
    end

    # Returns the plain recovery codes; only their digests are stored.
    def enable_mfa!(code)
      return false if mfa_enabled? || otp_secret.blank? || !consume_otp!(code)
      codes = generate_recovery_codes!
      update!(otp_enabled_at: Time.current)
      codes
    end

    def disable_mfa!
      update!(otp_secret: nil, otp_enabled_at: nil, otp_last_used_at: nil, otp_recovery_code_digests: [])
    end

    # Accepts a TOTP code (each code is usable once) or a recovery code (consumed).
    def verify_second_factor!(code)
      return false unless mfa_enabled?
      consume_otp!(code) || consume_recovery_code!(code)
    end

    def generate_recovery_codes!
      codes = Array.new(RECOVERY_CODES_COUNT) { SecureRandom.alphanumeric(10).downcase.insert(5, "-") }
      update!(otp_recovery_code_digests: codes.map { |code| digest_recovery_code(code) })
      codes
    end

    private
      def consume_otp!(code)
        code = code.to_s.gsub(/\s/, "")
        return false unless code.match?(/\A\d{6}\z/)

        totp = ROTP::TOTP.new(otp_secret)
        verified_at = totp.verify(code, drift_behind: 30, drift_ahead: 30, after: otp_last_used_at&.to_i)
        return false unless verified_at

        update_columns(otp_last_used_at: Time.zone.at(verified_at))
        true
      end

      def consume_recovery_code!(code)
        digest = digest_recovery_code(code)
        return false unless otp_recovery_code_digests.include?(digest)

        update_columns(otp_recovery_code_digests: otp_recovery_code_digests - [ digest ])
        true
      end

      def digest_recovery_code(code)
        Digest::SHA256.hexdigest(code.to_s.strip.downcase)
      end

      def password_must_not_contain_email
        return if password.blank? || email.blank?
        errors.add(:password, :contains_email) if password.downcase.include?(email.split("@").first)
      end

      def time_zone_must_exist
        errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
      end
  end
end
