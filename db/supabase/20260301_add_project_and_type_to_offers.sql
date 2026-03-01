-- 20260301_add_project_and_type_to_offers.sql
-- Step 1: Add columns
ALTER TABLE public.offers ADD COLUMN project VARCHAR(50);
UPDATE public.offers SET project = 'Belirtilmedi' WHERE project IS NULL;
ALTER TABLE public.offers ALTER COLUMN project SET NOT NULL;

ALTER TABLE public.offers ADD COLUMN offer_type VARCHAR(20) DEFAULT 'standard';
UPDATE public.offers SET offer_type = 'standard' WHERE offer_type IS NULL;
ALTER TABLE public.offers ALTER COLUMN offer_type SET NOT NULL;

-- Step 2: Create index
CREATE INDEX idx_offers_offer_type ON public.offers(offer_type);
CREATE INDEX idx_offers_project ON public.offers(project);

-- Step 3: Update RPC
CREATE OR REPLACE FUNCTION public.create_offer_with_items_atomic(
  p_actor_id uuid,
  p_company_id uuid,
  p_offer_number text,
  p_offer_date date,
  p_status text,
  p_net_total numeric,
  p_vat_total numeric,
  p_gross_total numeric,
  p_items jsonb,
  p_project text DEFAULT 'Belirtilmedi',
  p_offer_type text DEFAULT 'standard'
)
RETURNS TABLE (offer_id uuid)
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_offer_id uuid;
BEGIN
  INSERT INTO public.offers (
    user_id,
    company_id,
    offer_number,
    offer_date,
    status,
    net_total,
    vat_total,
    gross_total,
    project,
    offer_type
  )
  VALUES (
    p_actor_id,
    p_company_id,
    p_offer_number,
    p_offer_date,
    p_status,
    p_net_total,
    p_vat_total,
    p_gross_total,
    p_project,
    p_offer_type
  )
  RETURNING id INTO v_offer_id;

  INSERT INTO public.offer_items (
    user_id,
    offer_id,
    product_id,
    description,
    quantity,
    unit_price,
    discount_rate,
    line_total
  )
  SELECT
    p_actor_id,
    v_offer_id,
    (item->>'product_id')::uuid,
    item->>'description',
    COALESCE((item->>'quantity')::numeric, 0),
    COALESCE((item->>'unit_price')::numeric, 0),
    COALESCE((item->>'discount_rate')::numeric, 0),
    COALESCE((item->>'line_total')::numeric, 0)
  FROM jsonb_array_elements(COALESCE(p_items, '[]'::jsonb)) AS item;

  INSERT INTO public.activity_logs (
    action,
    actor_id,
    target_id,
    target_type,
    metadata,
    created_at
  )
  VALUES (
    'offers.create',
    p_actor_id,
    v_offer_id::text,
    'offer',
    jsonb_build_object('offer_number', p_offer_number, 'project', p_project, 'type', p_offer_type),
    now()
  );

  RETURN QUERY SELECT v_offer_id;
END;
$$;
