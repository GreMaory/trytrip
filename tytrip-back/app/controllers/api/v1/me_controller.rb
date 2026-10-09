module Api
  module V1
    # The signed-in user: profile, preferences, organizations and, on a tenant
    # subdomain, the membership and permissions in that organization.
    class MeController < BaseController
      def show
        @user = current_user
        @memberships = current_user.memberships.active.includes(:tenant, :role).where(tenants: { status: "active" })
        @current_membership = current_user.membership_for(Current.tenant)
      end

      def update
        current_user.update!(params.expect(user: [ :name, :locale, :time_zone, preferences: {} ]))
        head :no_content
      end
    end
  end
end
