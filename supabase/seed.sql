-- Idempotent seed data required after a clean public-schema wipe.
--
-- Keep this file limited to reference/config data. Do not put users,
-- hotels, bookings, payments, or environment-specific secrets here.

INSERT INTO public.roles (name)
VALUES
  ('customer'),
  ('staff'),
  ('hotel_admin'),
  ('system_admin')
ON CONFLICT (name) DO NOTHING;

INSERT INTO public.compliance_settings (key, value_int, value_text)
VALUES ('audit_log_retention_days', 2555, '7 years')
ON CONFLICT (key) DO NOTHING;

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
  jsonb_build_object(
    'source',
    'AzamPay published collection fee',
    'rate_format',
    'decimal'
  )
WHERE NOT EXISTS (
  SELECT 1
  FROM public.payment_provider_fee_policies
  WHERE lower(provider) = 'azampay'
    AND is_active = true
);

INSERT INTO public.amenities (
  name,
  category,
  short_description,
  availability_status,
  cost_type,
  currency,
  icon_url
)
SELECT *
FROM (
  VALUES
    ('Wi-Fi', 'property_wide'::public.amenity_category, 'Internet access for guests', 'available'::public.amenity_availability_status, 'included'::public.amenity_cost_type, 'TZS', 'wifi'),
    ('Parking', 'property_wide'::public.amenity_category, 'On-site or nearby guest parking', 'available'::public.amenity_availability_status, 'included'::public.amenity_cost_type, 'TZS', 'local_parking'),
    ('Restaurant', 'food_beverage'::public.amenity_category, 'Food and beverage service on property', 'available'::public.amenity_availability_status, 'paid_extra'::public.amenity_cost_type, 'TZS', 'restaurant'),
    ('Breakfast', 'food_beverage'::public.amenity_category, 'Breakfast service for guests', 'available'::public.amenity_availability_status, 'on_request'::public.amenity_cost_type, 'TZS', 'breakfast_dining'),
    ('Air conditioning', 'in_room'::public.amenity_category, 'Room air conditioning', 'available'::public.amenity_availability_status, 'included'::public.amenity_cost_type, 'TZS', 'ac_unit'),
    ('Swimming pool', 'leisure_wellness'::public.amenity_category, 'Guest swimming pool access', 'available'::public.amenity_availability_status, 'included'::public.amenity_cost_type, 'TZS', 'pool'),
    ('Airport shuttle', 'service'::public.amenity_category, 'Transport to or from the airport', 'available'::public.amenity_availability_status, 'paid_extra'::public.amenity_cost_type, 'TZS', 'airport_shuttle'),
    ('Laundry', 'service'::public.amenity_category, 'Laundry service for guests', 'available'::public.amenity_availability_status, 'paid_extra'::public.amenity_cost_type, 'TZS', 'local_laundry_service')
) AS seed(name, category, short_description, availability_status, cost_type, currency, icon_url)
WHERE NOT EXISTS (
  SELECT 1
  FROM public.amenities a
  WHERE lower(a.name) = lower(seed.name)
);
