module Api
  module V1
    module Me
      # The user's signed-in devices.
      class SessionsController < BaseController
        def index
          @sessions = current_user.sessions.active.order(last_seen_at: :desc, created_at: :desc)
        end

        def destroy
          session = current_user.sessions.active.find(params[:id])
          session.revoke!
          audit!("auth.session.revoked", subject: current_user, metadata: { session_id: session.id })
          head :no_content
        end

        # Signs out every other device.
        def destroy_others
          current_user.sessions.active.where.not(id: Current.session.id).find_each(&:revoke!)
          audit!("auth.session.revoked_others", subject: current_user)
          head :no_content
        end
      end
    end
  end
end
