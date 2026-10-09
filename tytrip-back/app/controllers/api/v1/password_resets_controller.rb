module Api
  module V1
    class PasswordResetsController < BaseController
      allow_unauthenticated_access
      rate_limit to: 5, within: 15.minutes, only: :create, with: -> { rate_limited }
      rate_limit to: 10, within: 15.minutes, only: :update, with: -> { rate_limited }

      # Always answers 202 so the response does not reveal whether the email exists.
      def create
        if (user = Identity::User.active.find_by(email: params.require(:email).to_s.strip.downcase))
          UserMailer.with(user: user).password_reset.deliver_later
          audit!("auth.password_reset.requested", subject: user, actor: nil)
        end
        head :accepted
      end

      def update
        user = Identity::User.find_by_token_for(:password_reset, params.require(:token).to_s)
        return render_error(:unprocessable_entity, t_api(:invalid_token), code: "invalid_token") unless user

        user.update!(password: params.require(:password), failed_login_attempts: 0, locked_until: nil)
        user.sessions.active.find_each(&:revoke!)
        audit!("auth.password_reset.completed", subject: user, actor: user)
        UserMailer.with(user: user).password_changed.deliver_later
        head :no_content
      end
    end
  end
end
