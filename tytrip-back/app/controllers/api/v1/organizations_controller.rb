module Api
  module V1
    # The current organization (tenant subdomain), and creation of additional
    # organizations by a signed-in user.
    class OrganizationsController < BaseController
      before_action :require_tenant_membership, only: %i[show update]
      before_action -> { authorize!("organization.manage") }, only: :update

      def show
        @tenant = Current.tenant
      end

      def create
        @tenant = Identity::Tenant.provision!(owner: current_user, **params.expect(organization: %i[name subdomain]).to_h.symbolize_keys)
        audit!("organization.created", subject: @tenant, tenant: @tenant)
        render :show, status: :created
      end

      def update
        @tenant = Current.tenant
        @tenant.update!(params.expect(organization: [ :name, :time_zone, :locale, :currency ]))
        audit!("organization.updated", subject: @tenant, metadata: { changes: @tenant.saved_changes.except("updated_at").keys })
        render :show
      end
    end
  end
end
