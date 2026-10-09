json.extract! property, :id, :name, :property_type, :status, :description, :address_line1, :address_line2,
  :postal_code, :city, :country_code, :time_zone, :check_in_time, :check_out_time, :house_rules,
  :access_instructions, :amenities, :created_at, :updated_at
json.latitude property.latitude&.to_s
json.longitude property.longitude&.to_s
json.units property.units, partial: "api/v1/units/unit", as: :unit
