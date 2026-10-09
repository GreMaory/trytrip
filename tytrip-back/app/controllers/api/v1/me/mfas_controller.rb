module Api
  module V1
    module Me
      # Two-factor authentication setup:
      #   POST   /me/mfa                 -> new secret + otpauth URI (not active yet)
      #   PATCH  /me/mfa {code}          -> activates, returns recovery codes (shown once)
      #   DELETE /me/mfa {password,code} -> deactivates
      #   POST   /me/mfa/recovery_codes {code} -> regenerates recovery codes
      class MfasController < BaseController
        rate_limit to: 10, within: 5.minutes, except: :create, with: -> { rate_limited }

        def create
          return render_error(:conflict, t_api(:mfa_already_enabled)) if current_user.mfa_enabled?

          current_user.start_mfa_setup!
          render json: { data: { secret: current_user.otp_secret, provisioning_uri: current_user.otp_provisioning_uri } }
        end

        def update
          codes = current_user.enable_mfa!(params.require(:code))
          return render_invalid_code unless codes

          current_user.sessions.active.where.not(id: Current.session.id).find_each(&:revoke!)
          audit!("auth.mfa.enabled", subject: current_user)
          UserMailer.with(user: current_user, event: "mfa_enabled").security_alert.deliver_later
          render json: { data: { recovery_codes: codes } }
        end

        def destroy
          unless current_user.authenticate(params.require(:password).to_s) && current_user.verify_second_factor!(params.require(:code))
            return render_invalid_code
          end

          current_user.disable_mfa!
          audit!("auth.mfa.disabled", subject: current_user)
          UserMailer.with(user: current_user, event: "mfa_disabled").security_alert.deliver_later
          head :no_content
        end

        def recovery_codes
          return render_invalid_code unless current_user.verify_second_factor!(params.require(:code))

          codes = current_user.generate_recovery_codes!
          audit!("auth.mfa.recovery_codes_regenerated", subject: current_user)
          render json: { data: { recovery_codes: codes } }
        end

        private
          def render_invalid_code
            render_error(:unprocessable_entity, t_api(:invalid_mfa_code), code: "invalid_mfa_code")
          end
      end
    end
  end
end
