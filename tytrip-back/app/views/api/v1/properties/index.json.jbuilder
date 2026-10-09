json.data @properties, partial: "api/v1/properties/property", as: :property
json.partial! "api/v1/shared/pagination", pagination: @pagination
