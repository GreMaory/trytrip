ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module TestDataHelpers
  PASSWORD = "Correct-horse-battery-9".freeze

  def create_user(email: "user-#{SecureRandom.hex(4)}@example.com", password: PASSWORD, **attributes)
    Identity::User.create!(email: email, name: "Test User", password: password, email_verified_at: Time.current, **attributes)
  end

  # Organization with default roles and an owner.
  def create_tenant(subdomain: "t#{SecureRandom.hex(4)}", owner: create_user, **attributes)
    Identity::Tenant.provision!(owner: owner, name: subdomain.titleize, subdomain: subdomain, **attributes)
  end

  def add_member(tenant, role_key, user: create_user)
    tenant.memberships.create!(user: user, role: tenant.roles.find_by!(key: role_key))
    user
  end

  def owner_of(tenant)
    tenant.memberships.owners.first.user
  end

  # Must be called inside tenant.switch
  def create_unit(property_name: "Villa #{SecureRandom.hex(2)}", **attributes)
    property = Lodging::Property.create!(name: property_name)
    property.units.create!({ name: property_name, max_guests: 4, base_rate: "120.00" }.merge(attributes))
  end

  def create_guest(**attributes)
    Crm::Guest.create!({ first_name: "Ada", last_name: "Lovelace", email: "ada-#{SecureRandom.hex(3)}@example.com" }.merge(attributes))
  end

  def book(unit, check_in, check_out, guest: create_guest, **attributes)
    reservation = Booking::Reservation.new(unit: unit, guest: guest, check_in: check_in, check_out: check_out, **attributes)
    reservation.save_with_unit_lock!
    reservation
  end
end

module ActiveSupport
  class TestCase
    # Tenant data spans several databases, so tests build their data with
    # TestDataHelpers instead of YAML fixtures.
    parallelize(workers: :number_of_processors)
    include TestDataHelpers

    setup { Rails.cache.clear }
  end
end

module ActionDispatch
  class IntegrationTest
    include ActiveJob::TestHelper

    def json
      response.parsed_body
    end

    # Requests go to <subdomain>.example.com ("www" is a reserved, tenant-less host).
    def on_host(subdomain)
      host! "#{subdomain}.example.com"
    end

    def sign_in(user, password: TestDataHelpers::PASSWORD)
      post "/api/v1/session", params: { email: user.email, password: password }, as: :json
      assert_response :success, "sign in failed: #{response.body}"
    end
  end
end
