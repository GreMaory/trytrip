json.data @users, partial: "api/v1/admin/users/user", as: :user
json.partial! "api/v1/shared/pagination", pagination: @pagination
