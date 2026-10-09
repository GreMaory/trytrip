require "test_helper"

class AccountRecoveryTest < ActionDispatch::IntegrationTest
  setup { on_host("app") }

  test "password reset: same answer for unknown emails, single-use token, sessions revoked" do
    user = create_user
    old_session = user.sessions.create!

    assert_no_enqueued_emails do
      post "/api/v1/password_reset", params: { email: "ghost@example.com" }, as: :json
    end
    assert_response :accepted

    perform_enqueued_jobs do
      post "/api/v1/password_reset", params: { email: user.email.upcase }, as: :json
    end
    assert_response :accepted
    mail = ActionMailer::Base.deliveries.last
    assert_equal [ user.email ], mail.to
    token = mail.text_part.body.to_s[/token=([^\s]+)/, 1]
    assert token

    patch "/api/v1/password_reset", params: { token: CGI.unescape(token), password: "Totally-new-pass-77" }, as: :json
    assert_response :no_content
    assert user.reload.authenticate("Totally-new-pass-77")
    assert old_session.reload.revoked_at

    patch "/api/v1/password_reset", params: { token: CGI.unescape(token), password: "Yet-another-pass-88" }, as: :json
    assert_response :unprocessable_entity
  end

  test "signup creates the user, the organization and sends a verification email" do
    perform_enqueued_jobs do
      post "/api/v1/signup", as: :json, params: {
        user: { name: "Owner", email: "owner@example.com", password: TestDataHelpers::PASSWORD },
        organization: { name: "Sea View", subdomain: "sea-view" }
      }
    end
    assert_response :created
    assert_equal "sea-view", json.dig("data", "organization", "subdomain")

    user = Identity::User.find_by!(email: "owner@example.com")
    assert_not user.email_verified?
    assert user.membership_for(Identity::Tenant.find_by!(subdomain: "sea-view")).owner?

    mail = ActionMailer::Base.deliveries.last
    token = mail.text_part.body.to_s[/token=([^\s]+)/, 1]
    patch "/api/v1/email_verification", params: { token: CGI.unescape(token) }, as: :json
    assert_response :no_content
    assert user.reload.email_verified?
  end

  test "signup is atomic: an invalid organization does not leave a user behind" do
    post "/api/v1/signup", as: :json, params: {
      user: { name: "Owner", email: "owner2@example.com", password: TestDataHelpers::PASSWORD },
      organization: { name: "Bad", subdomain: "admin" }
    }
    assert_response :unprocessable_entity
    assert json.dig("error", "details", "subdomain")
    assert_not Identity::User.exists?(email: "owner2@example.com")
  end
end
