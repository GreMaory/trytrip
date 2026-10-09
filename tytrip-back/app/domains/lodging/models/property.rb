module Lodging
  class Property < ApplicationRecord
    include TenantScoped

    TYPES = %w[apartment house villa chalet guesthouse hotel room other].freeze
    AMENITIES = %w[wifi parking pool air_conditioning heating kitchen washing_machine dishwasher tv
                   elevator garden terrace balcony bbq pets_allowed wheelchair_access baby_cot].freeze
    TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

    enum :status, { active: "active", archived: "archived" }, default: "active", validate: true

    has_many :units, -> { order(:name) }, dependent: :restrict_with_error

    normalizes :country_code, with: ->(code) { code.strip.upcase.presence }
    normalizes :amenities, with: ->(amenities) { Array(amenities).map(&:to_s).uniq.sort }

    validates :name, presence: true, length: { maximum: 120 }
    validates :property_type, inclusion: { in: TYPES }
    validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true
    validates :check_in_time, :check_out_time, format: { with: TIME_FORMAT }
    validates :latitude, numericality: { in: -90..90 }, allow_nil: true
    validates :longitude, numericality: { in: -180..180 }, allow_nil: true
    validate :amenities_must_be_known
    validate :time_zone_must_exist

    def today
      Time.current.in_time_zone(time_zone).to_date
    end

    private
      def amenities_must_be_known
        unknown = amenities - AMENITIES
        errors.add(:amenities, :inclusion, value: unknown.join(", ")) if unknown.any?
      end

      def time_zone_must_exist
        errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
      end
  end
end
