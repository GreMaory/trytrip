# Conventions de l'API (`/api/v1`)

- JSON uniquement. Succès : `{ "data": … }`, listes paginées : `{ "data": [...], "meta": { "pagination": { page, per_page, total, total_pages } } }`
  (`?page=&per_page=`, 100 max).
- Erreurs : `{ "error": { "code", "message", "details"? } }` — codes : `not_found`, `unauthorized`,
  `forbidden`, `invalid_csrf_token`, `validation_failed` (details par champ), `bad_request`,
  `too_many_requests`, `invalid_credentials`, `invalid_mfa_code`, `invalid_token`, `invalid_transition`…
- Messages localisés (fr par défaut, en).
- Paramètres filtrés explicitement (`params.expect`), représentations explicites (Jbuilder).
- Montants : chaînes décimales (`"1000.0"`) + `currency`. Dates de séjour : `YYYY-MM-DD` (date locale, départ exclusif).

Principaux endpoints : voir `config/routes.rb` (`bin/rails routes -g api`).

**OpenAPI** : non encore rédigé (voir implementation-status).
