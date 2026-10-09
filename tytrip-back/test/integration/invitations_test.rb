require "test_helper"

class InvitationsTest < ActionDispatch::IntegrationTest
  setup do
    @tenant = create_tenant(subdomain: "acme")
    @owner = owner_of(@tenant)
    @staff_role = @tenant.roles.find_by!(key: "staff")
  end

  def invite(email, role: @staff_role)
    on_host("acme")
    sign_in(@owner)
    perform_enqueued_jobs do
      post "/api/v1/invitations", params: { invitation: { email: email, role_id: role.id } }, as: :json
    end
    assert_response :created
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ email ], mail.to
    delete "/api/v1/session"
    CGI.unescape(mail.text_part.body.to_s[/token=([^\s]+)/, 1])
  end

  test "a new user accepts an invitation, gets an account and the membership" do
    token = invite("newbie@example.com")

    on_host("app")
    get "/api/v1/invitation_acceptance", params: { token: token }
    assert_response :success
    assert_equal "Acme", json.dig("data", "organization", "name")
    assert_equal false, json.dig("data", "existing_account")

    post "/api/v1/invitation_acceptance", params: { token: token, name: "Newbie", password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :success
    assert json.dig("data", "signed_in")

    user = Identity::User.find_by!(email: "newbie@example.com")
    assert user.email_verified?
    assert_equal "staff", user.membership_for(@tenant).role.key

    post "/api/v1/invitation_acceptance", params: { token: token, name: "Again", password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :not_found, "invitations are single use"
  end

  test "an existing user must confirm with their password" do
    existing = create_user(email: "known@example.com")
    token = invite("known@example.com")

    on_host("app")
    post "/api/v1/invitation_acceptance", params: { token: token, password: "wrong-password" }, as: :json
    assert_response :unauthorized
    assert_nil existing.membership_for(@tenant)

    post "/api/v1/invitation_acceptance", params: { token: token, password: TestDataHelpers::PASSWORD }, as: :json
    assert_response :success
    assert existing.membership_for(@tenant)
  end

  test "expired and revoked invitations cannot be accepted" do
    token = invite("late@example.com")
    on_host("app")
    travel Identity::Invitation::LIFETIME + 1.minute do
      get "/api/v1/invitation_acceptance", params: { token: token }
      assert_response :not_found
    end

    token = invite("revoked@example.com")
    @tenant.invitations.find_by!(email: "revoked@example.com").revoke!
    on_host("app")
    get "/api/v1/invitation_acceptance", params: { token: token }
    assert_response :not_found
  end

  test "an admin cannot invite someone as owner" do
    admin = add_member(@tenant, "admin")
    on_host("acme")
    sign_in(admin)
    post "/api/v1/invitations", params: { invitation: { email: "boss@example.com", role_id: @tenant.roles.owner!.id } }, as: :json
    assert_response :forbidden
  end

  test "members cannot be invited twice while an invitation is pending" do
    invite("twice@example.com")
    on_host("acme")
    sign_in(@owner)
    post "/api/v1/invitations", params: { invitation: { email: "twice@example.com", role_id: @staff_role.id } }, as: :json
    assert_response :unprocessable_entity
  end
end
