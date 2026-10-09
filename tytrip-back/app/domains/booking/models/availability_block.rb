# A period during which a unit cannot be booked (owner stay, works...).
# ends_on is exclusive, like a check-out date.
module Booking
  class AvailabilityBlock < ApplicationRecord
    include TenantScoped

    REASONS = %w[owner maintenance closed other].freeze

    belongs_to :unit, class_name: "Lodging::Unit"

    validates :starts_on, :ends_on, presence: true
    validates :reason, inclusion: { in: REASONS }
    validates :note, length: { maximum: 255 }
    validate :ends_after_start
    validate :no_live_reservation_overlap

    scope :overlapping, ->(from, to) { where("starts_on < ? AND ends_on > ?", to, from) }

    def save_with_unit_lock!
      transaction do
        Lodging::Unit.lock.find(unit_id)
        save!
      end
    rescue ActiveRecord::StatementInvalid => error
      raise unless self.class.exclusion_violation?(error)

      errors.add(:base, :overlaps_block)
      raise ActiveRecord::RecordInvalid, self
    end

    private
      def ends_after_start
        errors.add(:ends_on, :greater_than, count: starts_on) if starts_on && ends_on && ends_on <= starts_on
      end

      def no_live_reservation_overlap
        return unless unit && starts_on && ends_on
        if unit.reservations.live.overlapping(starts_on, ends_on).exists?
          errors.add(:base, :overlaps_reservation)
        end
      end
  end
end
