# Catalogue of permissions understood by the API. Permissions are defined in
# code because code checks them; roles (stored per tenant) group them.
module Identity
  module Permissions
    ALL = {
      "organization.manage" => "Modifier les paramètres de l'organisation",
      "members.read" => "Voir les membres",
      "members.manage" => "Inviter, modifier et retirer des membres",
      "roles.manage" => "Gérer les rôles et permissions",
      "audit.read" => "Consulter le journal d'audit",
      "properties.read" => "Voir les propriétés et logements",
      "properties.manage" => "Gérer les propriétés et logements",
      "reservations.read" => "Voir les réservations et disponibilités",
      "reservations.manage" => "Gérer les réservations et blocages",
      "guests.read" => "Voir les voyageurs",
      "guests.manage" => "Gérer les voyageurs",
      "rates.read" => "Voir les tarifs",
      "rates.manage" => "Gérer les tarifs",
      "housekeeping.read" => "Voir les tâches de ménage",
      "housekeeping.manage" => "Gérer les tâches de ménage",
      "maintenance.read" => "Voir les incidents de maintenance",
      "maintenance.manage" => "Gérer la maintenance",
      "billing.read" => "Voir la facturation",
      "billing.manage" => "Gérer la facturation",
      "reports.read" => "Consulter les rapports"
    }.freeze

    KEYS = ALL.keys.freeze
    READ_ONLY = KEYS.select { |key| key.end_with?(".read") }.freeze

    DEFAULT_ROLES = {
      "owner" => {
        name: "Propriétaire", system: true, permissions: KEYS,
        description: "Accès complet, y compris la gestion des propriétaires de l'organisation"
      },
      "admin" => {
        name: "Administrateur", permissions: KEYS,
        description: "Administre l'organisation"
      },
      "manager" => {
        name: "Manager",
        permissions: READ_ONLY + %w[properties.manage reservations.manage guests.manage rates.manage
                                    housekeeping.manage maintenance.manage billing.manage] - %w[audit.read],
        description: "Gère l'activité quotidienne"
      },
      "staff" => {
        name: "Équipe",
        permissions: %w[properties.read reservations.read guests.read housekeeping.read housekeeping.manage
                        maintenance.read maintenance.manage],
        description: "Ménage, maintenance et consultation des réservations"
      },
      "read_only" => {
        name: "Lecture seule", permissions: READ_ONLY - %w[audit.read],
        description: "Consultation uniquement"
      }
    }.freeze
  end
end
