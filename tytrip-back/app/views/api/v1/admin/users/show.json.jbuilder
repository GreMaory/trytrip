json.data do
  json.partial! "api/v1/admin/users/user", user: @user
  json.memberships @memberships do |membership|
    json.extract! membership, :id, :status
    json.organization { json.extract! membership.tenant, :id, :name, :subdomain }
    json.role membership.role.name
  end
end
