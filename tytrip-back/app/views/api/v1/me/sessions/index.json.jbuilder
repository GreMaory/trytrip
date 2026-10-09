json.data @sessions do |session|
  json.extract! session, :id, :ip_address, :user_agent, :created_at, :last_seen_at, :expires_at
  json.current session.id == Current.session.id
end
