# Data Access Scaling Strategy

## Decision
Do not perform a full migration from Supabase PostgREST/RPC to direct PostgreSQL driver access for the whole app.

## Rationale
- Current security model depends on Supabase Auth + RLS behavior across user-scoped requests.
- Full direct-DB migration would require re-implementing request-scoped auth context and would increase security/regression risk.
- The codebase is already organized around Query/Service objects; scaling bottlenecks can be solved in PostgreSQL with views, indexes, and query shaping without rewriting all data access.

## Standard
1. Keep request-path CRUD on Supabase PostgREST/RPC.
2. Push sort/filter/pagination/count logic into PostgreSQL.
3. Keep business validation in Rails services/forms.
4. Keep structural constraints (unique/check/fk/index) in PostgreSQL.
5. Introduce direct PostgreSQL only for isolated high-volume read-only workloads after measurement (export/reporting jobs), not as default path.

## Applied So Far
- `company_with_offer_counts` view for DB-side company sorting/filter/pagination.
- Service-level uniqueness guards + DB unique indexes for core modules.
- Performance index pack in `db/supabase/20260222_performance_scaling_indexes.sql`.

## Trigger to Revisit Full Direct-DB Migration
Re-evaluate only if all conditions are true:
- p95 latency target fails despite DB-side optimizations and caching.
- profiling shows HTTP serialization layer as dominant bottleneck.
- team can enforce secure request context equivalent to current RLS guarantees.
