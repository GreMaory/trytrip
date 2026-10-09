module Api
  module V1
    class EmailVerificationsController < BaseController
      allow_unauthenticated_access only: :update
      rate_limit to: 3, within: 15.minutes, only: :create, with: -> { rate_limited }

      # Resends the verification email to the signed-in user.
      def create
        UserMailer.with(user: current_user).email_verification.deliver_later unless current_user.email_verified?
        head :accepted
      end

      def update
        user = Identity::User.find_by_token_for(:email_verification, params.require(:token).to_s)
        return render_error(:unprocessable_entity, t_api(:invalid_token), code: "invalid_token") unless user

        user.verify_email!
        audit!("auth.email.verified", subject: user, actor: user)
        UserMailer.with(user: user).account_activated.deliver_later
        head :no_content
      end
    end
  end
end
