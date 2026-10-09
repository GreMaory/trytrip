# Base class for the central catalog database: tenants, users, memberships,
# roles, sessions, audit. Never sharded.
class CatalogRecord < ActiveRecord::Base
  self.abstract_class = true
  connects_to database: { writing: :catalog }
end
