module Api
  module V1
    # Lets the SPA obtain the XSRF-TOKEN cookie before its first unsafe request.
    class CsrfController < BaseController
      allow_unauthenticated_access

      def show
        head :no_content
      end
    end
  end
end
