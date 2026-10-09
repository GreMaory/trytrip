# Invitation of an email address to join an organization with a role.
module Identity
  class Invitation < CatalogRecord
    LIFETIME = 7.days

    belongs_to :tenant
    belongs_to :role
    belongs_to :invited_by, class_name: "Identity::User"

    normalizes :email, with: ->(email) { email.strip.downcase }

    validates :email, presence: true, length: { maximum: 254 }, format: { with: URI::MailTo::EMAIL_REGEXP }
    validates :email, uniqueness: { scope: :tenant_id, conditions: -> { pending_or_expired } }, on: :create
    validate :role_must_belong_to_tenant
    validate :email_must_not_be_member, on: :create

    scope :pending_or_expired, -> { where(accepted_at: nil, revoked_at: nil) }
    scope :pending, -> { pending_or_expired.where(expires_at: Time.current..) }

    attr_reader :token

    before_validation :generate_token, on: :create

    def self.find_pending_by_token(token)
      pending.includes(:tenant, :role).find_by(token_digest: Session.digest(token)) if token.present?
    end

    def pending?
      accepted_at.nil? && revoked_at.nil? && expires_at.future?
    end

    def revoke!
      update!(revoked_at: Time.current)
    end

    # Creates the membership. The invitation token was delivered to the
    # invited address, so accepting it also proves ownership of that email.
    def accept!(user)
      raise ActiveRecord::RecordInvalid, self unless pending? && user.email == email

      transaction do
        update!(accepted_at: Time.current)
        user.verify_email!
        tenant.memberships.create!(user: user, role: role)
      end
    end

    private
      def generate_token
        @token = SecureRandom.urlsafe_base64(32)
        self.token_digest = Session.digest(@token)
        self.expires_at ||= LIFETIME.from_now
      end

      def role_must_belong_to_tenant
        errors.add(:role, :invalid) if role && role.tenant_id != tenant_id
      end

      def email_must_not_be_member
        if tenant && tenant.memberships.joins(:user).exists?(users: { email: email })
          errors.add(:email, :taken)
        end
      end
  end
end
