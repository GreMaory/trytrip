require "test_helper"

class CookieDomainTest < ActionDispatch::IntegrationTest
  test "auth and CSRF cookies are shared by the subdomains of the application domain" do
    on_host("app")
    sign_in(create_user)
    cookies_header = Array(response.headers["set-cookie"]).join("\n")
    assert_match(/tytrip_auth=[^\n]*domain=\.example\.com/i, cookies_header)
    assert_match(/XSRF-TOKEN=[^\n]*domain=\.example\.com/i, cookies_header)
  end

  test "cookies are host-only outside the application domain" do
    host! "localhost"
    get "/api/v1/csrf"
    assert_no_match(/domain=/i, Array(response.headers["set-cookie"]).join("\n"))
  end

  test "one sign in works across organizations" do
    user = create_user
    create_tenant(subdomain: "acme", owner: user)
    on_host("app")
    sign_in(user)
    on_host("acme")
    get "/api/v1/organization"
    assert_response :success
  end
end
