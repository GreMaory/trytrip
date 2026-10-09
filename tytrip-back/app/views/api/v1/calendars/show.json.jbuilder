json.data do
  json.from @from
  json.to @to
  json.units @units do |unit|
    json.extract! unit, :id, :name, :max_guests
    json.property { json.extract! unit.property, :id, :name }
    json.reservations @reservations.fetch(unit.id, []) do |reservation|
      json.extract! reservation, :id, :reference, :status, :check_in, :check_out, :adults, :children
      json.guest_name reservation.guest.full_name
    end
    json.blocks @blocks.fetch(unit.id, []), partial: "api/v1/availability_blocks/availability_block", as: :availability_block
  end
end
