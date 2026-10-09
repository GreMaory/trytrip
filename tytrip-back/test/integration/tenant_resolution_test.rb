require "test_helper"

class TenantResolutionTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = create_tenant(subdomain: "acme")
    @owner = owner_of(@tenant)
  end

  test "unknown, malformed and suspended tenants get the same 404, without details" do
    suspended = create_tenant(subdomain: "closed")
    suspended.suspend!

    bodies = %w[nope closed bad_sub].map do |subdomain|
      on_host(subdomain)
      get "/api/v1/csrf"
      assert_response :not_found
      response.body
    end
    assert_equal 1, bodies.uniq.size
    assert_no_match(/closed|nope|shard/, bodies.first)
  end

  test "resolves the tenant on its subdomain" do
    on_host("acme")
    sign_in(@owner)
    get "/api/v1/organization"
    assert_response :success
    assert_equal "acme", json.dig("data", "subdomain")
  end

  test "health check works on any host" do
    on_host("nope")
    get "/up"
    assert_response :success
  end

  test "tenant endpoints are unavailable on tenant-less hosts" do
    on_host("app")
    sign_in(@owner)
    get "/api/v1/organization"
    assert_response :not_found
  end

  test "the shard cannot be chosen by the client" do
    on_host("acme")
    sign_in(@owner)
    other_shard = (Identity::Tenant.shard_keys - [ @tenant.shard ]).first
    get "/api/v1/organization", params: { shard: other_shard }, headers: { "X-Shard" => other_shard }
    assert_equal "acme", json.dig("data", "subdomain")
  end
end
