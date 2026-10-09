# Development data. Idempotent: safe to run several times.
# Never runs in production (create real admins with bin/rails console there).
return if Rails.env.production?

PASSWORD = "TyTrip-dev-2026!"

admin = Identity::User.find_or_create_by!(email: "admin@tytrip.test") do |user|
  user.name = "Platform Admin"
  user.password = PASSWORD
  user.platform_role = "super_admin"
  user.email_verified_at = Time.current
end

owner = Identity::User.find_or_create_by!(email: "owner@demo.test") do |user|
  user.name = "Camille Martin"
  user.password = PASSWORD
  user.email_verified_at = Time.current
end

tenant = Identity::Tenant.find_by(subdomain: "demo") ||
  Identity::Tenant.provision!(owner: owner, name: "Demo Conciergerie", subdomain: "demo")

{ "manager@demo.test" => [ "Lucas Bernard", "manager" ], "staff@demo.test" => [ "Inès Petit", "staff" ] }.each do |email, (name, role)|
  user = Identity::User.find_or_create_by!(email: email) do |u|
    u.name = name
    u.password = PASSWORD
    u.email_verified_at = Time.current
  end
  tenant.memberships.find_or_create_by!(user: user) { |m| m.role = tenant.roles.find_by!(key: role) }
end

tenant.switch do
  next if Lodging::Property.exists?

  villa = Lodging::Property.create!(name: "Villa Les Pins", property_type: "villa", city: "Biarritz", postal_code: "64200",
    address_line1: "12 avenue de la Plage", country_code: "FR", amenities: %w[wifi pool parking terrace])
  villa.units.create!(name: "Villa Les Pins", max_guests: 8, bedrooms: 4, beds: 5, bathrooms: 2, base_rate: "320.00", min_stay: 3)

  residence = Lodging::Property.create!(name: "Résidence du Port", property_type: "apartment", city: "La Rochelle",
    postal_code: "17000", country_code: "FR", amenities: %w[wifi elevator washing_machine])
  studio = residence.units.create!(name: "Studio 1", max_guests: 2, base_rate: "75.00")
  t2 = residence.units.create!(name: "T2 vue mer", max_guests: 4, bedrooms: 1, beds: 2, base_rate: "110.00", min_stay: 2)

  today = Date.current
  guests = [ %w[Marie Curie marie.curie@example.com], %w[Paul Durand paul.durand@example.com], %w[Léa Moreau lea.moreau@example.com] ]
    .map { |first, last, email| Crm::Guest.create!(first_name: first, last_name: last, email: email, country_code: "FR") }

  [
    [ villa.units.first, guests[0], today - 2, today + 3, :check_in ],
    [ studio, guests[1], today, today + 2, :confirm ],
    [ t2, guests[2], today + 5, today + 9, nil ],
    [ studio, guests[0], today + 10, today + 14, :confirm ]
  ].each do |unit, guest, check_in, check_out, step|
    reservation = Booking::Reservation.new(unit: unit, guest: guest, check_in: check_in, check_out: check_out, adults: 2, source: "direct")
    reservation.save_with_unit_lock!
    reservation.transition!(:confirm) if step
    reservation.transition!(:check_in) if step == :check_in
  end

  Booking::AvailabilityBlock.new(unit: t2, starts_on: today + 20, ends_on: today + 25, reason: "maintenance", note: "Peinture")
    .save_with_unit_lock!
end

puts "Seeded: admin@tytrip.test, owner@demo.test, manager@demo.test, staff@demo.test (password: #{PASSWORD})"
puts "Organization: http://demo.#{Rails.application.config.x.app_domain}"
