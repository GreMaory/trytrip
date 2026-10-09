# A signed-in browser. The raw token only lives in an encrypted, HttpOnly
# cookie; the database stores its SHA-256 digest.
module Identity
  class Session < CatalogRecord
    LIFETIME = 30.days
    LAST_SEEN_PRECISION = 5.minutes

    belongs_to :user

    scope :active, -> { where(revoked_at: nil).where(expires_at: Time.current..) }

    attr_reader :token

    before_validation :generate_token, on: :create

    def self.digest(token)
      Digest::SHA256.hexdigest(token.to_s)
    end

    def self.find_active_by_token(token)
      active.includes(:user).find_by(token_digest: digest(token)) if token.present?
    end

    def revoke!
      update!(revoked_at: Time.current) unless revoked_at
    end

    def active?
      revoked_at.nil? && expires_at.future?
    end

    def touch_last_seen!
      if last_seen_at.nil? || last_seen_at < LAST_SEEN_PRECISION.ago
        update_columns(last_seen_at: Time.current)
      end
    end

    private
      def generate_token
        @token = SecureRandom.urlsafe_base64(32)
        self.token_digest = self.class.digest(@token)
        self.expires_at ||= LIFETIME.from_now
      end
  end
end
