module Api
  module V1
    module Admin
      class UsersController < BaseController
        before_action :set_user, except: :index

        def index
          scope = Identity::User.order(:name)
          if params[:q].present?
            term = "%#{Identity::User.sanitize_sql_like(params[:q].to_s)}%"
            scope = scope.where("name ILIKE :term OR email ILIKE :term", term: term)
          end
          @users = paginate(scope)
        end

        def show
          @memberships = @user.memberships.includes(:tenant, :role)
        end

        def suspend
          raise ApiErrors::Forbidden, t_api(:cannot_suspend_self) if @user == current_user

          @user.transaction do
            @user.update!(status: :suspended)
            @user.sessions.active.find_each(&:revoke!)
          end
          audit!("admin.user.suspended", subject: @user)
          show
          render :show
        end

        def activate
          @user.update!(status: :active, failed_login_attempts: 0, locked_until: nil)
          audit!("admin.user.activated", subject: @user)
          show
          render :show
        end

        def revoke_sessions
          @user.sessions.active.find_each(&:revoke!)
          audit!("admin.user.sessions_revoked", subject: @user)
          head :no_content
        end

        private
          def set_user
            @user = Identity::User.find(params[:id])
          end
      end
    end
  end
end
