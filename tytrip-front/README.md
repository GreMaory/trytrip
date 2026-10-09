# TyTrip — Frontend

Vue 3 + TypeScript + Vite + Pinia + Vue Router + Element Plus (MIT).

```bash
npm install
npm run dev         # http://demo.lvh.me:5173 — /api est proxifié vers Rails (VITE_API_PROXY)
npm test            # Vitest
npm run type-check
npm run build
```

Structure : `src/api` (client HTTP centralisé, types, endpoints), `src/stores` (Pinia),
`src/router` (routes + garde d'accès), `src/modules/<domaine>` (écrans), `src/components`,
`src/composables`, `src/utils`.

L'application tourne sur plusieurs hôtes : `<organisation>.<domaine>` (back-office),
`app.<domaine>` (connexion, choix d'organisation), `admin.<domaine>` (plateforme).
Les permissions masquent des éléments d'interface ; l'API reste seule garante des autorisations.
