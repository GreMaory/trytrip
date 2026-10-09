module Api
  module V1
    class GuestsController < BaseController
      before_action -> { authorize!("guests.read") }, only: %i[index show]
      before_action -> { authorize!("guests.manage") }, except: %i[index show]
      before_action :set_guest, except: %i[index create]

      def index
        scope = Crm::Guest.order(:last_name, :first_name)
        scope = scope.search(params[:q]) if params[:q].present?
        @guests = paginate(scope)
      end

      def show
        @reservations = @guest.reservations.includes(unit: :property).order(check_in: :desc).limit(50)
      end

      def create
        @guest = Crm::Guest.create!(guest_params)
        render :show, status: :created
      end

      def update
        @guest.update!(guest_params)
        audit!("guest.updated", subject: @guest, metadata: { fields: @guest.saved_changes.keys - %w[updated_at] })
        render :show
      end

      # GDPR erasure: only guests without reservations can be deleted; others
      # must be kept for accounting obligations (anonymization: to do).
      def destroy
        @guest.destroy!
        audit!("guest.deleted", subject: @guest)
        head :no_content
      end

      private
        def set_guest
          @guest = Crm::Guest.find(params[:id])
        end

        def guest_params
          params.expect(guest: %i[first_name last_name email phone country_code language notes marketing_consent])
        end
    end
  end
end
