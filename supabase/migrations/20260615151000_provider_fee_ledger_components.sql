-- Record provider collection fees as first-class accounting components.

ALTER TABLE public.financial_components
  ADD COLUMN IF NOT EXISTS idempotency_key text;

CREATE UNIQUE INDEX IF NOT EXISTS ux_financial_components_idempotency_key
ON public.financial_components(idempotency_key)
WHERE idempotency_key IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS ux_payment_provider_fee_policy_active_provider
ON public.payment_provider_fee_policies(lower(provider))
WHERE is_active;

INSERT INTO public.payment_provider_fee_policies (
  provider,
  fee_rate,
  flat_fee,
  fee_owner_type,
  metadata
)
SELECT
  'azampay',
  0.030000,
  0,
  'platform',
  jsonb_build_object('source', 'AzamPay published collection fee', 'rate_format', 'decimal')
WHERE NOT EXISTS (
  SELECT 1
  FROM public.payment_provider_fee_policies
  WHERE lower(provider) = 'azampay'
    AND is_active = true
);

CREATE OR REPLACE FUNCTION public.allocate_settlements_for_payment(
  p_payment_id uuid,
  p_booking_id uuid,
  p_hold_hours integer DEFAULT 24
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $$
DECLARE
  v_created_count integer := 0;
  v_payment record;
  v_fee_policy record;
  v_fee_basis numeric(12,2) := 0;
  v_provider_fee numeric(12,2) := 0;
  r record;
BEGIN
  FOR r IN
    SELECT id FROM public.booking_items WHERE booking_id = p_booking_id
  LOOP
    PERFORM public.compute_booking_item_financials(r.id);
  END LOOP;

  WITH inserted_rows AS (
    INSERT INTO public.settlements (
      payment_id,
      booking_item_id,
      hotel_id,
      amount_allocated,
      status,
      available_at,
      currency,
      settlement_type
    )
    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.hotel_net_amount,
      'pending',
      now() + make_interval(hours => GREATEST(coalesce(p_hold_hours, 24), 0)),
      bif.currency,
      'hotel'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.hotel_net_amount > 0

    UNION ALL

    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.commission_amount,
      'available',
      now(),
      bif.currency,
      'platform'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.commission_amount > 0

    UNION ALL

    SELECT
      p_payment_id,
      bi.id,
      bi.hotel_id,
      bif.tax_amount,
      'available',
      now(),
      bif.currency,
      'tax'
    FROM public.booking_items bi
    JOIN public.booking_item_financials bif ON bif.booking_item_id = bi.id
    WHERE bi.booking_id = p_booking_id
      AND bif.tax_amount > 0
    ON CONFLICT (booking_item_id, settlement_type)
    DO NOTHING
    RETURNING id
  )
  SELECT count(*) INTO v_created_count FROM inserted_rows;

  INSERT INTO public.ledger_entries (
    idempotency_key,
    entry_type,
    owner_type,
    owner_hotel_id,
    booking_id,
    booking_item_id,
    payment_id,
    settlement_id,
    direction,
    amount,
    currency,
    metadata
  )
  SELECT
    'settlement_created:' || s.id::text,
    'settlement_created',
    CASE
      WHEN s.settlement_type = 'hotel' THEN 'hotel'
      WHEN s.settlement_type = 'platform' THEN 'platform'
      ELSE 'tax'
    END,
    CASE WHEN s.settlement_type = 'hotel' THEN s.hotel_id ELSE NULL END,
    p_booking_id,
    s.booking_item_id,
    s.payment_id,
    s.id,
    'credit',
    s.amount_allocated,
    s.currency,
    jsonb_build_object('settlement_type', s.settlement_type, 'status', s.status)
  FROM public.settlements s
  WHERE s.payment_id = p_payment_id
    AND s.booking_item_id IN (
      SELECT id FROM public.booking_items WHERE booking_id = p_booking_id
    )
  ON CONFLICT (idempotency_key)
  DO NOTHING;

  SELECT
    id,
    coalesce(amount_received, amount, 0) AS amount,
    coalesce(nullif(currency, ''), 'TZS') AS currency
  INTO v_payment
  FROM public.payments
  WHERE id = p_payment_id;

  SELECT
    provider,
    fee_rate,
    flat_fee,
    fee_owner_type
  INTO v_fee_policy
  FROM public.payment_provider_fee_policies
  WHERE lower(provider) = 'azampay'
    AND is_active = true
    AND applies_from <= now()
  ORDER BY applies_from DESC
  LIMIT 1;

  IF FOUND AND v_payment.id IS NOT NULL THEN
    v_fee_basis := round(coalesce(v_payment.amount, 0), 2);
    v_provider_fee := round((v_fee_basis * coalesce(v_fee_policy.fee_rate, 0)) + coalesce(v_fee_policy.flat_fee, 0), 2);

    IF v_provider_fee > 0 THEN
      INSERT INTO public.financial_components (
        idempotency_key,
        booking_id,
        payment_id,
        provider,
        component_type,
        owner_type,
        direction,
        amount,
        currency,
        rate,
        basis_amount,
        metadata
      )
      VALUES (
        'provider_collection_fee:' || p_payment_id::text,
        p_booking_id,
        p_payment_id,
        v_fee_policy.provider,
        'provider_collection_fee',
        v_fee_policy.fee_owner_type,
        'debit',
        v_provider_fee,
        upper(v_payment.currency),
        v_fee_policy.fee_rate,
        v_fee_basis,
        jsonb_build_object('flat_fee', coalesce(v_fee_policy.flat_fee, 0))
      )
      ON CONFLICT DO NOTHING;

      INSERT INTO public.ledger_entries (
        idempotency_key,
        entry_type,
        owner_type,
        booking_id,
        payment_id,
        direction,
        amount,
        currency,
        metadata
      )
      VALUES (
        'provider_collection_fee:' || p_payment_id::text,
        'provider_collection_fee',
        v_fee_policy.fee_owner_type,
        p_booking_id,
        p_payment_id,
        'debit',
        v_provider_fee,
        upper(v_payment.currency),
        jsonb_build_object(
          'provider', v_fee_policy.provider,
          'rate', v_fee_policy.fee_rate,
          'basis_amount', v_fee_basis,
          'flat_fee', coalesce(v_fee_policy.flat_fee, 0)
        )
      )
      ON CONFLICT (idempotency_key)
      DO NOTHING;
    END IF;
  END IF;

  RETURN v_created_count;
END;
$$;

GRANT ALL ON FUNCTION public.allocate_settlements_for_payment(uuid, uuid, integer) TO anon, authenticated, service_role;
