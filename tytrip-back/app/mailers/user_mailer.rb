class UserMailer < ApplicationMailer
  before_action { @user = params[:user] }
  default to: -> { @user.email }

  def email_verification
    @url = frontend_url("/verify-email", token: @user.generate_token_for(:email_verification))
    mail subject: "Confirmez votre adresse email"
  end

  def account_activated
    @url = frontend_url("/")
    mail subject: "Votre compte TyTrip est activé"
  end

  def password_reset
    @url = frontend_url("/reset-password", token: @user.generate_token_for(:password_reset))
    mail subject: "Réinitialisation de votre mot de passe"
  end

  def password_changed
    mail subject: "Votre mot de passe a été modifié"
  end

  SECURITY_EVENTS = {
    "mfa_enabled" => "L'authentification à deux facteurs a été activée sur votre compte.",
    "mfa_disabled" => "L'authentification à deux facteurs a été désactivée sur votre compte."
  }.freeze

  def security_alert
    @message = SECURITY_EVENTS.fetch(params[:event])
    mail subject: "Alerte de sécurité sur votre compte TyTrip"
  end
end
