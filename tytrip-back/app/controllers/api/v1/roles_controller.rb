module Api
  module V1
    class RolesController < BaseController
      before_action -> { authorize!("members.read") }, only: %i[index show]
      before_action -> { authorize!("roles.manage") }, except: %i[index show]
      before_action :set_role, only: %i[show update destroy]

      def index
        @roles = Current.tenant.roles.order(:system, :name).reverse_order
        @member_counts = Identity::Membership.where(role: @roles).group(:role_id).count
      end

      def show
      end

      def create
        @role = Current.tenant.roles.new(role_params)
        ensure_grantable!(@role.permissions)
        @role.save!
        audit!("role.created", subject: @role, metadata: { permissions: @role.permissions })
        render :show, status: :created
      end

      def update
        @role.assign_attributes(role_params)
        ensure_grantable!(@role.permissions)
        ensure_grantable!(@role.permissions_was) # cannot edit a role more powerful than oneself
        @role.save!
        audit!("role.updated", subject: @role, metadata: { permissions: @role.permissions })
        render :show
      end

      def destroy
        ensure_grantable!(@role.effective_permissions)
        @role.destroy!
        audit!("role.deleted", subject: @role, metadata: { name: @role.name })
        head :no_content
      end

      private
        def set_role
          @role = Current.tenant.roles.find(params[:id])
        end

        def role_params
          params.expect(role: [ :name, :description, permissions: [] ])
        end

        def ensure_grantable!(permissions)
          unless Identity::AccessPolicy.new(Current.membership).can_grant_permissions?(permissions)
            raise ApiErrors::Forbidden, t_api(:cannot_grant_permissions)
          end
        end
    end
  end
end
