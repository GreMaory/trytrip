json.extract! invitation, :id, :email, :expires_at, :created_at
json.role { json.extract! invitation.role, :id, :name }
json.invited_by { json.partial! "api/v1/shared/user", user: invitation.invited_by }
