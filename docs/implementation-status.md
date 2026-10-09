# État d'implémentation — TyTrip

_Dernière mise à jour : 2026-10-09. Ce fichier décrit l'état réel du dépôt._

## Terminé et vérifié

| Domaine | Contenu | Vérification |
|---|---|---|
| Socle | Rails 8.0.5.1 / Ruby 3.4.10 démarre ; Zeitwerk OK (`zeitwerk:check`, tests en eager load) ; Dockerfiles alignés (Ruby 3.4.10, Bundler 4.0.11) | tests, CI=true |
| Multi-tenant | Catalog + 2 shards configurables (`config/shards.yml`), résolution par sous-domaine, 404 uniforme, `Tenant#switch`, `TenantScoped` (échec fermé), jobs porteurs du tenant | tests modèles + intégration (2 tenants sur le même shard) |
| Identité | Organisations (tenants), utilisateurs, memberships, invitations (expiration, révocation, usage unique), inscription atomique (user + organisation), création d'organisations supplémentaires, changement d'organisation | tests + navigateur |
| Authentification | Cookie de session chiffré HttpOnly, CSRF, lockout, rate limiting, messages non révélateurs, sessions listables/révocables, mot de passe oublié, vérification d'email, changement de mot de passe | tests |
| MFA | TOTP + codes de récupération, anti-rejeu, défi limité, désactivation contrôlée, alertes email | tests |
| RBAC | Permissions en code, rôles par organisation (défauts + personnalisés), contrôle API, protections anti-élévation, owner immuable | tests |
| Plateforme | Admin : organisations (liste, création + invitation owner, suspension/réactivation), utilisateurs (suspension, révocation de sessions), audit global ; MFA exigeable | tests |
| Audit | Journal structuré catalog, métadonnées nettoyées, consultation organisation/plateforme | tests |
| Propriétés | Propriétés, logements (capacité, tarif de base, séjours min/max), équipements, adresses, règles, archivage | tests + navigateur |
| Réservations | Création (voyageur existant ou nouveau, dédoublonnage par email), modification (recalcul), cycle de vie (confirmer, arrivée, départ, annuler avec motif, no-show), anti-double-réservation (contrainte d'exclusion + verrou), blocages, calendrier | tests (dont concurrence réelle 5 threads) + navigateur |
| Voyageurs | Fiches, recherche, historique des séjours, consentement marketing horodaté, suppression (si aucun séjour) | tests |
| Tableau de bord | Arrivées/départs du jour (fuseau de l'organisation), séjours en cours, occupation 30 j, CA du mois, à confirmer | tests + navigateur |
| Emails | Vérification, activation, reset, mot de passe modifié, alertes MFA, invitation, confirmation/annulation de réservation ; HTML + texte ; asynchrone avec reprises | tests + envoi réel Solid Queue → Mailpit |
| I18n | fr par défaut, en ; locale utilisateur > organisation > Accept-Language | tests |
| Frontend | Vue 3/TS : connexion (+MFA), inscription, mot de passe oublié/reset, vérification email, acceptation d'invitation, choix/création d'organisation, tableau de bord, calendrier (création depuis une case, blocages), réservations (liste/filtres/détail/actions/formulaire), propriétés (liste/détail/formulaire/logements), voyageurs, membres & invitations, rôles & permissions, organisation, audit, compte (profil, mot de passe, MFA avec QR code, sessions), administration plateforme | vitest, vue-tsc, build, parcours manuel dans Chrome |

## Tests exécutés (2026-10-09)

- Backend : `bin/rails test` → **86 tests, 380 assertions, 0 échec** (aussi avec `CI=true`, eager load).
- `bin/rubocop` → 0 offense. `bin/brakeman` → 1 avertissement : fin de support de Rails 8.0 le 2026-11-07.
- Frontend : `npm test` → **18 tests, 0 échec** ; `vue-tsc --build` OK ; `vite build` OK.
- Parcours manuel (Chrome, `demo.tytrip.localhost`) : connexion manager → tableau de bord →
  calendrier → nouvelle réservation (refus « séjour minimum » affiché) → création → confirmation →
  email reçu dans Mailpit.
- Smoke test HTTP via le proxy Vite : CSRF, login, tenant inconnu, double réservation, session partagée entre sous-domaines, logout.

## Partiel

- **API** : conventions et tests d'intégration en place, mais **pas de documentation OpenAPI** ni de tests de contrat.
- **CI** : workflow backend corrigé (multi-DB, zeitwerk) mais **pas de job frontend** ni de build Docker ; dépôt Git non configuré (voir blocages).
- **Docker** : compose mis à jour (app, jobs, frontend, mailpit) ; la stack complète via Traefik n'a pas été démarrée de bout en bout (seuls postgres et mailpit ont tourné ; Rails/Vite testés sur l'hôte).
- **Voyageurs / RGPD** : pas d'anonymisation des voyageurs ayant des séjours, pas d'export, pas de politique de conservation.
- **Préférences utilisateur** : champ `preferences` (jsonb) sans écran dédié.
- **Frontend** : bundle principal ~880 kB (Element Plus importé en entier) ; tests de composants limités au login ; messages de validation serveur en français mais libellés de champs génériques.

## Restant (ordre prévu)

1. OpenAPI + tests de contrat ; job CI frontend.
2. Tarification : saisons, règles de durée, suppléments, taxes, historique des prix, tarifs par canal.
3. Housekeeping (tâches post-départ, affectation, checklists) et maintenance (incidents, coûts).
4. Messagerie : modèles, envois planifiés liés au séjour, historique.
5. Facturation : factures, avoirs, paiements, acomptes, exports ; Stripe/PayPal (contrats + tests, sans transactions fictives).
6. Abonnements, plans, quotas et modules activables (contrôlés côté backend).
7. Reporting avancé.
8. Channel manager (contrats d'adaptateurs, idempotence, journal de synchro) et moteur de réservation public.
9. RGPD (export, anonymisation, rétention), Active Storage isolé par tenant (photos, documents), observabilité (logs structurés JSON, suivi des jobs échoués).
10. Montée de version Rails 8.1 (fin de support 8.0 le 2026-11-07).

## Blocages / décisions en attente

- **Git** : la racine n'est pas un dépôt et `tytrip-back/.git` est vide. Le passage au monorepo
  (option retenue) n'a pas pu être fait automatiquement : voir le compte rendu de session.
- **PrimeVue** : abandonné au profit d'Element Plus car PrimeVue 5 est sous licence commerciale.
  Si une licence PrimeUI est souhaitée, c'est une décision métier.
