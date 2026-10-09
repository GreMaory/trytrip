class InvitationMailer < ApplicationMailer
  # The raw token is passed explicitly: only its digest is stored.
  def invite
    @invitation = params[:invitation]
    @url = frontend_url("/invitations/accept", token: params[:token])
    mail to: @invitation.email, subject: "Invitation à rejoindre #{@invitation.tenant.name} sur TyTrip"
  end
end
