module Crm
  class Guest < ApplicationRecord
    include TenantScoped

    has_many :reservations, class_name: "Booking::Reservation", dependent: :restrict_with_error

    normalizes :email, with: ->(email) { email.strip.downcase.presence }
    normalizes :country_code, with: ->(code) { code.strip.upcase.presence }
    normalizes :first_name, :last_name, with: ->(name) { name.squish }

    validates :first_name, :last_name, presence: true, length: { maximum: 100 }
    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, length: { maximum: 254 }, allow_nil: true
    validates :phone, length: { maximum: 40 }, format: { with: /\A[+\d\s().-]+\z/ }, allow_blank: true
    validates :country_code, format: { with: /\A[A-Z]{2}\z/ }, allow_nil: true

    before_save -> { self.marketing_consent_at = marketing_consent? ? Time.current : nil }, if: :marketing_consent_changed?

    scope :search, ->(term) {
      pattern = "%#{sanitize_sql_like(term.to_s.strip)}%"
      where("first_name ILIKE :p OR last_name ILIKE :p OR email ILIKE :p OR phone ILIKE :p " \
            "OR (first_name || ' ' || last_name) ILIKE :p", p: pattern)
    }

    def full_name
      "#{first_name} #{last_name}"
    end

    # Reuses the guest with the same email (simple deduplication) or builds a new one.
    def self.find_or_initialize_for(attributes)
      email = attributes[:email].to_s.strip.downcase.presence
      guest = (email && find_by(email: email)) || new
      guest.assign_attributes(attributes.to_h.compact_blank) if guest.new_record?
      guest
    end
  end
end
