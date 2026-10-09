json.data @events do |event|
  json.extract! event, :id, :action, :subject_type, :subject_id, :metadata, :ip_address, :tenant_id, :created_at
  json.actor do
    if event.actor
      json.partial! "api/v1/shared/user", user: event.actor
    else
      json.nil!
    end
  end
end
json.partial! "api/v1/shared/pagination", pagination: @pagination
