module Api
  module V1
    # Self-service sign up: creates the user and their organization.
    class SignupsController < BaseController
      allow_unauthenticated_access
      rate_limit to: 5, within: 1.hour, with: -> { rate_limited }

      def create
        user = Identity::User.new(params.expect(user: %i[name email password]))
        tenant = nil
        Identity::Tenant.transaction do
          user.save!
          tenant = Identity::Tenant.provision!(owner: user, **params.expect(organization: %i[name subdomain]).to_h.symbolize_keys)
        end

        audit!("organization.created", subject: tenant, actor: user, tenant: tenant)
        UserMailer.with(user: user).email_verification.deliver_later
        start_new_session_for(user)
        render json: { data: { organization: { id: tenant.id, name: tenant.name, subdomain: tenant.subdomain, host: tenant.host } } },
          status: :created
      end
    end
  end
end
