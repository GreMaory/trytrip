module Api
  module V1
    module Me
      class PasswordsController < BaseController
        rate_limit to: 5, within: 15.minutes, with: -> { rate_limited }

        # Changing the password revokes every other session.
        def update
          unless current_user.authenticate(params.require(:current_password).to_s)
            return render_error(:unprocessable_entity, t_api(:validation_failed), code: "validation_failed",
              details: { current_password: [ "is invalid" ] })
          end

          current_user.update!(password: params.require(:password))
          current_user.sessions.active.where.not(id: Current.session.id).find_each(&:revoke!)
          audit!("auth.password.changed", subject: current_user)
          UserMailer.with(user: current_user).password_changed.deliver_later
          head :no_content
        end
      end
    end
  end
end
