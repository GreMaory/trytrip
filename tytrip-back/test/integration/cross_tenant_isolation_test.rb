require "test_helper"

# A member of one organization must never reach another organization's data,
# even when knowing its identifiers.
class CrossTenantIsolationTest < ActionDispatch::IntegrationTest
  setup do
    @acme = create_tenant(subdomain: "acme")
    @globex = create_tenant(subdomain: "globex")
    @acme_owner = owner_of(@acme)
    @globex_owner = owner_of(@globex)
  end

  test "a user cannot use another organization's subdomain" do
    on_host("globex")
    sign_in(@acme_owner)
    get "/api/v1/organization"
    assert_response :forbidden
    get "/api/v1/memberships"
    assert_response :forbidden
  end

  test "identifiers from another organization are not found from one's own subdomain" do
    globex_role = @globex.roles.find_by!(key: "admin")
    globex_membership = @globex_owner.membership_for(@globex)

    on_host("acme")
    sign_in(@acme_owner)
    get "/api/v1/roles/#{globex_role.id}"
    assert_response :not_found
    patch "/api/v1/roles/#{globex_role.id}", params: { role: { name: "pwned" } }, as: :json
    assert_response :not_found
    delete "/api/v1/memberships/#{globex_membership.id}"
    assert_response :not_found

    # Assigning another organization's role to one's own member
    staff = add_member(@acme, "staff")
    patch "/api/v1/memberships/#{staff.membership_for(@acme).id}", params: { membership: { role_id: globex_role.id } }, as: :json
    assert_response :not_found

    assert_equal "Administrateur", globex_role.reload.name
    assert globex_membership.reload.persisted?
  end

  test "audit events are scoped to the organization" do
    Audit::Event.record!("test.globex.secret", tenant: @globex, actor: @globex_owner)
    on_host("acme")
    sign_in(@acme_owner)
    get "/api/v1/audit_events", params: { per_page: 100 }
    assert json["data"].none? { |event| event["action"] == "test.globex.secret" }
  end
end
