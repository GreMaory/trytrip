json.data do
  json.partial! "api/v1/guests/guest", guest: @guest
  if @reservations
    json.reservations @reservations do |reservation|
      json.extract! reservation, :id, :reference, :status, :check_in, :check_out
      json.total_amount reservation.total_amount.to_s
      json.currency reservation.currency
      json.unit_name reservation.unit.name
      json.property_name reservation.unit.property.name
    end
  end
end
