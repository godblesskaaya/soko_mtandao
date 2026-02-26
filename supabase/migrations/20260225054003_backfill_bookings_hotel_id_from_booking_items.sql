UPDATE public.bookings b
SET hotel_id = src.hotel_id
FROM (
  SELECT
    booking_id,
    (array_agg(hotel_id ORDER BY created_at ASC))[1] AS hotel_id
  FROM public.booking_items
  GROUP BY booking_id
) src
WHERE b.id = src.booking_id
  AND b.hotel_id IS NULL;
