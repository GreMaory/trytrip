# Rules preventing privilege escalation inside an organization, on top of
# the plain permission checks (members.manage, roles.manage).
#
# - Nobody can grant permissions they do not have themselves.
# - Only owners can grant the owner role or modify an owner's membership.
# - Nobody can change their own role or status.
module Identity
  class AccessPolicy
    def initialize(actor_membership)
      @actor = actor_membership
    end

    def can_grant_permissions?(permissions)
      @actor.owner? || (Array(permissions) - @actor.permissions).empty?
    end

    def can_assign_role?(role)
      return false unless role.tenant_id == @actor.tenant_id
      return @actor.owner? if role.owner?

      can_grant_permissions?(role.effective_permissions)
    end

    def can_manage_membership?(membership)
      return false if membership.id == @actor.id || membership.tenant_id != @actor.tenant_id
      return @actor.owner? if membership.owner?

      can_grant_permissions?(membership.role.effective_permissions)
    end
  end
end
