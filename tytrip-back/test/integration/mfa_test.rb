require "test_helper"

class MfaTest < ActionDispatch::IntegrationTest
  setup do
    on_host("app")
    @user = create_user
  end

  def enable_mfa
    sign_in(@user)
    post "/api/v1/me/mfa"
    assert_response :success
    secret = json.dig("data", "secret")
    assert_match %r{\Aotpauth://totp/}, json.dig("data", "provisioning_uri")
    patch "/api/v1/me/mfa", params: { code: ROTP::TOTP.new(secret).now }, as: :json
    assert_response :success
    [ secret, json.dig("data", "recovery_codes") ]
  end

  test "enabling MFA then signing in requires the second factor" do
    secret, recovery_codes = enable_mfa
    assert_equal 10, recovery_codes.size
    delete "/api/v1/session"

    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    assert_equal true, json.dig("data", "mfa_required")
    get "/api/v1/me"
    assert_response :unauthorized, "password alone must not open a session"

    post "/api/v1/session/mfa", params: { code: "123456" }, as: :json
    assert_response :unauthorized

    travel 30.seconds do
      post "/api/v1/session/mfa", params: { code: ROTP::TOTP.new(secret).now }, as: :json
      assert_response :success
      get "/api/v1/me"
      assert_response :success
      assert json.dig("data", "mfa_enabled")
    end
  end

  test "a recovery code can complete sign in once" do
    _secret, recovery_codes = enable_mfa
    delete "/api/v1/session"

    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    post "/api/v1/session/mfa", params: { code: recovery_codes.first }, as: :json
    assert_response :success
    delete "/api/v1/session"

    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    post "/api/v1/session/mfa", params: { code: recovery_codes.first }, as: :json
    assert_response :unauthorized
  end

  test "the MFA challenge is limited in attempts and time" do
    enable_mfa
    delete "/api/v1/session"
    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json

    Api::V1::SessionsController::MAX_MFA_ATTEMPTS.times do
      post "/api/v1/session/mfa", params: { code: "000000" }, as: :json
    end
    post "/api/v1/session/mfa", params: { code: "000000" }, as: :json
    assert_equal "unauthorized", json.dig("error", "code")

    post "/api/v1/session/mfa", params: { code: ROTP::TOTP.new(@user.reload.otp_secret).now }, as: :json
    assert_response :unauthorized, "challenge must be discarded after too many attempts"
  end

  test "disabling MFA requires the password and a valid code" do
    secret, = enable_mfa
    delete "/api/v1/me/mfa", params: { password: "wrong", code: "000000" }, as: :json
    assert_response :unprocessable_entity
    assert @user.reload.mfa_enabled?

    travel 30.seconds do
      delete "/api/v1/me/mfa", params: { password: TestDataHelpers::PASSWORD, code: ROTP::TOTP.new(secret).now }, as: :json
      assert_response :no_content
    end
    assert_not @user.reload.mfa_enabled?
  end
end
