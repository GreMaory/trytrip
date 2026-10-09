require "test_helper"

class Identity::UserTest < ActiveSupport::TestCase
  test "normalizes email and enforces a password policy" do
    user = create_user(email: "  Jane.Doe@Example.COM ")
    assert_equal "jane.doe@example.com", user.email

    assert_not Identity::User.new(email: "a@example.com", name: "A", password: "short").valid?
    weak = Identity::User.new(email: "jane.smith@example.com", name: "J", password: "jane.smith-is-me-2024")
    assert_not weak.valid?
    assert weak.errors.of_kind?(:password, :contains_email)
  end

  test "rejects duplicate emails case-insensitively" do
    create_user(email: "dup@example.com")
    assert_not Identity::User.new(email: "DUP@example.com", name: "x", password: TestDataHelpers::PASSWORD).valid?
  end

  test "locks the account after too many failed logins" do
    user = create_user
    (Identity::User::MAX_FAILED_LOGINS - 1).times { user.register_failed_login! }
    assert_not user.locked?
    user.register_failed_login!
    assert user.reload.locked?

    travel Identity::User::LOCK_DURATION + 1.second do
      assert_not user.reload.locked?
    end
  end

  test "password reset tokens are single use and expire" do
    user = create_user
    token = user.generate_token_for(:password_reset)
    assert_equal user, Identity::User.find_by_token_for(:password_reset, token)

    user.update!(password: "Another-strong-pass-42")
    assert_nil Identity::User.find_by_token_for(:password_reset, token)

    token = user.generate_token_for(:password_reset)
    travel 31.minutes do
      assert_nil Identity::User.find_by_token_for(:password_reset, token)
    end
  end

  test "email verification tokens stop working once the email is verified" do
    user = create_user(email_verified_at: nil)
    token = user.generate_token_for(:email_verification)
    Identity::User.find_by_token_for(:email_verification, token).verify_email!
    assert user.reload.email_verified?
    assert_nil Identity::User.find_by_token_for(:email_verification, token)
  end

  test "TOTP codes cannot be replayed and recovery codes are single use" do
    user = create_user
    user.start_mfa_setup!
    totp = ROTP::TOTP.new(user.otp_secret)

    assert_not user.enable_mfa!("000000")
    codes = user.enable_mfa!(totp.now)
    assert_equal Identity::User::RECOVERY_CODES_COUNT, codes.size
    assert user.mfa_enabled?

    # The code used for activation cannot be used again.
    assert_not user.verify_second_factor!(totp.now)
    travel 30.seconds do
      assert user.verify_second_factor!(totp.now)
    end

    assert user.verify_second_factor!(codes.first)
    assert_not user.verify_second_factor!(codes.first)
    assert_not_includes user.reload.otp_recovery_code_digests, Digest::SHA256.hexdigest(codes.first)
  end

  test "the OTP secret is encrypted at rest" do
    user = create_user
    user.start_mfa_setup!
    raw = Identity::User.connection.select_value("SELECT otp_secret FROM users WHERE id = #{user.id}")
    assert_not_equal user.otp_secret, raw
  end
end
