json.data @units do |unit|
  json.partial! "api/v1/units/unit", unit: unit
  json.property_name unit.property.name
end
