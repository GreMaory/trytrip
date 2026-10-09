require "test_helper"

class LocaleTest < ActionDispatch::IntegrationTest
  setup { on_host("app") }

  test "messages are in French by default and follow Accept-Language for anonymous users" do
    post "/api/v1/session", params: { email: "x@example.com", password: "nope-nope-nope" }, as: :json
    assert_equal "Email ou mot de passe incorrect", json.dig("error", "message")

    post "/api/v1/session", params: { email: "x@example.com", password: "nope-nope-nope" }, as: :json,
      headers: { "Accept-Language" => "en-US,en;q=0.9" }
    assert_equal "Invalid email or password", json.dig("error", "message")
  end

  test "signed-in users get their preferred language" do
    user = create_user(locale: "en")
    sign_in(user)
    patch "/api/v1/me", params: { user: { time_zone: "Not/AZone" } }, as: :json
    assert_equal "Validation failed", json.dig("error", "message")
  end
end
