# Domains

This folder contains bounded-context entrypoints used by controllers/jobs.

- `Catalog::UseCases` -> companies, products, currencies, categories
- `Sales::UseCases` -> offers
- `Admin::Users::UseCases` -> admin user management

Current implementation uses namespace facades to existing use-case classes.
Future refactors can move concrete classes behind these domain boundaries
without changing controller/job call sites.


