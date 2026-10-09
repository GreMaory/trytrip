require "test_helper"

# Phase 3 journey through the API: property -> availability -> reservation ->
# confirmation email -> modification.
class BookingFlowTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = create_tenant(subdomain: "acme")
    @manager = add_member(@tenant, "manager")
    on_host("acme")
    sign_in(@manager)
  end

  test "a manager creates a property, books a stay, confirms it and the guest is emailed" do
    post "/api/v1/properties", as: :json, params: {
      property: { name: "Villa Les Pins", property_type: "villa", city: "Biarritz", country_code: "fr", amenities: %w[wifi pool] },
      unit: { max_guests: 6, base_rate: "250.00", min_stay: 2 }
    }
    assert_response :created
    unit_id = json.dig("data", "units", 0, "id")
    assert_equal "FR", json.dig("data", "country_code")

    get "/api/v1/calendar", params: { from: "2027-07-01", to: "2027-07-31" }
    assert_response :success
    assert_equal [ unit_id ], json.dig("data", "units").map { |unit| unit["id"] }
    assert_empty json.dig("data", "units", 0, "reservations")

    post "/api/v1/reservations", as: :json, params: {
      reservation: { unit_id: unit_id, check_in: "2027-07-10", check_out: "2027-07-14", adults: 2, children: 1, source: "phone" },
      guest: { first_name: "Marie", last_name: "Curie", email: "marie@example.com" }
    }
    assert_response :created
    reservation_id = json.dig("data", "id")
    assert_equal "pending", json.dig("data", "status")
    assert_equal "1000.0", json.dig("data", "total_amount")
    assert_equal 4, json.dig("data", "nights")

    post "/api/v1/reservations", as: :json, params: {
      reservation: { unit_id: unit_id, check_in: "2027-07-12", check_out: "2027-07-15" },
      guest: { first_name: "Other", last_name: "Guest" }
    }
    assert_response :unprocessable_entity
    assert_includes json.dig("error", "details", "base"), I18n.t("errors.messages.unavailable", locale: :fr)

    perform_enqueued_jobs do
      post "/api/v1/reservations/#{reservation_id}/transition", params: { event: "confirm" }, as: :json
    end
    assert_response :success
    assert_equal "confirmed", json.dig("data", "status")
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "marie@example.com" ], mail.to
    assert_match "Villa Les Pins", mail.subject
    assert_match "1 000,00 EUR", mail.text_part.body.to_s

    patch "/api/v1/reservations/#{reservation_id}", params: { reservation: { check_out: "2027-07-16" } }, as: :json
    assert_response :success
    assert_equal "1500.0", json.dig("data", "total_amount")

    get "/api/v1/calendar", params: { from: "2027-07-01", to: "2027-07-31" }
    assert_equal [ reservation_id ], json.dig("data", "units", 0, "reservations").map { |r| r["id"] }

    get "/api/v1/reservations", params: { q: "curie" }
    assert_equal 1, json.dig("meta", "pagination", "total")

    get "/api/v1/guests", params: { q: "marie" }
    guest_id = json.dig("data", 0, "id")
    get "/api/v1/guests/#{guest_id}"
    assert_equal 1, json.dig("data", "reservations").size

    assert Audit::Event.exists?(action: "reservation.confirm", tenant: @tenant, actor: @manager)
  end

  test "returning guests are matched by email" do
    unit = @tenant.switch { create_unit }
    2.times do |i|
      post "/api/v1/reservations", as: :json, params: {
        reservation: { unit_id: unit.id, check_in: "2027-0#{i + 1}-10", check_out: "2027-0#{i + 1}-12" },
        guest: { first_name: "Marie", last_name: "Curie", email: "MARIE@example.com" }
      }
      assert_response :created
    end
    assert_equal 1, @tenant.switch { Crm::Guest.count }
  end

  test "invalid transitions and malformed dates are rejected" do
    reservation = @tenant.switch { book(create_unit, Date.new(2027, 3, 1), Date.new(2027, 3, 3)) }
    post "/api/v1/reservations/#{reservation.id}/transition", params: { event: "check_out" }, as: :json
    assert_response :unprocessable_entity
    assert_equal "invalid_transition", json.dig("error", "code")
    post "/api/v1/reservations/#{reservation.id}/transition", params: { event: "destroy" }, as: :json
    assert_response :unprocessable_entity

    get "/api/v1/calendar", params: { from: "nope", to: "2027-01-01" }
    assert_response :bad_request
    get "/api/v1/calendar", params: { from: "2027-01-01", to: "2028-01-01" }
    assert_response :bad_request
  end

  test "dashboard reports today's activity in the organization's time zone" do
    travel_to Time.zone.parse("2027-05-10 12:00") do
      @tenant.switch do
        unit = create_unit
        create_unit
        book(unit, Date.new(2027, 5, 10), Date.new(2027, 5, 13)).transition!(:confirm)
      end
      sign_in(@manager) # the session from setup has expired in 2027
      get "/api/v1/dashboard"
      assert_response :success
      assert_equal 1, json.dig("data", "arrivals").size
      assert_equal 2, json.dig("data", "units_count")
      assert_in_delta 3.0 / 60, json.dig("data", "occupancy_rate"), 0.0001
      assert_equal "360.0", json.dig("data", "revenue_month", "amount")
    end
  end

  test "read-only members can read but not write" do
    reader = add_member(@tenant, "read_only")
    sign_in(reader)
    get "/api/v1/properties"
    assert_response :success
    post "/api/v1/properties", params: { property: { name: "Nope" } }, as: :json
    assert_response :forbidden
  end

  test "another organization's reservations are invisible, even on the same shard" do
    other = create_tenant(subdomain: "globex", shard: @tenant.shard)
    foreign = other.switch { book(create_unit, Date.new(2027, 3, 1), Date.new(2027, 3, 3)) }

    get "/api/v1/reservations/#{foreign.id}"
    assert_response :not_found
    post "/api/v1/reservations/#{foreign.id}/transition", params: { event: "cancel" }, as: :json
    assert_response :not_found
    post "/api/v1/reservations", as: :json, params: {
      reservation: { unit_id: foreign.unit_id, check_in: "2027-04-01", check_out: "2027-04-03", guest_id: foreign.guest_id }
    }
    assert_response :not_found
    assert other.switch { foreign.reload.pending? }
  end
end
