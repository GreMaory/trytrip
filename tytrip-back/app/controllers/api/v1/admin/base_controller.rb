module Api
  module V1
    module Admin
      # Platform back-office (admin.<domain>). Distinct from organization
      # administration: requires the platform super admin role, and 2FA when
      # config.x.require_mfa_for_platform_admins is set (always in production).
      class BaseController < Api::V1::BaseController
        before_action :require_platform_admin
        before_action :require_mfa

        private
          def require_mfa
            if Rails.application.config.x.require_mfa_for_platform_admins && !current_user.mfa_enabled?
              raise ApiErrors::Forbidden, t_api(:mfa_required)
            end
          end
      end
    end
  end
end
