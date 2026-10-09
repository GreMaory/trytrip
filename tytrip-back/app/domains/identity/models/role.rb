module Identity
  class Role < CatalogRecord
    belongs_to :tenant
    has_many :memberships, dependent: :restrict_with_error
    has_many :invitations, dependent: :restrict_with_error

    normalizes :permissions, with: ->(permissions) { Array(permissions).map(&:to_s).uniq.sort }

    validates :name, presence: true, length: { maximum: 50 }, uniqueness: { scope: :tenant_id }
    validates :description, length: { maximum: 255 }
    validate :permissions_must_be_known
    validate :system_role_is_immutable, on: :update
    before_destroy :prevent_system_role_destruction

    def self.create_defaults_for!(tenant)
      Permissions::DEFAULT_ROLES.each do |key, attributes|
        tenant.roles.create!(key: key, **attributes)
      end
    end

    def self.owner!
      find_by!(key: "owner")
    end

    def owner?
      key == "owner"
    end

    # The owner role always grants every permission, including ones added later.
    def effective_permissions
      owner? ? Permissions::KEYS : permissions & Permissions::KEYS
    end

    private
      def permissions_must_be_known
        unknown = permissions - Permissions::KEYS
        errors.add(:permissions, :inclusion, value: unknown.join(", ")) if unknown.any?
      end

      def system_role_is_immutable
        errors.add(:base, :system_role_immutable) if system? && (changed - %w[updated_at]).any?
      end

      def prevent_system_role_destruction
        if system?
          errors.add(:base, :system_role_undeletable)
          throw :abort
        end
      end
  end
end
