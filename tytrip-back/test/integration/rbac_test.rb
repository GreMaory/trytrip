require "test_helper"

class RbacTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = create_tenant(subdomain: "acme")
    @owner = owner_of(@tenant)
    @admin = add_member(@tenant, "admin")
    @manager = add_member(@tenant, "manager")
    @staff = add_member(@tenant, "staff")
    on_host("acme")
  end

  def membership(user) = user.membership_for(@tenant)

  test "permissions are enforced by the API" do
    sign_in(@staff)
    get "/api/v1/memberships"
    assert_response :forbidden
    patch "/api/v1/organization", params: { organization: { name: "Hacked" } }, as: :json
    assert_response :forbidden
    assert_equal "Acme", @tenant.reload.name

    sign_in(@admin)
    get "/api/v1/memberships"
    assert_response :success
    assert_equal 4, json.dig("meta", "pagination", "total")
  end

  test "a suspended membership has no permissions" do
    membership(@admin).update!(status: :suspended)
    sign_in(@admin)
    get "/api/v1/organization"
    assert_response :forbidden
  end

  test "an admin cannot grant the owner role nor manage an owner" do
    sign_in(@admin)
    patch "/api/v1/memberships/#{membership(@manager).id}", params: { membership: { role_id: @tenant.roles.owner!.id } }, as: :json
    assert_response :forbidden
    delete "/api/v1/memberships/#{membership(@owner).id}"
    assert_response :forbidden
    assert membership(@manager).reload.role.key == "manager"
  end

  test "nobody can change their own membership" do
    sign_in(@owner)
    patch "/api/v1/memberships/#{membership(@owner).id}", params: { membership: { status: "suspended" } }, as: :json
    assert_response :forbidden
  end

  test "users cannot grant permissions they do not have" do
    # A custom role able to manage members but without billing.
    hr = @tenant.roles.create!(name: "HR", permissions: %w[members.read members.manage roles.manage])
    hr_user = create_user
    @tenant.memberships.create!(user: hr_user, role: hr)
    sign_in(hr_user)

    post "/api/v1/roles", params: { role: { name: "Sneaky", permissions: %w[billing.manage] } }, as: :json
    assert_response :forbidden

    patch "/api/v1/roles/#{hr.id}", params: { role: { permissions: %w[members.read members.manage roles.manage billing.manage] } }, as: :json
    assert_response :forbidden
    assert_not_includes hr.reload.permissions, "billing.manage"

    patch "/api/v1/memberships/#{membership(@staff).id}", params: { membership: { role_id: @tenant.roles.find_by!(key: "admin").id } }, as: :json
    assert_response :forbidden

    # Allowed: a role within their own permissions.
    post "/api/v1/roles", params: { role: { name: "Viewer", permissions: %w[members.read] } }, as: :json
    assert_response :created
  end

  test "admins manage roles and memberships, and changes are audited" do
    sign_in(@admin)
    post "/api/v1/roles", params: { role: { name: "Cleaner lead", permissions: %w[housekeeping.read housekeeping.manage] } }, as: :json
    assert_response :created
    role_id = json.dig("data", "id")

    patch "/api/v1/memberships/#{membership(@staff).id}", params: { membership: { role_id: role_id } }, as: :json
    assert_response :success
    assert_equal "Cleaner lead", json.dig("data", "role", "name")

    assert Audit::Event.exists?(action: "role.created", tenant: @tenant, actor: @admin)
    assert Audit::Event.exists?(action: "membership.updated", tenant: @tenant, actor: @admin)

    get "/api/v1/audit_events"
    assert_response :success
    assert json["data"].any? { |event| event["action"] == "membership.updated" }
  end

  test "system roles cannot be edited" do
    sign_in(@owner)
    patch "/api/v1/roles/#{@tenant.roles.owner!.id}", params: { role: { name: "Boss" } }, as: :json
    assert_response :unprocessable_entity
  end
end
