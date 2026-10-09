json.data @reservations, partial: "api/v1/reservations/reservation", as: :reservation
json.partial! "api/v1/shared/pagination", pagination: @pagination
