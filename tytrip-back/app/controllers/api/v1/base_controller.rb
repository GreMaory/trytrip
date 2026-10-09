module Api
  module V1
    class BaseController < ApplicationController
      include ActionController::Cookies
      include ActionController::RequestForgeryProtection
      include ApiErrors
      include Authentication
      include Paginated

      # Cookies authenticate the SPA, so every non-GET request must carry the
      # CSRF token. The token is exposed in the XSRF-TOKEN cookie (readable
      # by the SPA, same site only) and sent back in the X-CSRF-Token header.
      protect_from_forgery with: :exception
      # ActionController::API does not pick up config.action_controller.allow_forgery_protection
      # (only disabled in the test environment).
      self.allow_forgery_protection = Rails.application.config.action_controller.allow_forgery_protection != false

      prepend_before_action :set_request_context
      around_action :switch_locale
      after_action :set_csrf_cookie

      private
        def set_request_context
          Current.request_id = request.request_id
          Current.ip_address = request.remote_ip
          Current.user_agent = request.user_agent
        end

        # User preference, then organization, then the browser's Accept-Language.
        def switch_locale(&action)
          locale = current_user&.locale || Current.tenant&.locale ||
            request.headers["Accept-Language"].to_s[/\A[a-z]{2}/]
          locale = I18n.default_locale unless I18n.available_locales.map(&:to_s).include?(locale.to_s)
          @locale = locale # error rendering (rescue_from) happens outside of this block
          I18n.with_locale(locale, &action)
        end

        def set_csrf_cookie
          cookies["XSRF-TOKEN"] = { value: form_authenticity_token, same_site: :lax, secure: Rails.env.production?,
                                  domain: Rails.application.config.x.cookie_domain }
        end

        def current_user
          Current.user
        end

        # Endpoints operating on an organization's data. The tenant comes from
        # the subdomain (Middleware::TenantResolver) and the user must be an
        # active member of it.
        def require_tenant_membership
          raise ApiErrors::TenantRequired unless Current.tenant
          Current.membership = current_user.membership_for(Current.tenant) || raise(ApiErrors::Forbidden)
        end

        def authorize!(permission)
          require_tenant_membership unless Current.membership
          raise ApiErrors::Forbidden, t_api(:missing_permission, permission: permission) unless Current.membership.can?(permission)
        end

        def require_platform_admin
          raise ApiErrors::Forbidden unless current_user.platform_super_admin?
        end

        # Parses an ISO 8601 date parameter; 400 when malformed.
        def date_param(name, required: false)
          value = required ? params.require(name) : params[name]
          Date.iso8601(value.to_s) if value.present?
        rescue Date::Error
          raise ActionController::BadRequest, "Invalid date for #{name}"
        end

        def audit!(action, **options)
          Audit::Event.record!(action, **options)
        end

        def rate_limited
          render_error(:too_many_requests, t_api(:too_many_requests))
        end
    end
  end
end
