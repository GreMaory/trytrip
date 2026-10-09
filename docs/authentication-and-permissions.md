# Authentification, sessions et permissions

## Sessions

- `POST /api/v1/session` → cookie `tytrip_auth` chiffré, HttpOnly, SameSite=Lax, Secure en
  production, partagé par les sous-domaines de `APP_DOMAIN`. Il contient un jeton aléatoire ;
  la base ne stocke que son SHA-256 (`sessions.token_digest`).
- Durée de vie 30 jours ; révocation à la déconnexion, au changement/réinitialisation de mot de
  passe (autres sessions), à l'activation du MFA, à la suspension d'un utilisateur.
- L'utilisateur voit et révoque ses sessions (`/me/sessions`).
- Fixation de session évitée (`reset_session` à la connexion).

## Protection

- CSRF : jeton Rails exposé dans le cookie `XSRF-TOKEN` (lisible par la SPA), renvoyé dans
  `X-CSRF-Token` pour toute requête non-GET. Le login est protégé aussi.
- Messages identiques pour email inconnu, mauvais mot de passe, compte verrouillé ou suspendu.
- Verrouillage après 10 échecs (15 min) ; rate limiting par IP sur login, MFA, mot de passe
  oublié, inscription, invitations.
- Mot de passe : bcrypt, 12 caractères minimum, ne doit pas contenir l'email.
- Réinitialisation : jeton signé (`generates_token_for`) valable 30 min, à usage unique
  (invalidé par le changement de mot de passe). Réponse 202 identique que l'email existe ou non.
- Vérification d'email : jeton signé 48 h, invalidé après usage.

## Double authentification (TOTP)

- Secret chiffré en base (Active Record Encryption).
- Activation par saisie d'un code ; 10 codes de récupération (stockés hachés, usage unique).
- Anti-rejeu : un code TOTP n'est accepté qu'une fois (`otp_last_used_at`).
- Connexion en deux étapes : défi en session Rails, 5 min, 5 tentatives.
- Désactivation : mot de passe + code. Alertes email à l'activation/désactivation.
- Obligatoire pour les administrateurs plateforme en production (`REQUIRE_MFA_FOR_PLATFORM_ADMINS`).

## RBAC

- Permissions définies dans le code (`Identity::Permissions::ALL`), vérifiées côté API par
  `authorize!("…")` sur chaque action sensible.
- Rôles par organisation (table `roles`) : `owner` (système, immuable, toutes permissions),
  `admin`, `manager`, `staff`, `read_only` (modifiables), rôles personnalisés.
- Un membre a un rôle par organisation (`memberships`) ; un membre suspendu n'a aucune permission.
- Anti-élévation (`Identity::AccessPolicy`) : on ne peut accorder que des permissions que l'on
  possède, seul un owner attribue le rôle owner ou gère un owner, personne ne modifie sa
  propre appartenance, l'organisation garde au moins un owner.
- Administrateur plateforme : `users.platform_role = super_admin`, distinct des rôles
  d'organisation ; endpoints `/api/v1/admin/*`. Il n'a pas accès aux données métier d'une
  organisation sans en être membre.

## Audit

`audit_events` (catalog, append-only) : connexions et échecs, MFA, mots de passe, sessions,
rôles, appartenances, invitations, actions plateforme, création/modification des
propriétés et réservations. Les clés sensibles des métadonnées sont filtrées
(`[FILTERED]`). Consultation : `/api/v1/audit_events` (permission `audit.read`) et
`/api/v1/admin/audit_events`.
