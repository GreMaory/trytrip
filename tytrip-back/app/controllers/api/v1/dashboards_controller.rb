module Api
  module V1
    # Operational indicators for today (in the organization's time zone).
    #
    # occupancy_rate: booked unit-nights / available unit-nights over the next
    # 30 days, for active units, counting pending, confirmed, checked-in and
    # checked-out reservations.
    # revenue_month: sum of total_amount of non-cancelled reservations whose
    # check-in falls in the current month (booking value, not cash received).
    class DashboardsController < BaseController
      OCCUPANCY_WINDOW = 30

      before_action -> { authorize!("reservations.read") }

      def show
        today = Time.current.in_time_zone(Current.tenant.time_zone).to_date
        reservations = Booking::Reservation.includes(:guest, unit: :property)
        counted = Booking::Reservation.where(status: %w[pending confirmed checked_in checked_out])

        window_end = today + OCCUPANCY_WINDOW
        units_count = Lodging::Unit.active.count
        booked_nights = counted.overlapping(today, window_end)
          .sum(Arel.sql(ActiveRecord::Base.sanitize_sql_array([ "LEAST(check_out, ?::date) - GREATEST(check_in, ?::date)", window_end, today ])))

        month = today.all_month
        render json: { data: {
          date: today,
          arrivals: serialize(reservations.where(check_in: today, status: %w[pending confirmed checked_in])),
          departures: serialize(reservations.where(check_out: today, status: %w[checked_in checked_out confirmed])),
          in_house_count: Booking::Reservation.checked_in.count,
          pending_count: Booking::Reservation.pending.count,
          occupancy_rate: units_count.zero? ? 0 : (booked_nights.to_d / (units_count * OCCUPANCY_WINDOW)).round(4).to_f,
          revenue_month: {
            amount: counted.where(check_in: month).sum(:total_amount).to_s,
            currency: Current.tenant.currency
          },
          units_count: units_count
        } }
      end

      private
        def serialize(scope)
          scope.limit(50).map do |reservation|
            {
              id: reservation.id, reference: reservation.reference, status: reservation.status,
              guest_name: reservation.guest.full_name, unit_name: reservation.unit.name,
              property_name: reservation.unit.property.name, check_in: reservation.check_in, check_out: reservation.check_out
            }
          end
        end
    end
  end
end
