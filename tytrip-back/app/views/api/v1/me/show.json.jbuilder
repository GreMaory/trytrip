json.data do
  json.extract! @user, :id, :name, :email, :locale, :time_zone, :preferences, :last_sign_in_at
  json.email_verified @user.email_verified?
  json.mfa_enabled @user.mfa_enabled?
  json.platform_admin @user.platform_super_admin?

  json.organizations @memberships do |membership|
    json.extract! membership.tenant, :id, :name, :subdomain
    json.host membership.tenant.host
    json.role membership.role.name
  end

  json.current_organization do
    if @current_membership
      json.partial! "api/v1/shared/tenant", tenant: @current_membership.tenant
      json.membership_id @current_membership.id
      json.role { json.extract! @current_membership.role, :id, :key, :name }
      json.permissions @current_membership.permissions
    else
      json.nil!
    end
  end
end
