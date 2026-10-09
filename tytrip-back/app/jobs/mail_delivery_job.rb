require "net/smtp"

# deliver_later goes through this job so that emails enqueued in a tenant
# context are rendered in that same context.
class MailDeliveryJob < ActionMailer::MailDeliveryJob
  include TenantContextJob

  retry_on Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNREFUSED, Net::SMTPServerBusy,
    wait: :polynomially_longer, attempts: 5
end
