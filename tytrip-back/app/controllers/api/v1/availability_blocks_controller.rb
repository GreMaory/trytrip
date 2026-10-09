module Api
  module V1
    class AvailabilityBlocksController < BaseController
      before_action -> { authorize!("reservations.manage") }

      def create
        @block = Booking::AvailabilityBlock.new(params.expect(availability_block: %i[unit_id starts_on ends_on reason note]))
        @block.save_with_unit_lock!
        audit!("availability_block.created", subject: @block)
        render :show, status: :created
      end

      def destroy
        block = Booking::AvailabilityBlock.find(params[:id])
        block.destroy!
        audit!("availability_block.deleted", subject: block)
        head :no_content
      end
    end
  end
end
