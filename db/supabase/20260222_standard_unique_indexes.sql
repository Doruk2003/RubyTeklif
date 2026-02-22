-- Structural uniqueness constraints aligned with service-level validation rules.
-- Keep these in DB to prevent race-condition duplicates.

create unique index if not exists currencies_user_code_unique_idx
  on public.currencies (user_id, upper(code))
  where deleted_at is null and code is not null and btrim(code) <> '';

create unique index if not exists offers_user_offer_number_unique_idx
  on public.offers (user_id, offer_number)
  where deleted_at is null and offer_number is not null and btrim(offer_number) <> '';
