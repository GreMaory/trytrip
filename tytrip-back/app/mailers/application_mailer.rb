class ApplicationMailer < ActionMailer::Base
  default from: -> { Rails.application.config.x.mail_from }
  layout "mailer"

  self.delivery_job = MailDeliveryJob

  helper_method :frontend_url

  private
    # Links in emails point to the SPA, on the portal ("app") or on a tenant subdomain.
    def frontend_url(path, subdomain: "app", **query)
      config = Rails.application.config.x
      url = "#{config.app_protocol}://#{subdomain}.#{config.app_domain}#{path}"
      query.any? ? "#{url}?#{query.to_query}" : url
    end
end
