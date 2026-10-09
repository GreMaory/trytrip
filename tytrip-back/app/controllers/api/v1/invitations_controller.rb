module Api
  module V1
    # Invitations sent by an organization (tenant subdomain).
    class InvitationsController < BaseController
      before_action -> { authorize!("members.manage") }
      rate_limit to: 30, within: 1.hour, only: :create, with: -> { rate_limited }

      def index
        @invitations = Current.tenant.invitations.pending.includes(:role, :invited_by).order(created_at: :desc)
      end

      def create
        unless current_user.email_verified?
          return render_error(:forbidden, t_api(:email_not_verified), code: "email_not_verified")
        end

        attributes = params.expect(invitation: %i[email role_id])
        role = Current.tenant.roles.find(attributes[:role_id])
        raise ApiErrors::Forbidden, t_api(:cannot_assign_role) unless Identity::AccessPolicy.new(Current.membership).can_assign_role?(role)

        # An expired invitation for the same email is replaced.
        Current.tenant.invitations.pending_or_expired.where(email: attributes[:email].to_s.strip.downcase)
          .where(expires_at: ...Time.current).find_each(&:revoke!)

        @invitation = Current.tenant.invitations.create!(email: attributes[:email], role: role, invited_by: current_user)
        InvitationMailer.with(invitation: @invitation, token: @invitation.token).invite.deliver_later
        audit!("invitation.created", subject: @invitation, metadata: { email: @invitation.email, role: role.name })
        render :show, status: :created
      end

      def destroy
        invitation = Current.tenant.invitations.pending_or_expired.find(params[:id])
        invitation.revoke!
        audit!("invitation.revoked", subject: invitation, metadata: { email: invitation.email })
        head :no_content
      end
    end
  end
end
