module Api
  module V1
    # Public endpoints used from the invitation email link (portal).
    #   GET  /invitation_acceptance?token=   -> invitation summary
    #   POST /invitation_acceptance {token, name?, password?}
    # If no account exists for the invited email, one is created with the
    # given name and password. The user is then signed in.
    class InvitationAcceptancesController < BaseController
      allow_unauthenticated_access
      rate_limit to: 20, within: 15.minutes, with: -> { rate_limited }
      before_action :set_invitation

      def show
        render json: { data: {
          email: @invitation.email,
          organization: { name: @invitation.tenant.name, subdomain: @invitation.tenant.subdomain },
          role: @invitation.role.name,
          existing_account: Identity::User.exists?(email: @invitation.email),
          expires_at: @invitation.expires_at
        } }
      end

      def create
        user = Identity::User.find_by(email: @invitation.email)
        if user.nil?
          user = Identity::User.new(email: @invitation.email, name: params.require(:name), password: params.require(:password))
          user.save!
        elsif !user.authenticate(params.require(:password).to_s)
          # Existing accounts confirm with their password: the email link alone
          # must not be enough to open a session on an existing account.
          return render_error(:unauthorized, t_api(:invalid_credentials), code: "invalid_credentials")
        end
        return render_error(:forbidden, t_api(:account_suspended)) if user.suspended?

        @invitation.accept!(user)
        Audit::Event.record!("invitation.accepted", subject: @invitation, actor: user, tenant: @invitation.tenant)

        if user.mfa_enabled?
          render json: { data: { organization: { subdomain: @invitation.tenant.subdomain }, signed_in: false } }
        else
          start_new_session_for(user)
          render json: { data: { organization: { subdomain: @invitation.tenant.subdomain }, signed_in: true } }
        end
      end

      private
        def set_invitation
          @invitation = Identity::Invitation.find_pending_by_token(params.require(:token).to_s)
          render_error(:not_found, t_api(:invalid_invitation), code: "invalid_token") unless @invitation
        end
    end
  end
end
