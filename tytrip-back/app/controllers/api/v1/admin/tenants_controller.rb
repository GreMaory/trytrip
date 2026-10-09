module Api
  module V1
    module Admin
      class TenantsController < BaseController
        before_action :set_tenant, except: %i[index create]

        def index
          scope = Identity::Tenant.order(:name)
          scope = scope.where(status: params[:status]) if Identity::Tenant.statuses.key?(params[:status])
          if params[:q].present?
            term = "%#{Identity::Tenant.sanitize_sql_like(params[:q].to_s)}%"
            scope = scope.where("name ILIKE :term OR subdomain ILIKE :term", term: term)
          end
          @tenants = paginate(scope)
          @member_counts = Identity::Membership.where(tenant: @tenants).group(:tenant_id).count
        end

        def show
          @member_counts = { @tenant.id => @tenant.memberships.count }
        end

        # Creates the organization and invites its owner by email.
        def create
          owner_email = params.require(:owner_email)
          Identity::Tenant.transaction do
            @tenant = Identity::Tenant.create!(params.expect(organization: %i[name subdomain time_zone locale currency]))
            Identity::Role.create_defaults_for!(@tenant)
            @invitation = @tenant.invitations.create!(email: owner_email, role: @tenant.roles.owner!, invited_by: current_user)
          end
          InvitationMailer.with(invitation: @invitation, token: @invitation.token).invite.deliver_later
          audit!("admin.organization.created", subject: @tenant, tenant: @tenant, metadata: { owner_email: owner_email })
          @member_counts = {}
          render :show, status: :created
        end

        def update
          @tenant.update!(params.expect(organization: %i[name time_zone locale currency]))
          audit!("admin.organization.updated", subject: @tenant, tenant: @tenant)
          show
          render :show
        end

        def suspend
          @tenant.suspend!
          audit!("admin.organization.suspended", subject: @tenant, tenant: @tenant)
          show
          render :show
        end

        def activate
          @tenant.activate!
          audit!("admin.organization.activated", subject: @tenant, tenant: @tenant)
          show
          render :show
        end

        private
          def set_tenant
            @tenant = Identity::Tenant.find(params[:id])
          end
      end
    end
  end
end
