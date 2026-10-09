# An organization using TyTrip. Lives in the catalog database; its business
# data lives on the shard named by `shard` (see config/shards.yml).
module Identity
  class Tenant < CatalogRecord
    SUBDOMAIN_FORMAT = Middleware::TenantResolver::SUBDOMAIN_FORMAT
    RESERVED_SUBDOMAINS = Middleware::TenantResolver::RESERVED_SUBDOMAINS

    enum :status, { active: "active", suspended: "suspended" }, default: "active", validate: true

    has_many :memberships, dependent: :destroy
    has_many :users, through: :memberships
    has_many :roles, dependent: :destroy
    has_many :invitations, dependent: :destroy

    normalizes :subdomain, with: ->(subdomain) { subdomain.strip.downcase }
    normalizes :currency, with: ->(currency) { currency.strip.upcase }

    validates :name, presence: true, length: { maximum: 100 }
    validates :subdomain, presence: true, uniqueness: true, length: { in: 3..63 },
      format: { with: SUBDOMAIN_FORMAT }, exclusion: { in: RESERVED_SUBDOMAINS }
    validates :shard, inclusion: { in: ->(_) { shard_keys } }
    validates :currency, format: { with: /\A[A-Z]{3}\z/ }
    validates :locale, inclusion: { in: %w[fr en] }
    validate :time_zone_must_exist

    # Moving a tenant between shards is a data migration, not an attribute update.
    attr_readonly :shard

    before_validation :assign_shard, on: :create

    def self.shard_keys
      Rails.application.config.x.tenant_shards.keys.map(&:to_s)
    end

    # New tenants go to the least populated shard.
    def self.next_shard
      counts = group(:shard).count
      shard_keys.min_by { |key| counts.fetch(key, 0) }
    end

    # Creates the organization with its default roles and its owner.
    def self.provision!(owner:, **attributes)
      transaction do
        tenant = create!(attributes)
        Role.create_defaults_for!(tenant)
        tenant.memberships.create!(user: owner, role: tenant.roles.owner!)
        tenant
      end
    end

    # Runs the block in this tenant's context: Current.tenant is set and tenant
    # models talk to this tenant's shard. Used by the request middleware, jobs,
    # the console and tests. Re-entrant for the same tenant (e.g. a job
    # performed inline); switching to another tenant while nested raises.
    def switch
      return yield(self) if Current.tenant == self && ApplicationRecord.current_shard == shard.to_sym

      Current.set(tenant: self) do
        ApplicationRecord.connected_to(shard: shard.to_sym, role: :writing) do
          ApplicationRecord.prohibit_shard_swapping { yield self }
        end
      end
    end

    def suspend!
      update!(status: :suspended, suspended_at: Time.current)
    end

    def activate!
      update!(status: :active, suspended_at: nil)
    end

    def host
      "#{subdomain}.#{Rails.application.config.x.app_domain}"
    end

    private
      def assign_shard
        self.shard ||= self.class.next_shard
      end

      def time_zone_must_exist
        errors.add(:time_zone, :inclusion) unless ActiveSupport::TimeZone[time_zone.to_s]
      end
  end
end
