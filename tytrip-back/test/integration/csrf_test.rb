require "test_helper"

class CsrfTest < ActionDispatch::IntegrationTest
  setup do
    on_host("app")
    @previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    Api::V1::BaseController.allow_forgery_protection = true
    @user = create_user
  end

  teardown do
    ActionController::Base.allow_forgery_protection = @previous
    Api::V1::BaseController.allow_forgery_protection = @previous
  end

  test "unsafe requests without the CSRF token are rejected" do
    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :forbidden
    assert_equal "invalid_csrf_token", json.dig("error", "code")
  end

  test "the token from the XSRF-TOKEN cookie is accepted in the X-CSRF-Token header" do
    get "/api/v1/csrf"
    token = cookies["XSRF-TOKEN"]
    assert token.present?

    post "/api/v1/session", params: { email: @user.email, password: TestDataHelpers::PASSWORD },
      headers: { "X-CSRF-Token" => CGI.unescape(token) }, as: :json
    assert_response :success
  end
end
