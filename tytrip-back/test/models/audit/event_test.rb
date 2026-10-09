require "test_helper"

class Audit::EventTest < ActiveSupport::TestCase
  test "scrubs secrets from metadata and is append-only" do
    event = Audit::Event.record!("auth.test.done", actor: nil, tenant: nil,
      metadata: { password: "x", nested: { api_token: "y", ok: 1 }, list: [ { otp_code: "1" } ] })

    assert_equal "[FILTERED]", event.metadata["password"]
    assert_equal({ "api_token" => "[FILTERED]", "ok" => 1 }, event.metadata["nested"])
    assert_equal [ { "otp_code" => "[FILTERED]" } ], event.metadata["list"]
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "auth.other.done") }
  end
end
