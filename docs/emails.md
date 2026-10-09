# Emails

- Action Mailer, envoi asynchrone (`deliver_later` → `MailDeliveryJob`, Solid Queue),
  reprises limitées (5) sur erreurs SMTP transitoires, contexte tenant restauré.
- Templates HTML + texte : `app/views/{user,invitation,reservation}_mailer`.
- Liens vers la SPA : `ApplicationMailer#frontend_url` (`APP_PROTOCOL`, `APP_DOMAIN`).
- Expéditeur : `MAIL_FROM_ADDRESS` ; les emails voyageurs portent le nom de l'organisation.
- Développement : Mailpit (`SMTP_ADDRESS`/`SMTP_PORT`, UI http://localhost:8025).
- Production : `SMTP_ADDRESS`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`.

Emails existants : vérification d'email, compte activé, mot de passe oublié, mot de passe
modifié, alertes sécurité (MFA), invitation, confirmation et annulation de réservation.
