json.data @roles do |role|
  json.partial! "api/v1/shared/role", role: role
  json.members_count @member_counts.fetch(role.id, 0)
end
