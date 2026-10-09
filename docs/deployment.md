# Déploiement (premiers éléments)

Non encore éprouvé en production. Pré-requis identifiés :

- Image : `tytrip-back/Dockerfile` (production, Thruster) ; frontend : `npm run build` servi en statique.
- Variables : voir `tytrip-back/.env.example` (bases `DATABASE_URL_*`, clés `AR_ENCRYPTION_*`,
  SMTP, `APP_DOMAIN`, `APP_PROTOCOL=https`). `RAILS_MASTER_KEY` si des credentials sont utilisés.
- `bin/rails db:prepare` crée/migre catalog, shards, queue, cache, cable.
- Lancer un worker `bin/jobs` (ou `SOLID_QUEUE_IN_PUMA=1`).
- TLS terminé par Traefik/Kamal ; `force_ssl` actif ; cookies Secure.
- Certificat wildcard nécessaire pour `*.APP_DOMAIN` (challenge DNS).
- Créer le premier administrateur plateforme via `bin/rails console`
  (`Identity::User.create!(…, platform_role: "super_admin")`), puis activer son MFA.
