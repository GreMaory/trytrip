module Api
  module V1
    class MembershipsController < BaseController
      before_action -> { authorize!("members.read") }, only: :index
      before_action -> { authorize!("members.manage") }, except: :index
      before_action :set_membership, except: :index

      def index
        scope = Current.tenant.memberships.includes(:user, :role).joins(:user).order("users.name")
        if params[:q].present?
          term = "%#{Identity::Membership.sanitize_sql_like(params[:q].to_s)}%"
          scope = scope.where("users.name ILIKE :term OR users.email ILIKE :term", term: term)
        end
        @memberships = paginate(scope)
      end

      def update
        attributes = params.expect(membership: %i[role_id status])
        if attributes[:role_id]
          role = Current.tenant.roles.find(attributes[:role_id])
          raise ApiErrors::Forbidden, t_api(:cannot_assign_role) unless policy.can_assign_role?(role)
          @membership.role = role
        end
        @membership.status = attributes[:status] if attributes[:status]
        ensure_owner_remains!

        @membership.save!
        audit!("membership.updated", subject: @membership,
          metadata: { user_id: @membership.user_id, changes: @membership.saved_changes.except("updated_at") })
        render :show
      end

      def destroy
        ensure_owner_remains!
        @membership.destroy!
        audit!("membership.removed", subject: @membership, metadata: { user_id: @membership.user_id })
        head :no_content
      end

      private
        def set_membership
          @membership = Current.tenant.memberships.find(params[:id])
          raise ApiErrors::Forbidden, t_api(:cannot_manage_member) unless policy.can_manage_membership?(@membership)
        end

        def policy
          @policy ||= Identity::AccessPolicy.new(Current.membership)
        end

        # Defense in depth: AccessPolicy already prevents touching one's own
        # membership, so the last owner cannot normally be reached.
        def ensure_owner_remains!
          stays_owner = action_name != "destroy" && @membership.active? && @membership.role.owner?
          others = Current.tenant.memberships.active.owners.where.not(id: @membership.id).exists?
          raise ApiErrors::Forbidden, t_api(:last_owner) unless stays_owner || others
        end
    end
  end
end
