# Resolves the tenant from the request subdomain and runs the rest of the
# request inside its context (Current.tenant + shard connection).
#
# Lives in lib/ (not reloaded) because middlewares are built once at boot;
# the reloadable Identity::Tenant constant is looked up on each request.
#
#   acme.lvh.me      -> tenant "acme" (404 if unknown or suspended)
#   app.lvh.me       -> no tenant (portal: login, signup, organization choice)
#   admin.lvh.me     -> no tenant (platform administration)
#   lvh.me / IP      -> no tenant
#
# Controllers that need a tenant enforce it themselves (ApiController#require_tenant!).
module Middleware
  class TenantResolver
    RESERVED_SUBDOMAINS = %w[app admin www api mail static assets].freeze
    SUBDOMAIN_FORMAT = /\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z/
    EXEMPT_PATHS = %w[/up].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = ActionDispatch::Request.new(env)
      return @app.call(env) if EXEMPT_PATHS.include?(request.path)

      subdomain = request.subdomain.to_s.downcase
      return @app.call(env) if subdomain.empty? || RESERVED_SUBDOMAINS.include?(subdomain)
      return not_found unless SUBDOMAIN_FORMAT.match?(subdomain)

      tenant = Identity::Tenant.active.find_by(subdomain: subdomain)
      return not_found unless tenant

      tenant.switch { @app.call(env) }
    end

    private
      # Same response for malformed, unknown and suspended tenants: nothing
      # about the tenant registry leaks to the client.
      def not_found
        body = { error: { code: "not_found", message: "Not found" } }.to_json
        [ 404, { "content-type" => "application/json; charset=utf-8" }, [ body ] ]
      end
  end
end
