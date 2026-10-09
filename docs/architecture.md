# Architecture

## Vue d'ensemble

```
Navigateur ──► Traefik ──┬─ <host>/api/* ──► Rails API (app) ──┬─ PostgreSQL catalog
                          │                                    ├─ PostgreSQL shards tenants
                          └─ <host>/*     ──► Vite / SPA       └─ Solid Queue (jobs) ──► SMTP
```

SPA et API sont servies sur le **même site** (même hôte, Traefik route `/api`) :
authentification par cookies, pas de CORS.

## Backend

- `app/domains/<domaine>/<type>/` : code métier. Les sous-dossiers (`models/`, `policies/`…)
  sont « collapsés » par Zeitwerk : `app/domains/booking/models/reservation.rb` → `Booking::Reservation`.
- Domaines actuels : `identity` (tenants, utilisateurs, sessions, rôles, invitations),
  `audit`, `lodging` (propriétés, logements), `crm` (voyageurs), `booking` (réservations, blocages).
- `app/controllers/api/v1` : API JSON ; vues Jbuilder dans `app/views/api/v1` (attributs explicites).
- `lib/middleware/tenant_resolver.rb` : middleware Rack (hors rechargement, chargé explicitement dans `application.rb`).
- Pas de couche service/repository systématique : modèles Active Record + contrôleurs. Un objet
  dédié n'existe que lorsqu'il porte une règle (ex. `Identity::AccessPolicy`).

## Décisions

| Sujet | Choix | Raison |
|---|---|---|
| Tests | Minitest | Déjà en place (Rails par défaut) ; pas de seconde stack |
| Jobs | Solid Queue | Déjà dans le Gemfile Rails 8 ; évite Redis + Sidekiq tant que non nécessaire |
| Cache / rate limiting | Solid Cache (prod), mémoire (dev/test) | Natif Rails 8 |
| Contexte de requête | `ActiveSupport::CurrentAttributes` (`Current`) | Natif, remis à zéro par l'executor ; remplace `request_store` |
| JSON | Jbuilder | Représentations explicites, conventionnel |
| Auth | Session serveur + cookie chiffré HttpOnly | SPA same-site ; pas de JWT en localStorage |
| MFA | TOTP (`rotp`) + codes de récupération | Standard, sans dépendance externe |
| UI | Element Plus (MIT) | PrimeVue 5 est passé sous licence commerciale avec clé ; Element Plus est maintenu et adapté au back-office |
| Monnaie | `numeric(12,2)` + BigDecimal, arrondi half-up | Jamais de flottants |
| Double réservation | Contrainte d'exclusion PostgreSQL + verrou sur le logement | Garantie même en concurrence |
| I18n | `rails-i18n`, fr par défaut, en disponible | Locale = utilisateur > organisation > Accept-Language |

## Frontend

- `src/api/client.ts` : axios centralisé (cookies, CSRF `XSRF-TOKEN` → `X-CSRF-Token`,
  relance unique sur jeton CSRF expiré, erreurs normalisées `ApiError`, gestion 401).
- `src/stores/auth.ts` : utilisateur courant, organisation, permissions (affichage uniquement).
- `src/router` : garde d'accès (public / authentifié / tenant / admin / permission).
- `src/modules/*` : écrans par domaine.
