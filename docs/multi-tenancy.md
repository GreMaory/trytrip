# Multi-tenant et sharding

## Bases de données

| Base | Contenu | Classe |
|---|---|---|
| `catalog` | tenants, users, sessions, roles, memberships, invitations, audit_events | `CatalogRecord` |
| shards (`primary`, `primary_shard_two`) | données métier : properties, units, guests, reservations, availability_blocks | `ApplicationRecord` |
| queue / cache / cable | Solid Queue / Cache / Cable | — |

Les shards sont déclarés dans `config/shards.yml` (clé de shard → config `database.yml`).
`ApplicationRecord.connects_to shards:` est construit à partir de ce fichier.
Chaque tenant stocke sa clé de shard (`tenants.shard`, non modifiable par update).
Les nouveaux tenants vont sur le shard le moins peuplé (`Identity::Tenant.next_shard`).
Les migrations de `db/migrate` s'appliquent à tous les shards.

**Ajouter un shard** : nouvelle base dans `database.yml` (tous les environnements),
nouvelle entrée dans `config/shards.yml`, `bin/rails db:prepare`. Déplacer un tenant
existant est une migration de données (non outillée à ce jour).

## Résolution du tenant (`Middleware::TenantResolver`)

1. `/up` est exempté.
2. Sous-domaine absent ou réservé (`app`, `admin`, `www`, `api`…) → pas de tenant (portail / plateforme).
3. Sous-domaine validé par format strict, recherché dans le catalog (`status = active`).
4. Inconnu, suspendu ou malformé → **même** 404 JSON générique.
5. Sinon `tenant.switch { app.call(env) }` : `Current.tenant` + connexion au shard du tenant,
   changement de shard interdit à l'intérieur (`prohibit_shard_swapping`). Le contexte est
   restauré à la sortie, exception comprise ; `Current` est remis à zéro par l'executor Rails.

Le client ne peut jamais choisir le shard (aucun paramètre ni en-tête n'est lu).
Les contrôleurs exigent ensuite une **appartenance active** de l'utilisateur au tenant.

## Isolation des données (`TenantScoped`)

Un shard pouvant héberger plusieurs tenants, chaque table métier porte `tenant_id` et
les modèles incluent `TenantScoped` :

- `default_scope where(tenant_id: Current.tenant.id)` — toutes les requêtes, y compris `find`
  et les associations, sont filtrées ;
- **échec fermé** : sans contexte tenant → `Current::TenantMissing` ; connexion sur un autre
  shard que celui du tenant → `TenantScoped::ShardMismatch` ;
- `tenant_id` est affecté automatiquement, en lecture seule, et validé contre le tenant courant.

Tests : `test/models/tenant_scoped_test.rb`, `test/integration/cross_tenant_isolation_test.rb`,
`test/integration/booking_flow_test.rb` (deux tenants sur le même shard, identifiants connus).

## Jobs

`TenantContextJob` (inclus dans `ApplicationJob` et `MailDeliveryJob`) enregistre l'id du
tenant courant dans le payload à l'enqueue et exécute tout le job (désérialisation des
arguments comprise) dans `tenant.switch`. Testé dans `test/jobs/tenant_context_job_test.rb`.

## Limites connues

- `unscoped`, `connection.execute` ou du SQL brut contournent `TenantScoped` : interdits dans
  le code tenant (à vérifier en revue de code ; pas de Row Level Security PostgreSQL à ce stade).
- Les écritures catalog (audit) et shard ne sont pas dans une même transaction.
- Les associations entre catalog et shards (ex. `created_by`) n'ont pas de clé étrangère.
- Cache, fichiers (Active Storage) et exports : pas encore utilisés ; à préfixer par tenant le moment venu.
