require "test_helper"

class PlatformAdminTest < ActionDispatch::IntegrationTest
  setup do
    on_host("admin")
    @admin = create_user(platform_role: "super_admin")
    @tenant = create_tenant(subdomain: "acme")
  end

  test "organization owners are not platform admins" do
    sign_in(owner_of(@tenant))
    get "/api/v1/admin/tenants"
    assert_response :forbidden
  end

  test "platform admins list, create and suspend organizations" do
    sign_in(@admin)
    get "/api/v1/admin/tenants"
    assert_response :success
    assert_equal [ "acme" ], json["data"].map { |tenant| tenant["subdomain"] }

    assert_enqueued_emails 1 do
      post "/api/v1/admin/tenants", params: { organization: { name: "Globex", subdomain: "globex" }, owner_email: "boss@globex.test" }, as: :json
    end
    assert_response :created
    globex = Identity::Tenant.find_by!(subdomain: "globex")
    assert globex.invitations.pending.exists?(email: "boss@globex.test", role: globex.roles.owner!)

    post "/api/v1/admin/tenants/#{@tenant.id}/suspend"
    assert_response :success
    assert @tenant.reload.suspended?
    assert Audit::Event.exists?(action: "admin.organization.suspended", actor: @admin)

    on_host("acme")
    get "/api/v1/organization"
    assert_response :not_found
  end

  test "platform admins can suspend a user, which revokes their sessions" do
    user = owner_of(@tenant)
    session = user.sessions.create!
    sign_in(@admin)
    post "/api/v1/admin/users/#{user.id}/suspend"
    assert_response :success
    assert user.reload.suspended?
    assert session.reload.revoked_at

    post "/api/v1/admin/users/#{@admin.id}/suspend"
    assert_response :forbidden
  end

  test "two-factor authentication can be required for platform admins" do
    Rails.application.config.x.require_mfa_for_platform_admins = true
    sign_in(@admin)
    get "/api/v1/admin/tenants"
    assert_response :forbidden
  ensure
    Rails.application.config.x.require_mfa_for_platform_admins = false
  end
end
