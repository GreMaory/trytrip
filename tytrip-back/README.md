# TyTrip — API Rails

Voir le [README racine](../README.md) pour le démarrage et [../docs](../docs) pour l'architecture.

- Ruby 3.4.10, Rails 8.0.5.1, Bundler 4.0.11
- PostgreSQL : base `catalog` (centrale) + shards tenants (`config/shards.yml`)
- Solid Queue (jobs), Solid Cache (cache, rate limiting)
- Minitest

```bash
export DATABASE_PORT=5433      # Postgres du docker compose
bin/rails db:prepare db:seed
bin/rails test
```

Code métier : `app/domains/<domaine>/<type>/` (sous-dossiers « collapsés » par Zeitwerk :
`app/domains/identity/models/user.rb` définit `Identity::User`).
