require "test_helper"

class Booking::ReservationTest < ActiveSupport::TestCase
  setup do
    @tenant = create_tenant
    @day = Date.new(2027, 7, 1)
  end

  def within_tenant(&block) = @tenant.switch(&block)

  test "prices the stay from the unit rate with decimal arithmetic" do
    within_tenant do
      unit = create_unit(base_rate: "99.99")
      reservation = book(unit, @day, @day + 3)
      assert_equal BigDecimal("99.99"), reservation.nightly_rate
      assert_equal BigDecimal("299.97"), reservation.total_amount
      assert_equal "EUR", reservation.currency
      assert_match(/\AR[A-Z0-9]{7}\z/, reservation.reference)

      unit.update!(base_rate: "150")
      assert_equal BigDecimal("299.97"), reservation.reload.total_amount, "rate changes do not alter existing bookings"
    end
  end

  test "rejects overlapping live reservations but allows back-to-back stays" do
    within_tenant do
      unit = create_unit
      book(unit, @day, @day + 3)
      assert_raises(ActiveRecord::RecordInvalid) { book(unit, @day + 2, @day + 5) }
      assert_raises(ActiveRecord::RecordInvalid) { book(unit, @day - 1, @day + 4) }
      assert book(unit, @day + 3, @day + 5).persisted?, "check-out day is free for the next arrival"
      assert book(unit, @day - 2, @day).persisted?
    end
  end

  test "cancelled reservations free the dates" do
    within_tenant do
      unit = create_unit
      first = book(unit, @day, @day + 3)
      first.transition!(:cancel, reason: "Guest request")
      assert book(unit, @day, @day + 3).persisted?
      assert_equal "Guest request", first.reload.cancellation_reason
    end
  end

  test "the database rejects overlaps even when validations are bypassed" do
    within_tenant do
      unit = create_unit
      book(unit, @day, @day + 3)
      overlapping = Booking::Reservation.new(unit: unit, guest: create_guest, check_in: @day + 1, check_out: @day + 2,
        reference: "RMANUAL1", nightly_rate: 1, total_amount: 1, currency: "EUR")
      error = assert_raises(ActiveRecord::StatementInvalid) { overlapping.save!(validate: false) }
      assert ApplicationRecord.exclusion_violation?(error)
    end
  end

  test "availability blocks and reservations exclude each other" do
    within_tenant do
      unit = create_unit
      Booking::AvailabilityBlock.new(unit: unit, starts_on: @day, ends_on: @day + 7, reason: "maintenance").save_with_unit_lock!
      assert_raises(ActiveRecord::RecordInvalid) { book(unit, @day + 6, @day + 8) }

      book(unit, @day + 10, @day + 12)
      block = Booking::AvailabilityBlock.new(unit: unit, starts_on: @day + 11, ends_on: @day + 13)
      assert_not block.valid?
    end
  end

  test "enforces capacity and stay length" do
    within_tenant do
      unit = create_unit(max_guests: 2, min_stay: 2, max_stay: 7)
      too_many = Booking::Reservation.new(unit: unit, guest: create_guest, check_in: @day, check_out: @day + 3, adults: 2, children: 1)
      assert_not too_many.valid?
      assert too_many.errors.of_kind?(:base, :too_many_guests)

      assert Booking::Reservation.new(unit: unit, guest: create_guest, check_in: @day, check_out: @day + 1).invalid?
      assert Booking::Reservation.new(unit: unit, guest: create_guest, check_in: @day, check_out: @day + 8).invalid?
      assert Booking::Reservation.new(unit: unit, guest: create_guest, check_in: @day, check_out: @day).invalid?
    end
  end

  test "follows the status lifecycle" do
    within_tenant do
      reservation = book(create_unit, @day, @day + 2)
      assert_equal %i[confirm cancel], reservation.available_events
      assert_raises(Booking::Reservation::InvalidTransition) { reservation.transition!(:check_out) }

      reservation.transition!(:confirm)
      reservation.transition!(:check_in)
      reservation.transition!(:check_out)
      assert reservation.checked_out?
      assert reservation.confirmed_at && reservation.checked_in_at && reservation.checked_out_at
      assert_raises(Booking::Reservation::InvalidTransition) { reservation.transition!(:cancel) }
    end
  end
end
