module Api
  module V1
    class AuditEventsController < BaseController
      before_action -> { authorize!("audit.read") }

      def index
        scope = Audit::Event.where(tenant: Current.tenant).includes(:actor).recent_first
        scope = scope.where(action: params[:action_name]) if params[:action_name].present?
        @events = paginate(scope)
        render "api/v1/shared/audit_events"
      end
    end
  end
end
