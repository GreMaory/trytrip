# TyTrip

SaaS de gestion d'hébergements touristiques (PMS) multi-tenant.

| Dossier | Contenu |
|---|---|
| `tytrip-back/` | API Rails 8.0 (Ruby 3.4), PostgreSQL multi-bases, Solid Queue |
| `tytrip-front/` | SPA Vue 3 + TypeScript + Vite + Pinia + Element Plus |
| `docs/` | Architecture, multi-tenant, sécurité, API, état d'avancement |

État réel du projet : [docs/implementation-status.md](docs/implementation-status.md).

## Démarrage rapide (Docker)

```bash
docker compose up -d            # traefik, postgres, mailpit, app (Rails), jobs, frontend
docker compose exec app bin/rails db:seed
```

- Organisation de démo : http://demo.lvh.me
- Portail (connexion, choix d'organisation) : http://app.lvh.me
- Administration plateforme : http://admin.lvh.me
- Emails capturés : http://localhost:8025 (Mailpit)

Comptes de démo créés par `db/seeds.rb` (mot de passe dans ce fichier) :
`admin@tytrip.test` (admin plateforme), `owner@demo.test`, `manager@demo.test`, `staff@demo.test`.

`lvh.me` et ses sous-domaines pointent vers 127.0.0.1. Hors ligne, utilisez
`APP_DOMAIN=tytrip.localhost` / `VITE_APP_DOMAIN=tytrip.localhost` (les navigateurs
résolvent `*.localhost` localement).

## Développement sans Docker pour Rails/Vite

```bash
docker compose up -d postgres mailpit          # Postgres exposé sur 127.0.0.1:5433
cd tytrip-back
export DATABASE_PORT=5433
bin/rails db:prepare db:seed
bin/rails server                               # API sur :3000
bin/jobs                                       # worker Solid Queue (emails...)

cd ../tytrip-front
npm install
npm run dev                                    # http://demo.lvh.me:5173 (proxy /api -> :3000)
```

## Tests et qualité

```bash
cd tytrip-back
DATABASE_PORT=5433 bin/rails db:test:prepare test   # Minitest (modèles, intégration, jobs)
bin/rubocop
bin/brakeman --no-pager

cd tytrip-front
npm test            # Vitest
npm run type-check  # vue-tsc
npm run build
```
