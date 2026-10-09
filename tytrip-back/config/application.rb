require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
require "rails/test_unit/railtie"
require_relative "../lib/middleware/tenant_resolver"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TytripBack
  class Application < Rails::Application
    config.load_defaults 8.0
    config.api_only = true
    config.time_zone = "UTC"
    config.i18n.available_locales = %i[fr en]
    config.i18n.default_locale = :fr

    # Domain-oriented code lives in app/domains/<domain>/<kind>/*.rb.
    # The <kind> folders (models/, services/...) are collapsed so that
    # app/domains/identity/models/tenant.rb defines Identity::Tenant.
    config.paths.add "app/domains", eager_load: true
    Rails.autoloaders.main.tap do |autoloader|
      Dir[Rails.root.join("app/domains/*/*")].select { |path| File.directory?(path) }.each do |subdir|
        autoloader.collapse(subdir)
      end
    end

    # Tenant shards (see config/shards.yml and docs/multi-tenancy.md)
    config.x.tenant_shards = config_for(:shards)

    # Public domain of the application; tenants live on <subdomain>.<app_domain>.
    config.x.app_domain = ENV.fetch("APP_DOMAIN", "lvh.me")
    config.x.app_protocol = ENV.fetch("APP_PROTOCOL", "http")
    config.x.require_mfa_for_platform_admins = ENV.fetch("REQUIRE_MFA_FOR_PLATFORM_ADMINS", Rails.env.production?.to_s) == "true"
    config.x.mail_from_address = ENV.fetch("MAIL_FROM_ADDRESS", "no-reply@tytrip.com")
    config.x.mail_from = "TyTrip <#{config.x.mail_from_address}>"

    # The SPA is served on the same site as the API (Traefik routes /api to
    # Rails), so authentication uses cookies. Cookies are shared across the
    # subdomains of APP_DOMAIN so that one login works for every organization
    # the user belongs to; on other hosts (localhost...) they are host-only.
    # (Rails' `domain: :all` guesses the domain and gets "lvh.me" wrong.)
    config.x.cookie_domain = ->(request) {
      domain = Rails.application.config.x.app_domain
      ".#{domain}" if request.host == domain || request.host.end_with?(".#{domain}")
    }
    config.session_store :cookie_store, key: "_tytrip_session", domain: config.x.cookie_domain, same_site: :lax, httponly: true
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options

    # Must run after cookies/session and inside the executor (which resets Current).
    config.middleware.use Middleware::TenantResolver
  end
end
