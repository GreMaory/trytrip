json.extract! unit, :id, :property_id, :name, :status, :max_guests, :bedrooms, :beds, :min_stay, :max_stay
json.bathrooms unit.bathrooms.to_s
json.base_rate unit.base_rate.to_s
