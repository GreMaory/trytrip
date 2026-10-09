module Api
  module V1
    # Sign in / sign out. When the user has two-factor authentication, the
    # password step only records a short-lived pending challenge in the Rails
    # session; the auth session is created after the second factor.
    class SessionsController < BaseController
      MFA_CHALLENGE_TTL = 5.minutes
      MAX_MFA_ATTEMPTS = 5

      allow_unauthenticated_access only: %i[create verify_mfa]
      rate_limit to: 10, within: 3.minutes, only: :create, with: -> { rate_limited }
      rate_limit to: 10, within: 3.minutes, only: :verify_mfa, with: -> { rate_limited }

      def create
        user = Identity::User.find_by(email: params.require(:email).to_s.strip.downcase)
        authenticated = Identity::User.authenticate_by(email: params[:email].to_s, password: params.require(:password).to_s)

        if authenticated.nil? || user.locked? || user.suspended?
          user&.register_failed_login! unless user&.locked?
          audit!("auth.login.failed", subject: user, actor: nil, metadata: { reason: failure_reason(user, authenticated) })
          return render_invalid_credentials
        end

        if user.mfa_enabled?
          reset_session
          session[:mfa_challenge] = { "user_id" => user.id, "expires_at" => MFA_CHALLENGE_TTL.from_now.to_i, "attempts" => 0 }
          render json: { data: { mfa_required: true } }
        else
          sign_in(user)
        end
      end

      def verify_mfa
        challenge = session[:mfa_challenge]
        if challenge.nil? || challenge["expires_at"] < Time.current.to_i || challenge["attempts"] >= MAX_MFA_ATTEMPTS
          session.delete(:mfa_challenge)
          return render_error(:unauthorized, t_api(:unauthorized))
        end

        user = Identity::User.active.find(challenge["user_id"])
        if user.verify_second_factor!(params.require(:code))
          session.delete(:mfa_challenge)
          sign_in(user)
        else
          session[:mfa_challenge] = challenge.merge("attempts" => challenge["attempts"] + 1)
          audit!("auth.mfa.failed", subject: user, actor: user)
          render_error(:unauthorized, t_api(:invalid_mfa_code), code: "invalid_mfa_code")
        end
      end

      def destroy
        audit!("auth.logout", subject: current_user)
        terminate_session
        head :no_content
      end

      private
        def sign_in(user)
          start_new_session_for(user)
          audit!("auth.login.succeeded", subject: user, actor: user)
          render json: { data: { mfa_required: false } }
        end

        # Same answer for unknown email, wrong password, locked or suspended
        # account: the response never reveals whether an account exists.
        def render_invalid_credentials
          render_error(:unauthorized, t_api(:invalid_credentials), code: "invalid_credentials")
        end

        def failure_reason(user, authenticated)
          if user.nil? then "unknown_email"
          elsif user.locked? then "locked"
          elsif user.suspended? then "suspended"
          else "bad_password"
          end
        end
    end
  end
end
