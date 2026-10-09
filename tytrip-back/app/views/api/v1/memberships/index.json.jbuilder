json.data @memberships, partial: "api/v1/shared/membership", as: :membership
json.partial! "api/v1/shared/pagination", pagination: @pagination
