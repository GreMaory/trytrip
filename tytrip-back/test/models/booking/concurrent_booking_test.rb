require "test_helper"

# Real concurrency: separate threads and database connections, no wrapping
# transaction (data is cleaned up explicitly).
class Booking::ConcurrentBookingTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @tenant = create_tenant
    @unit, @guest = @tenant.switch { [ create_unit, create_guest ] }
  end

  teardown do
    @tenant.switch do
      Booking::Reservation.delete_all
      Crm::Guest.delete_all
      Lodging::Unit.delete_all
      Lodging::Property.delete_all
    end
    Audit::Event.delete_all
    Identity::Membership.delete_all
    Identity::Invitation.delete_all
    Identity::Role.delete_all
    Identity::Session.delete_all
    Identity::Tenant.delete_all
    Identity::User.delete_all
  end

  test "only one of several simultaneous bookings of the same dates succeeds" do
    check_in = Date.new(2027, 8, 1)
    gate = Concurrent::CountDownLatch.new(1)

    results = Array.new(5) do
      Thread.new do
        Rails.application.executor.wrap do
          gate.wait
          @tenant.switch do
            book(Lodging::Unit.find(@unit.id), check_in, check_in + 3, guest: Crm::Guest.find(@guest.id))
            :booked
          rescue ActiveRecord::RecordInvalid
            :rejected
          end
        end
      end
    end
    gate.count_down
    outcomes = results.map(&:value)

    assert_equal 1, outcomes.count(:booked), outcomes.inspect
    assert_equal 1, @tenant.switch { Booking::Reservation.count }
  end
end
