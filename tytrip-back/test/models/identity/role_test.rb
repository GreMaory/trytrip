require "test_helper"

class Identity::RoleTest < ActiveSupport::TestCase
  setup { @tenant = create_tenant }

  test "rejects unknown permissions" do
    role = @tenant.roles.new(name: "Custom", permissions: %w[properties.read nuclear.launch])
    assert_not role.valid?
    assert role.errors.of_kind?(:permissions, :inclusion)
  end

  test "the owner role is immutable and always has every permission" do
    owner = @tenant.roles.owner!
    assert_not owner.update(name: "Boss")
    assert_not owner.destroy
    assert_equal Identity::Permissions::KEYS, owner.effective_permissions
  end

  test "a role in use cannot be deleted" do
    role = @tenant.roles.find_by!(key: "staff")
    add_member(@tenant, "staff")
    assert_not role.destroy
  end

  test "a membership cannot use a role from another organization" do
    other = create_tenant
    membership = @tenant.memberships.new(user: create_user, role: other.roles.find_by!(key: "admin"))
    assert_not membership.valid?
  end
end
