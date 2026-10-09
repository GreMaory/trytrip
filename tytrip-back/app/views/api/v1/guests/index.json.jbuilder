json.data @guests, partial: "api/v1/guests/guest", as: :guest
json.partial! "api/v1/shared/pagination", pagination: @pagination
