require "test_helper"

class AuthenticationTest < ActionDispatch::IntegrationTest
  setup do
    on_host("app")
    @user = create_user(email: "jane@example.com")
  end

  test "signs in and out with a session cookie" do
    sign_in(@user)
    assert_equal false, json.dig("data", "mfa_required")
    get "/api/v1/me"
    assert_response :success
    assert_equal "jane@example.com", json.dig("data", "email")

    delete "/api/v1/session"
    assert_response :no_content
    get "/api/v1/me"
    assert_response :unauthorized
    assert Identity::Session.where(user: @user).all? { |session| session.revoked_at.present? }
  end

  test "the session cookie is HttpOnly and the token is only stored as a digest" do
    sign_in(@user)
    cookie_header = Array(response.headers["set-cookie"]).join("\n")
    assert_match(/tytrip_auth=.*HttpOnly/i, cookie_header)
    assert_match(/tytrip_auth=.*SameSite=Lax/i, cookie_header)
    session = @user.sessions.last
    assert_equal 64, session.token_digest.length
  end

  test "failed sign in does not reveal whether the account exists" do
    post "/api/v1/session", params: { email: "jane@example.com", password: "wrong-password-123" }, as: :json
    wrong_password = [ response.status, response.body ]
    post "/api/v1/session", params: { email: "ghost@example.com", password: "wrong-password-123" }, as: :json
    unknown_email = [ response.status, response.body ]

    assert_equal 401, wrong_password.first
    assert_equal wrong_password, unknown_email
    assert_equal 2, Audit::Event.where(action: "auth.login.failed").count
  end

  test "locked and suspended accounts cannot sign in, with the same message" do
    @user.update_columns(locked_until: 10.minutes.from_now)
    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :unauthorized
    assert_equal "invalid_credentials", json.dig("error", "code")

    @user.update_columns(locked_until: nil, status: "suspended")
    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :unauthorized
  end

  test "suspending a user invalidates their existing sessions" do
    sign_in(@user)
    @user.update!(status: :suspended)
    get "/api/v1/me"
    assert_response :unauthorized
  end

  test "sign in is rate limited" do
    10.times { post "/api/v1/session", params: { email: "x@example.com", password: "nope-nope-nope" }, as: :json }
    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :too_many_requests
  end

  test "sessions expire" do
    sign_in(@user)
    travel Identity::Session::LIFETIME + 1.minute do
      get "/api/v1/me"
      assert_response :unauthorized
    end
  end

  test "users can list and revoke their other sessions" do
    sign_in(@user)
    other = @user.sessions.create!
    get "/api/v1/me/sessions"
    assert_equal 2, json["data"].size
    assert_equal 1, json["data"].count { |session| session["current"] }

    delete "/api/v1/me/sessions/others"
    assert_response :no_content
    assert other.reload.revoked_at
    get "/api/v1/me"
    assert_response :success
  end

  test "changing the password requires the current one and revokes other sessions" do
    sign_in(@user)
    other = @user.sessions.create!

    patch "/api/v1/me/password", params: { current_password: "wrong", password: "Brand-new-password-1" }, as: :json
    assert_response :unprocessable_entity

    assert_enqueued_emails 1 do
      patch "/api/v1/me/password", params: { current_password: TestDataHelpers::PASSWORD, password: "Brand-new-password-1" }, as: :json
    end
    assert_response :no_content
    assert other.reload.revoked_at
    assert @user.reload.authenticate("Brand-new-password-1")
  end
end
