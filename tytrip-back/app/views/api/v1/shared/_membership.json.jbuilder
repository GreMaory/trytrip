json.extract! membership, :id, :status, :created_at
json.user { json.partial! "api/v1/shared/user", user: membership.user }
json.role { json.extract! membership.role, :id, :key, :name }
