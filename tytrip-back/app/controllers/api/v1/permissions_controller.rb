module Api
  module V1
    class PermissionsController < BaseController
      before_action :require_tenant_membership

      def index
        render json: { data: Identity::Permissions::ALL.map { |key, description| { key: key, description: description } } }
      end
    end
  end
end
