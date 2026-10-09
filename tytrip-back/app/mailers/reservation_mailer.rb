# Emails to guests, sent in the organization's name.
class ReservationMailer < ApplicationMailer
  before_action do
    @reservation = params[:reservation]
    @guest = @reservation.guest
    @property = @reservation.unit.property
    @organization = Current.tenant!
  end

  default to: -> { @guest.email }, from: -> { email_address_with_name(Rails.application.config.x.mail_from_address, @organization.name) }

  def confirmation
    mail subject: "Confirmation de votre réservation #{@reservation.reference} – #{@property.name}"
  end

  def cancellation
    mail subject: "Annulation de votre réservation #{@reservation.reference}"
  end
end
