module Api
  module V1
    module Admin
      class AuditEventsController < BaseController
        def index
          scope = Audit::Event.includes(:actor).recent_first
          scope = scope.where(tenant_id: params[:tenant_id]) if params[:tenant_id].present?
          scope = scope.where(action: params[:action_name]) if params[:action_name].present?
          @events = paginate(scope)
          render "api/v1/shared/audit_events"
        end
      end
    end
  end
end
