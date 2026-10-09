# Cookie-based authentication for the SPA. The cookie holds the raw session
# token, encrypted by Rails (tamper-proof, unreadable by JavaScript).
module Authentication
  extend ActiveSupport::Concern

  COOKIE_NAME = :tytrip_auth

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session.present?
    end

    def require_authentication
      resume_session || raise(ApiErrors::Unauthenticated)
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      session = Identity::Session.find_active_by_token(cookies.encrypted[COOKIE_NAME])
      return unless session&.user&.active?

      session.touch_last_seen!
      session
    end

    def start_new_session_for(user)
      reset_session # prevents session fixation; also rotates the CSRF token
      user.register_successful_login!
      session = user.sessions.create!(ip_address: request.remote_ip, user_agent: request.user_agent.to_s.truncate(255))
      cookies.encrypted[COOKIE_NAME] = {
        value: session.token,
        expires: session.expires_at,
        httponly: true,
        secure: Rails.env.production?,
        same_site: :lax,
        domain: Rails.application.config.x.cookie_domain
      }
      Current.session = session
    end

    def terminate_session
      Current.session&.revoke!
      Current.session = nil
      cookies.delete(COOKIE_NAME, domain: Rails.application.config.x.cookie_domain)
      reset_session
    end
end
