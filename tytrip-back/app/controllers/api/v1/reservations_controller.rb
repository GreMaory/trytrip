module Api
  module V1
    class ReservationsController < BaseController
      EDITABLE = %i[unit_id check_in check_out adults children source notes special_requests nightly_rate total_amount].freeze
      GUEST_ATTRIBUTES = %i[first_name last_name email phone country_code language].freeze
      EVENTS = %w[confirm check_in check_out cancel mark_no_show].freeze

      before_action -> { authorize!("reservations.read") }, only: %i[index show]
      before_action -> { authorize!("reservations.manage") }, except: %i[index show]
      before_action :set_reservation, only: %i[show update transition]

      def index
        scope = Booking::Reservation.includes(:guest, unit: :property).order(:check_in, :id)
        scope = scope.where(status: Array(params[:status]) & Booking::Reservation.statuses.keys) if params[:status].present?
        scope = scope.where(unit_id: params[:unit_id]) if params[:unit_id].present?
        scope = scope.joins(:unit).where(units: { property_id: params[:property_id] }) if params[:property_id].present?
        scope = scope.where(guest_id: params[:guest_id]) if params[:guest_id].present?
        from, to = date_param(:from), date_param(:to)
        scope = scope.overlapping(from || Date.new(1900), to || Date.new(9999)) if from || to
        scope = scope.where(check_in: date_param(:arriving_on)) if params[:arriving_on]
        scope = scope.where(check_out: date_param(:departing_on)) if params[:departing_on]
        if params[:q].present?
          term = params[:q].to_s.strip
          scope = scope.joins(:guest).merge(Crm::Guest.search(term)).or(scope.joins(:guest).where(reference: term.upcase))
        end
        @reservations = paginate(scope)
      end

      def show
      end

      def create
        @reservation = Booking::Reservation.new(reservation_params.except(:guest_id))
        @reservation.created_by = current_user
        Booking::Reservation.transaction do
          @reservation.guest = find_or_build_guest
          @reservation.guest.save! if @reservation.guest&.new_record?
          @reservation.save_with_unit_lock!
        end
        audit!("reservation.created", subject: @reservation, metadata: { reference: @reservation.reference })
        render :show, status: :created
      end

      def update
        @reservation.assign_attributes(reservation_params.except(:guest_id))
        if (@reservation.check_in_changed? || @reservation.check_out_changed? || @reservation.nightly_rate_changed?) &&
            !reservation_params.key?(:total_amount)
          @reservation.reprice
        end
        @reservation.save_with_unit_lock!
        audit!("reservation.updated", subject: @reservation, metadata: { fields: @reservation.saved_changes.keys - %w[updated_at] })
        render :show
      end

      # POST /reservations/:id/transition { event: "confirm" | "cancel" | ..., reason }
      def transition
        event = params.require(:event).to_s
        raise Booking::Reservation::InvalidTransition, t_api(:unknown_event, event: event) unless EVENTS.include?(event)

        @reservation.transition!(event, reason: params[:reason])
        audit!("reservation.#{event}", subject: @reservation, metadata: { reference: @reservation.reference })
        notify_guest(event)
        render :show
      end

      private
        def set_reservation
          @reservation = Booking::Reservation.includes(:guest, unit: :property).find(params[:id])
        end

        def reservation_params
          params.expect(reservation: [ *EDITABLE, :guest_id ])
        end

        def find_or_build_guest
          if (guest_id = params.dig(:reservation, :guest_id)).present?
            Crm::Guest.find(guest_id)
          else
            Crm::Guest.find_or_initialize_for(params.require(:guest).permit(*GUEST_ATTRIBUTES))
          end
        end

        def notify_guest(event)
          return if @reservation.guest.email.blank?

          case event
          when "confirm" then ReservationMailer.with(reservation: @reservation).confirmation.deliver_later
          when "cancel" then ReservationMailer.with(reservation: @reservation).cancellation.deliver_later
          end
        end
    end
  end
end
