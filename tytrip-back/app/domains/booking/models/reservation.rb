# A stay of a guest in a unit. Dates are local dates of the property;
# check_out is exclusive (the unit is free again that day).
#
# Money: amounts are BigDecimal (numeric(12,2) columns) in the tenant
# currency, rounded half-up to the cent. nightly_rate and total_amount are a
# snapshot taken at booking time: later rate changes never alter them.
module Booking
  class Reservation < ApplicationRecord
    include TenantScoped

    class InvalidTransition < StandardError; end

    LIVE_STATUSES = %w[pending confirmed checked_in].freeze
    SOURCES = %w[direct phone email website airbnb booking_com vrbo other].freeze
    TRANSITIONS = {
      confirm: { from: %w[pending], to: "confirmed", timestamp: :confirmed_at },
      check_in: { from: %w[confirmed], to: "checked_in", timestamp: :checked_in_at },
      check_out: { from: %w[checked_in], to: "checked_out", timestamp: :checked_out_at },
      cancel: { from: %w[pending confirmed], to: "cancelled", timestamp: :cancelled_at },
      mark_no_show: { from: %w[confirmed], to: "no_show", timestamp: nil }
    }.freeze

    enum :status, {
      pending: "pending", confirmed: "confirmed", checked_in: "checked_in",
      checked_out: "checked_out", cancelled: "cancelled", no_show: "no_show"
    }, default: "pending", validate: true

    belongs_to :unit, class_name: "Lodging::Unit"
    belongs_to :guest, class_name: "Crm::Guest"
    belongs_to :created_by, class_name: "Identity::User", optional: true
    has_one :property, through: :unit

    scope :live, -> { where(status: LIVE_STATUSES) }
    scope :overlapping, ->(from, to) { where("check_in < ? AND check_out > ?", to, from) }

    validates :check_in, :check_out, presence: true
    validates :source, inclusion: { in: SOURCES }
    validates :adults, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :children, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
    validates :nightly_rate, :total_amount, numericality: { greater_than_or_equal_to: 0, less_than: 10_000_000 }
    validates :currency, format: { with: /\A[A-Z]{3}\z/ }
    validates :notes, :special_requests, length: { maximum: 5000 }
    validate :check_out_after_check_in
    validate :stay_rules, if: :booking_terms_changed?
    validate :unit_must_be_available, if: -> { live? && booking_terms_changed? }

    before_validation :assign_reference, on: :create
    before_validation :price_from_unit, on: :create

    def nights
      (check_out - check_in).to_i if check_in && check_out
    end

    def guests_count
      adults.to_i + children.to_i
    end

    def live?
      LIVE_STATUSES.include?(status)
    end

    # Saves while holding a lock on the unit row, so that concurrent bookings
    # of the same unit are serialized and the availability check is reliable.
    # The exclusion constraint in the database remains the final guarantee.
    def save_with_unit_lock!
      transaction do
        Lodging::Unit.lock.find(unit_id) if unit_id
        save!
      end
    rescue ActiveRecord::StatementInvalid => error
      raise unless self.class.exclusion_violation?(error)

      errors.add(:base, :unavailable)
      raise ActiveRecord::RecordInvalid, self
    end

    def transition!(event, reason: nil)
      rule = TRANSITIONS.fetch(event.to_sym) { raise InvalidTransition, I18n.t("api.errors.unknown_event", event: event) }
      raise InvalidTransition, I18n.t("api.errors.invalid_transition", event: event, status: status) unless rule[:from].include?(status)

      self.status = rule[:to]
      self[rule[:timestamp]] = Time.current if rule[:timestamp]
      self.cancellation_reason = reason.to_s.truncate(255) if event.to_sym == :cancel
      save_with_unit_lock!
    end

    def available_events
      TRANSITIONS.select { |_, rule| rule[:from].include?(status) }.keys
    end

    # Recomputes the total from the nightly rate (used when dates change).
    def reprice
      self.total_amount = (nightly_rate.to_d * nights).round(2, BigDecimal::ROUND_HALF_UP) if nightly_rate && nights
    end

    private
      def booking_terms_changed?
        new_record? || will_save_change_to_check_in? || will_save_change_to_check_out? ||
          will_save_change_to_unit_id? || will_save_change_to_status? || will_save_change_to_adults? ||
          will_save_change_to_children?
      end

      def assign_reference
        self.reference ||= loop do
          candidate = "R#{SecureRandom.alphanumeric(7).upcase}"
          break candidate unless self.class.exists?(reference: candidate)
        end
      end

      def price_from_unit
        return unless unit
        self.currency ||= Current.tenant!.currency
        self.nightly_rate ||= unit.base_rate
        reprice if total_amount.nil?
      end

      def check_out_after_check_in
        if check_in && check_out && check_out <= check_in
          errors.add(:check_out, :greater_than, count: check_in)
        end
      end

      def stay_rules
        return unless unit && nights&.positive?

        errors.add(:unit, :not_bookable) if new_record? && !unit.active?
        errors.add(:base, :too_many_guests, count: unit.max_guests) if guests_count > unit.max_guests
        errors.add(:base, :stay_too_short, count: unit.min_stay) if nights < unit.min_stay
        if unit.max_stay && nights > unit.max_stay
          errors.add(:base, :stay_too_long, count: unit.max_stay)
        end
      end

      def unit_must_be_available
        return unless unit && check_in && check_out && check_out > check_in

        unless unit.available?(check_in, check_out, except_reservation: self)
          errors.add(:base, :unavailable)
        end
      end
  end
end
