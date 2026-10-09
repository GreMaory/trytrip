# A bookable accommodation of a property (the whole house, an apartment, a room...).
module Lodging
  class Unit < ApplicationRecord
    include TenantScoped

    enum :status, { active: "active", inactive: "inactive" }, default: "active", validate: true

    belongs_to :property
    has_many :reservations, class_name: "Booking::Reservation", dependent: :restrict_with_error
    has_many :availability_blocks, class_name: "Booking::AvailabilityBlock", dependent: :destroy

    validates :name, presence: true, length: { maximum: 120 }
    validates :max_guests, numericality: { only_integer: true, in: 1..100 }
    validates :bedrooms, :beds, numericality: { only_integer: true, in: 0..100 }
    validates :bathrooms, numericality: { in: 0..100 }
    validates :base_rate, numericality: { greater_than_or_equal_to: 0, less_than: 1_000_000 }
    validates :min_stay, numericality: { only_integer: true, in: 1..365 }
    validates :max_stay, numericality: { only_integer: true, in: 1..365 }, allow_nil: true
    validate :max_stay_not_below_min_stay

    def available?(check_in, check_out, except_reservation: nil)
      reservations.live.overlapping(check_in, check_out).where.not(id: except_reservation&.id).none? &&
        availability_blocks.overlapping(check_in, check_out).none?
    end

    private
      def max_stay_not_below_min_stay
        errors.add(:max_stay, :greater_than_or_equal_to, count: min_stay) if max_stay && min_stay && max_stay < min_stay
      end
  end
end
