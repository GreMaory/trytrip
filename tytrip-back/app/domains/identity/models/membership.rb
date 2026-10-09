# A user's access to an organization, with exactly one role.
module Identity
  class Membership < CatalogRecord
    belongs_to :user
    belongs_to :tenant
    belongs_to :role

    enum :status, { active: "active", suspended: "suspended" }, default: "active", validate: true

    validates :user_id, uniqueness: { scope: :tenant_id }
    validate :role_must_belong_to_tenant

    scope :owners, -> { joins(:role).where(roles: { key: "owner" }) }

    delegate :owner?, to: :role

    def permissions
      active? ? role.effective_permissions : []
    end

    def can?(permission)
      permissions.include?(permission.to_s)
    end

    # Last active owner of the organization: cannot be demoted, suspended or removed.
    def last_owner?
      owner? && tenant.memberships.active.owners.where.not(id: id).none?
    end

    private
      def role_must_belong_to_tenant
        errors.add(:role, :invalid) if role && role.tenant_id != tenant_id
      end
  end
end
