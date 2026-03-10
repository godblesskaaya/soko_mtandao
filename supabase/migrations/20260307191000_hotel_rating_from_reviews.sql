-- Replace admin-controlled hotel ratings with verified guest reviews.
-- Ratings are collected per booking and hotel.rating is maintained from review aggregates.

-- Remove obviously invalid rows before constraints/indexes.
DELETE FROM public.reviews
WHERE booking_id IS NULL
   OR rating IS NULL
   OR rating < 1
   OR rating > 5;

-- Keep only the newest review per booking (if duplicates exist).
DELETE FROM public.reviews r
USING public.reviews newer
WHERE r.booking_id = newer.booking_id
  AND (r.created_at, r.id::text) < (newer.created_at, newer.id::text);

CREATE UNIQUE INDEX IF NOT EXISTS reviews_booking_id_uidx
ON public.reviews (booking_id);

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'reviews_rating_range_chk'
      AND conrelid = 'public.reviews'::regclass
  ) THEN
    ALTER TABLE public.reviews
      ADD CONSTRAINT reviews_rating_range_chk CHECK (rating BETWEEN 1 AND 5);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.recompute_hotel_rating(p_hotel_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_avg numeric(3, 2);
BEGIN
  SELECT ROUND(AVG(r.rating)::numeric, 2)
  INTO v_avg
  FROM public.reviews r
  JOIN public.bookings b ON b.id = r.booking_id
  WHERE b.hotel_id = p_hotel_id;

  UPDATE public.hotels
  SET rating = COALESCE(v_avg, 0)
  WHERE id = p_hotel_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.sync_hotel_rating_from_reviews()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_new_hotel_id uuid;
  v_old_hotel_id uuid;
BEGIN
  IF TG_OP IN ('INSERT', 'UPDATE') THEN
    SELECT hotel_id INTO v_new_hotel_id
    FROM public.bookings
    WHERE id = NEW.booking_id;
  END IF;

  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    SELECT hotel_id INTO v_old_hotel_id
    FROM public.bookings
    WHERE id = OLD.booking_id;
  END IF;

  IF v_old_hotel_id IS NOT NULL
     AND (v_new_hotel_id IS NULL OR v_new_hotel_id <> v_old_hotel_id) THEN
    PERFORM public.recompute_hotel_rating(v_old_hotel_id);
  END IF;

  IF v_new_hotel_id IS NOT NULL THEN
    PERFORM public.recompute_hotel_rating(v_new_hotel_id);
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS trg_reviews_sync_hotel_rating ON public.reviews;

CREATE TRIGGER trg_reviews_sync_hotel_rating
AFTER INSERT OR UPDATE OR DELETE ON public.reviews
FOR EACH ROW
EXECUTE FUNCTION public.sync_hotel_rating_from_reviews();

CREATE OR REPLACE FUNCTION public.submit_hotel_review(
  p_booking_id uuid,
  p_rating integer,
  p_comment text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_uid uuid := auth.uid();
  v_review_id uuid;
  v_hotel_rating numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'message', 'Authentication required.');
  END IF;

  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RETURN jsonb_build_object('success', false, 'message', 'Rating must be between 1 and 5.');
  END IF;

  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'message', 'Booking not found.');
  END IF;

  IF v_booking.user_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'message', 'You can only review your own booking.');
  END IF;

  IF v_booking.status <> 'confirmed' OR v_booking.payment_status <> 'completed' THEN
    RETURN jsonb_build_object('success', false, 'message', 'Only confirmed paid stays can be reviewed.');
  END IF;

  INSERT INTO public.reviews (booking_id, rating, comment)
  VALUES (
    p_booking_id,
    p_rating,
    NULLIF(TRIM(COALESCE(p_comment, '')), '')
  )
  ON CONFLICT (booking_id)
  DO UPDATE SET
    rating = EXCLUDED.rating,
    comment = EXCLUDED.comment,
    created_at = now()
  RETURNING id INTO v_review_id;

  PERFORM public.recompute_hotel_rating(v_booking.hotel_id);

  SELECT rating INTO v_hotel_rating
  FROM public.hotels
  WHERE id = v_booking.hotel_id;

  RETURN jsonb_build_object(
    'success', true,
    'review_id', v_review_id,
    'hotel_id', v_booking.hotel_id,
    'hotel_rating', v_hotel_rating
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.submit_hotel_review(uuid, integer, text)
TO authenticated, service_role;

-- One-time backfill from existing review data.
UPDATE public.hotels h
SET rating = COALESCE(stats.avg_rating, 0)
FROM (
  SELECT b.hotel_id, ROUND(AVG(r.rating)::numeric, 2) AS avg_rating
  FROM public.reviews r
  JOIN public.bookings b ON b.id = r.booking_id
  GROUP BY b.hotel_id
) stats
WHERE h.id = stats.hotel_id;

UPDATE public.hotels h
SET rating = 0
WHERE NOT EXISTS (
  SELECT 1
  FROM public.reviews r
  JOIN public.bookings b ON b.id = r.booking_id
  WHERE b.hotel_id = h.id
);
