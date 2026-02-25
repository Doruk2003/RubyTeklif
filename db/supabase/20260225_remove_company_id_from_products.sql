-- Remove company_id from products table as requested
-- This column is no longer needed for products.

-- 1. Remove foreign key constraint
ALTER TABLE "public"."products" DROP CONSTRAINT IF EXISTS "products_company_id_fkey";

-- 2. Remove index
DROP INDEX IF EXISTS "public"."products_company_id_idx";

-- 3. Remove column
ALTER TABLE "public"."products" DROP COLUMN IF EXISTS "company_id";
