module Api
  module V1
    # Booking calendar: units with their reservations and blocks over a period
    # (at most MAX_DAYS days).
    class CalendarsController < BaseController
      MAX_DAYS = 93

      before_action -> { authorize!("reservations.read") }

      def show
        @from = date_param(:from, required: true)
        @to = date_param(:to, required: true)
        unless @to > @from && (@to - @from) <= MAX_DAYS
          return render_error(:bad_request, t_api(:invalid_period, count: MAX_DAYS))
        end

        units = Lodging::Unit.active.includes(:property).joins(:property).merge(Lodging::Property.active).order("properties.name", :name)
        units = units.where(property_id: params[:property_id]) if params[:property_id].present?
        @units = units.to_a

        unit_ids = @units.map(&:id)
        @reservations = Booking::Reservation.where(unit_id: unit_ids).where.not(status: %w[cancelled no_show])
          .overlapping(@from, @to).includes(:guest).group_by(&:unit_id)
        @blocks = Booking::AvailabilityBlock.where(unit_id: unit_ids).overlapping(@from, @to).group_by(&:unit_id)
      end
    end
  end
end
