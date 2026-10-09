json.extract! reservation, :id, :reference, :status, :source, :check_in, :check_out, :nights, :adults, :children,
  :currency, :notes, :special_requests, :confirmed_at, :checked_in_at, :checked_out_at, :cancelled_at,
  :cancellation_reason, :created_at, :updated_at
json.nightly_rate reservation.nightly_rate.to_s
json.total_amount reservation.total_amount.to_s
json.available_events reservation.available_events
json.unit do
  json.extract! reservation.unit, :id, :name
  json.property { json.extract! reservation.unit.property, :id, :name }
end
json.guest { json.partial! "api/v1/guests/guest", guest: reservation.guest }
